import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// On the cover, until the reader turns it for the first time, the page curls back from its
/// bottom corner, as if a finger had pulled it partway, showing the next page beneath, and
/// then falls flat again. It repeats every few seconds and never turns the page itself.
///
/// The curl is drawn with Core Image's page curl, so the back of the curling cover is the page
/// color: black in dark mode, white in light mode.
struct CoverCurlHint: UIViewRepresentable {
    let book: Book
    let isRightToLeft: Bool

    func makeUIView(context: Context) -> CoverCurlHintView {
        CoverCurlHintView(book: book, isRightToLeft: isRightToLeft)
    }

    func updateUIView(_ view: CoverCurlHintView, context: Context) {}
}

final class CoverCurlHintView: UIView {
    private let book: Book
    private let cover: BookPageView
    private let nextPage: BookPageView
    /// Shows the curling cover, one picture per frame.
    private let curlView = UIView()
    private let isRightToLeft: Bool
    private var loop: Task<Void, Never>?
    private let renderer = CurlRenderer()
    private var displayLink: CADisplayLink?
    private var animation: (from: CGFloat, to: CGFloat, start: CFTimeInterval, duration: CFTimeInterval, easeIn: Bool)?

    /// How far the page curls back, out of a whole turn.
    private static let curlAmount: CGFloat = 0.35

    init(book: Book, isRightToLeft: Bool) {
        self.book = book
        cover = BookPageView(book: book, index: 0, showsTotal: false)
        nextPage = BookPageView(book: book, index: min(1, book.pages.count - 1), showsTotal: false)
        self.isRightToLeft = isRightToLeft
        super.init(frame: CGRect(origin: .zero, size: book.metrics.size))
        isUserInteractionEnabled = false
        backgroundColor = .clear
        for page in [nextPage, cover, curlView] {
            page.frame = bounds
            page.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(page)
        }
        curlView.isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        loop?.cancel()
        guard window != nil else {
            displayLink?.invalidate()
            displayLink = nil
            return
        }
        loop = Task { @MainActor [weak self] in
            // A moment on the flat cover first.
            try? await Task.sleep(for: .seconds(1.2))
            while !Task.isCancelled {
                self?.curl()
                try? await Task.sleep(for: .seconds(1.4))
                guard !Task.isCancelled else { return }
                self?.uncurl()
                try? await Task.sleep(for: .seconds(3.2))
            }
        }
    }

    /// Curls the cover back partway and holds it there.
    private func curl() {
        guard prepareCurl() else { return }
        cover.isHidden = true
        curlView.isHidden = false
        animate(from: 0, to: Self.curlAmount, duration: 1.0, easeIn: false)
    }

    /// Lets go: the cover falls back flat from where it was held.
    private func uncurl() {
        guard !curlView.isHidden else { return }
        animate(from: Self.curlAmount, to: 0, duration: 0.6, easeIn: true)
    }

    // MARK: Drawing the curl

    /// Takes pictures of the cover and the next page in the current light or dark mode, with a
    /// back side in the page color (black in dark mode, white in light mode) and the cover's
    /// own picture showing through faintly, like the back of a real page.
    private func prepareCurl() -> Bool {
        guard let front = snapshot(of: 0),
              let revealed = snapshot(of: min(1, book.pages.count - 1))?.cgImage,
              let frontImage = front.cgImage,
              let back = backSnapshot(of: front) else { return false }
        // Led by the bottom corner, along a slight diagonal, like the book's own curl.
        let angle: CGFloat = isRightToLeft ? 0.25 : .pi - 0.25
        renderer.prepare(from: frontImage, to: revealed, back: back, angle: angle)
        curlView.layer.contents = renderer.frame(at: 0)
        return true
    }

    private var snapshotFormat: UIGraphicsImageRendererFormat {
        let format = UIGraphicsImageRendererFormat()
        // Twice the point size keeps the curl smooth without too much work each frame.
        format.scale = min(traitCollection.displayScale, 2)
        format.opaque = true
        return format
    }

    private func snapshot(of index: Int) -> UIImage? {
        let size = book.metrics.size
        guard size.width > 0, size.height > 0 else { return nil }
        let page = BookPageView(book: book, index: index, showsTotal: false)
        page.frame = CGRect(origin: .zero, size: size)
        page.overrideUserInterfaceStyle = traitCollection.userInterfaceStyle
        return UIGraphicsImageRenderer(size: size, format: snapshotFormat).image { context in
            traitCollection.performAsCurrent {
                Typography.pageColor.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                page.draw(page.bounds)
            }
        }
    }

    private func backSnapshot(of front: UIImage) -> CGImage? {
        let size = front.size
        return UIGraphicsImageRenderer(size: size, format: snapshotFormat).image { context in
            traitCollection.performAsCurrent {
                Typography.pageColor.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                front.draw(at: .zero, blendMode: .normal, alpha: 0.1)
            }
        }.cgImage
    }

    private func animate(from: CGFloat, to: CGFloat, duration: CFTimeInterval, easeIn: Bool) {
        animation = (from, to, CACurrentMediaTime(), duration, easeIn)
        if displayLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(step))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }
    }

    @objc private func step() {
        guard let animation else { return }
        let progress = min((CACurrentMediaTime() - animation.start) / animation.duration, 1)
        let eased = animation.easeIn
            ? progress * progress
            : progress * progress * (3 - 2 * progress)
        let time = animation.from + (animation.to - animation.from) * eased
        curlView.layer.contents = renderer.frame(at: time)
        guard progress >= 1 else { return }
        self.animation = nil
        displayLink?.invalidate()
        displayLink = nil
        if animation.to == 0 {
            // Flat again: back to the real cover.
            cover.isHidden = false
            curlView.isHidden = true
            curlView.layer.contents = nil
        }
    }
}

/// Core Image's page curl, set up once for a pair of pages and then drawn at any point of the turn.
private final class CurlRenderer {
    private let context = CIContext(options: [.cacheIntermediates: false])
    private let filter = CIFilter.pageCurlTransition()
    private var extent: CGRect = .zero

    func prepare(from: CGImage, to: CGImage, back: CGImage, angle: CGFloat) {
        let front = CIImage(cgImage: from)
        extent = front.extent
        filter.inputImage = front
        filter.targetImage = CIImage(cgImage: to)
        filter.backsideImage = CIImage(cgImage: back)
        // The shading image is the shine on the curl. A clear one means no white shine at all.
        filter.shadingImage = CIImage(color: .clear).cropped(to: extent)
        filter.extent = extent
        filter.angle = Float(angle)
        filter.radius = Float(extent.width * 0.12)
    }

    func frame(at time: CGFloat) -> CGImage? {
        filter.time = Float(min(max(time, 0), 1))
        guard let output = filter.outputImage?.cropped(to: extent) else { return nil }
        return context.createCGImage(output, from: extent)
    }
}
