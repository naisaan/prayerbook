import SwiftUI
import UIKit

/// On the cover, until the reader turns it for the first time, the page curls back from its
/// bottom corner, as if a finger had pulled it partway, showing the next page beneath, and
/// then falls flat again. It repeats every few seconds and never turns the page itself.
///
/// The curl is Core Animation's own page curl, the same one the book uses when a page is
/// turned, so it looks the same and draws the real pages in light or dark mode.
struct CoverCurlHint: UIViewRepresentable {
    let book: Book
    let isRightToLeft: Bool

    func makeUIView(context: Context) -> CoverCurlHintView {
        CoverCurlHintView(book: book, isRightToLeft: isRightToLeft)
    }

    func updateUIView(_ view: CoverCurlHintView, context: Context) {}
}

final class CoverCurlHintView: UIView {
    private let cover: BookPageView
    private let nextPage: BookPageView
    private let isRightToLeft: Bool
    private var loop: Task<Void, Never>?

    /// How far the page curls back, out of a whole turn.
    private static let curlAmount: Float = 0.35

    init(book: Book, isRightToLeft: Bool) {
        cover = BookPageView(book: book, index: 0, showsTotal: false)
        nextPage = BookPageView(book: book, index: min(1, book.pages.count - 1), showsTotal: false)
        self.isRightToLeft = isRightToLeft
        super.init(frame: CGRect(origin: .zero, size: book.metrics.size))
        isUserInteractionEnabled = false
        backgroundColor = .clear
        for page in [nextPage, cover] {
            page.frame = bounds
            page.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(page)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        loop?.cancel()
        guard window != nil else { return }
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
        let transition = CATransition()
        transition.type = CATransitionType(rawValue: "pageCurl")
        transition.subtype = isRightToLeft ? .fromLeft : .fromRight
        transition.duration = 1.0
        transition.startProgress = 0
        transition.endProgress = Self.curlAmount
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        transition.fillMode = .forwards
        transition.isRemovedOnCompletion = false
        layer.add(transition, forKey: "curl")
        cover.isHidden = true
    }

    /// Lets go: the cover falls back flat from where it was held.
    private func uncurl() {
        layer.removeAnimation(forKey: "curl")
        let transition = CATransition()
        transition.type = CATransitionType(rawValue: "pageUnCurl")
        transition.subtype = isRightToLeft ? .fromLeft : .fromRight
        transition.duration = 0.6
        transition.startProgress = 1 - Self.curlAmount
        transition.endProgress = 1
        transition.timingFunction = CAMediaTimingFunction(name: .easeIn)
        layer.add(transition, forKey: "uncurl")
        cover.isHidden = false
    }
}
