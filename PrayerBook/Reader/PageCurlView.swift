import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Draws one page: the section name at the top, the text, the drop cap and the page number.
/// A section's first page shows just the section's name.
final class BookPageView: UIView {
    private let book: Book
    private let index: Int

    /// Shows "12 of 340" instead of just "12" while the reading controls are visible.
    var showsTotal: Bool {
        didSet { if showsTotal != oldValue { setNeedsDisplay() } }
    }

    init(book: Book, index: Int, showsTotal: Bool) {
        self.book = book
        self.index = index
        self.showsTotal = showsTotal
        super.init(frame: CGRect(origin: .zero, size: book.metrics.size))
        backgroundColor = Typography.pageColor
        isOpaque = true
        contentMode = .redraw

        let page = book.pages[index]
        isAccessibilityElement = true
        if let prayerPage = page.prayerPage {
            accessibilityLabel = (prayerPage.layout.storage.string as NSString).substring(with: prayerPage.characterRange)
        } else {
            accessibilityLabel = page.sectionName
            accessibilityTraits = .header
        }

        // Redraw when switching between light and dark so the text flips between black and white.
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _: UITraitCollection) in
            self.setNeedsDisplay()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func draw(_ rect: CGRect) {
        let page = book.pages[index]
        let metrics = book.metrics

        switch page.content {
        case .sectionTitle:
            drawSectionTitle(page.sectionName)
        case .prayer(let prayerPage):
            drawPrayerPage(prayerPage, origin: metrics.textRect.origin)
            drawCentered(page.sectionName, in: metrics.headerRect, font: .systemFont(ofSize: 13, weight: .medium))
        }

        let number = showsTotal ? "\(index + 1) of \(book.pages.count)" : "\(index + 1)"
        drawCentered(number, in: metrics.footerRect, font: .monospacedDigitSystemFont(ofSize: 13, weight: .regular))
    }

    private func drawPrayerPage(_ prayerPage: PrayerPage, origin: CGPoint) {
        let layout = prayerPage.layout
        let glyphs = layout.layoutManager.glyphRange(for: layout.containers[prayerPage.pageInPrayer])
        layout.layoutManager.drawBackground(forGlyphRange: glyphs, at: origin)
        layout.layoutManager.drawGlyphs(forGlyphRange: glyphs, at: origin)

        if let dropCap = layout.dropCap, dropCap.containerIndex == prayerPage.pageInPrayer {
            dropCap.letter.draw(at: CGPoint(x: origin.x + dropCap.origin.x, y: origin.y + dropCap.origin.y))
        }
    }

    /// The section's name, large and centered, with a thin line beneath it.
    private func drawSectionTitle(_ name: String) {
        let typography = book.typography
        let textRect = book.metrics.textRect

        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineHeightMultiple = 1.05
        let title = NSAttributedString(string: name, attributes: [
            .font: typography.font.uiFont(size: typography.size * 1.9),
            .foregroundColor: Typography.textColor,
            .paragraphStyle: style,
            .kern: -0.4,
        ])
        let bounds = title.boundingRect(
            with: CGSize(width: textRect.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        // Sit a little above the middle of the page, like a chapter opening.
        let top = textRect.minY + textRect.height * 0.38 - bounds.height / 2
        title.draw(with: CGRect(x: textRect.minX, y: top, width: textRect.width, height: ceil(bounds.height)),
                   options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)

        let lineWidth: CGFloat = 44
        let lineY = top + ceil(bounds.height) + typography.size * 1.1
        let line = UIBezierPath(rect: CGRect(x: textRect.midX - lineWidth / 2, y: lineY, width: lineWidth, height: 1))
        Typography.secondaryColor.setFill()
        line.fill()
    }

    private func drawCentered(_ string: String, in rect: CGRect, font: UIFont) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byTruncatingTail
        (string as NSString).draw(in: rect, withAttributes: [
            .font: font,
            .foregroundColor: UIColor.secondaryLabel,
            .paragraphStyle: style,
        ])
    }
}


/// Draws the page curl with Core Image. UIKit's built-in curl adds a bright white shine that
/// can't be turned off, which looks wrong on dark pages. Here we choose the lighting, so a page
/// curls like paper in Apple Books: the back is the page color with its text faintly showing through.
final class CurlRenderer {
    private let context = CIContext(options: [.cacheIntermediates: false])
    private let filter = CIFilter.pageCurlTransition()
    private var extent: CGRect = .zero

    func prepare(from: CGImage, to: CGImage, back: CGImage, angle: CGFloat) {
        let front = CIImage(cgImage: from)
        extent = front.extent
        filter.inputImage = front
        filter.targetImage = CIImage(cgImage: to)
        filter.backsideImage = CIImage(cgImage: back)
        // The shading image is the shine on the curl. A clear one means no shine at all.
        filter.shadingImage = CIImage(color: .clear).cropped(to: extent)
        filter.extent = extent
        filter.angle = Float(angle)
        filter.radius = Float(extent.width * 0.12)
    }

    /// The curl at a moment of the turn, from 0 (flat) to 1 (turned over).
    func frame(at time: CGFloat) -> CGImage? {
        filter.time = Float(min(max(time, 0), 1))
        guard let output = filter.outputImage?.cropped(to: extent) else { return nil }
        return context.createCGImage(output, from: extent)
    }
}

/// Shows one page at a time and turns pages with a curl that follows your finger.
/// Taps near the edges turn the page; taps in the middle show or hide the reading controls.
/// With Reduce Motion turned on, pages fade instead of curling.
final class BookReaderController: UIViewController, UIGestureRecognizerDelegate {
    private(set) var book: Book
    private(set) var index: Int
    var reduceMotion = false
    var showsTotal = false {
        didSet { pageView?.showsTotal = showsTotal }
    }
    var onCenterTap: () -> Void = {}
    var onPageTurn: () -> Void = {}
    var onPageChange: (Int) -> Void = { _ in }

    private var pageView: BookPageView?
    private let curlView = UIView()
    private let renderer = CurlRenderer()
    private var turn: Turn?
    private var animation: TurnAnimation?
    private var displayLink: CADisplayLink?

    private struct Turn {
        let target: Int
        let forward: Bool
        /// 0 shows the earlier page flat, 1 shows it turned over, revealing the later page.
        var time: CGFloat
        /// The time at which the target page is fully showing.
        var doneTime: CGFloat { forward ? 1 : 0 }
    }

    private struct TurnAnimation {
        let from: CGFloat
        let to: CGFloat
        let start: CFTimeInterval
        let duration: CFTimeInterval
    }

    init(book: Book, index: Int) {
        self.book = book
        self.index = min(max(index, 0), book.pages.count - 1)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Typography.pageColor

        curlView.isHidden = true
        curlView.isUserInteractionEnabled = false
        curlView.layer.contentsGravity = .resize
        view.addSubview(curlView)
        showPage()

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        view.addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        pan.delegate = self
        view.addGestureRecognizer(pan)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        pageView?.frame = view.bounds
        curlView.frame = view.bounds
    }

    /// Shows a book paginated again (new font, size or languages), without a turn.
    func setBook(_ book: Book, index: Int) {
        endTurn(completed: false)
        self.book = book
        self.index = min(max(index, 0), book.pages.count - 1)
        showPage()
    }

    /// Turns to a page chosen from Contents, Bookmarks or Search, or by tapping an edge.
    func turn(to page: Int) {
        finishTurnNow()
        let target = min(max(page, 0), book.pages.count - 1)
        guard target != index else { return }
        if reduceMotion {
            fade(to: target)
        } else if beginTurn(to: target, touchY: 0.75), let turn {
            animate(to: turn.doneTime, duration: 0.55)
        } else {
            commit(target)
        }
    }

    // MARK: Gestures

    @objc private func handleTap(_ tap: UITapGestureRecognizer) {
        let x = tap.location(in: view).x / max(view.bounds.width, 1)
        if x < 0.25 {
            turn(to: index - 1)
        } else if x > 0.75 {
            turn(to: index + 1)
        } else {
            onCenterTap()
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: view)
        return abs(velocity.x) > abs(velocity.y)
    }

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        let dx = pan.translation(in: view).x
        let distance = max(view.bounds.width * 0.85, 1)

        switch pan.state {
        case .began:
            finishTurnNow()
            let target = dx < 0 ? index + 1 : index - 1
            guard book.pages.indices.contains(target) else { return }
            if reduceMotion { return }
            let touchY = pan.location(in: view).y / max(view.bounds.height, 1)
            _ = beginTurn(to: target, touchY: touchY)

        case .changed:
            guard let turn, animation == nil else { return }
            let progress = min(max((turn.forward ? -dx : dx) / distance, 0), 1)
            setTime(turn.forward ? progress : 1 - progress)

        case .ended, .cancelled, .failed:
            let velocity = pan.velocity(in: view).x
            if reduceMotion {
                let target = dx < 0 ? index + 1 : index - 1
                if pan.state == .ended, abs(dx) > 40, book.pages.indices.contains(target) {
                    fade(to: target)
                }
                return
            }
            guard let turn, animation == nil else { return }
            // How far the page has turned toward the new page, from 0 to 1.
            let turned = turn.forward ? turn.time : 1 - turn.time
            let flick = turn.forward ? -velocity : velocity
            let completes = pan.state == .ended && (flick > 300 || (turned > 0.4 && flick > -300))
            let goal = completes ? turn.doneTime : 1 - turn.doneTime
            animate(to: goal, duration: max(0.18, 0.4 * abs(goal - turn.time)))

        default:
            break
        }
    }

    // MARK: Turning

    /// Takes pictures of the two pages and sets up the curl. The earlier page is always the one
    /// that curls: turning forward it curls away, turning back it uncurls into place.
    private func beginTurn(to target: Int, touchY: CGFloat) -> Bool {
        let forward = target > index
        let earlier = forward ? index : target
        let later = forward ? target : index
        guard let front = snapshot(of: earlier),
              let revealed = snapshot(of: later)?.cgImage,
              let back = backSnapshot(of: front),
              let frontImage = front.cgImage else { return false }

        // Curl along a slight diagonal, led by the corner nearest your finger, like a real page.
        let angle = CGFloat.pi - (touchY - 0.5) * 0.5
        renderer.prepare(from: frontImage, to: revealed, back: back, angle: angle)
        turn = Turn(target: target, forward: forward, time: forward ? 0 : 1)
        onPageTurn()
        setTime(forward ? 0 : 1)
        curlView.isHidden = false
        return true
    }

    private func setTime(_ time: CGFloat) {
        guard turn != nil else { return }
        turn?.time = time
        curlView.layer.contents = renderer.frame(at: time)
    }

    private func animate(to goal: CGFloat, duration: CFTimeInterval) {
        guard let turn else { return }
        animation = TurnAnimation(from: turn.time, to: goal, start: CACurrentMediaTime(), duration: duration)
        if displayLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(step))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }
    }

    @objc private func step(_ link: CADisplayLink) {
        guard let animation, let turn else {
            endTurn(completed: false)
            return
        }
        let progress = min((CACurrentMediaTime() - animation.start) / animation.duration, 1)
        let eased = 1 - pow(1 - progress, 3)
        setTime(animation.from + (animation.to - animation.from) * eased)
        if progress >= 1 {
            endTurn(completed: animation.to == turn.doneTime)
        }
    }

    /// Jumps a turn that's still animating straight to its end.
    private func finishTurnNow() {
        guard let turn else { return }
        endTurn(completed: animation?.to == turn.doneTime)
    }

    private func endTurn(completed: Bool) {
        displayLink?.invalidate()
        displayLink = nil
        animation = nil
        let target = turn?.target
        turn = nil
        if completed, let target {
            commit(target)
        }
        curlView.isHidden = true
        curlView.layer.contents = nil
    }

    private func commit(_ target: Int) {
        index = target
        showPage()
        onPageChange(target)
    }

    private func fade(to target: Int) {
        onPageTurn()
        UIView.transition(with: view, duration: 0.25, options: [.transitionCrossDissolve, .allowUserInteraction]) {
            self.index = target
            self.showPage()
        }
        onPageChange(target)
    }

    private func showPage() {
        let page = BookPageView(book: book, index: index, showsTotal: showsTotal)
        page.frame = view.bounds
        page.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(page, belowSubview: curlView)
        pageView?.removeFromSuperview()
        pageView = page
    }

    // MARK: Pictures of pages

    private var snapshotFormat: UIGraphicsImageRendererFormat {
        let format = UIGraphicsImageRendererFormat()
        // Twice the point size keeps the curl smooth; the page itself stays full sharpness.
        format.scale = min(traitCollection.displayScale, 2)
        format.opaque = true
        return format
    }

    private func snapshot(of index: Int) -> UIImage? {
        let size = book.metrics.size
        guard size.width > 0, size.height > 0 else { return nil }
        let page = BookPageView(book: book, index: index, showsTotal: false)
        page.overrideUserInterfaceStyle = traitCollection.userInterfaceStyle
        return UIGraphicsImageRenderer(size: size, format: snapshotFormat).image { context in
            traitCollection.performAsCurrent {
                Typography.pageColor.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                page.draw(page.bounds)
            }
        }
    }

    /// The back of a page: the page color with its text faintly showing through.
    /// Core Image mirrors it as the page turns over, like real paper.
    private func backSnapshot(of front: UIImage) -> CGImage? {
        let size = front.size
        return UIGraphicsImageRenderer(size: size, format: snapshotFormat).image { context in
            traitCollection.performAsCurrent {
                Typography.pageColor.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                front.draw(at: .zero, blendMode: .normal, alpha: 0.28)
            }
        }.cgImage
    }
}

/// The book reader, brought into SwiftUI.
struct PageCurlView: UIViewControllerRepresentable {
    let book: Book
    @Binding var currentPage: Int
    var showsTotal: Bool
    var reduceMotion: Bool
    var onCenterTap: () -> Void
    var onPageTurn: () -> Void

    func makeUIViewController(context: Context) -> BookReaderController {
        let controller = BookReaderController(book: book, index: currentPage)
        configure(controller)
        return controller
    }

    func updateUIViewController(_ controller: BookReaderController, context: Context) {
        configure(controller)
        if controller.book !== book {
            controller.setBook(book, index: currentPage)
        } else if controller.index != currentPage {
            controller.turn(to: currentPage)
        }
    }

    private func configure(_ controller: BookReaderController) {
        controller.reduceMotion = reduceMotion
        controller.showsTotal = showsTotal
        controller.onCenterTap = onCenterTap
        controller.onPageTurn = onPageTurn
        let currentPage = $currentPage
        controller.onPageChange = { currentPage.wrappedValue = $0 }
    }
}
