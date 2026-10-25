import SwiftUI
import UIKit

/// Draws one page: the section name at the top, the text, the drop cap and the page number.
final class BookPageView: UIView {
    private let book: Book
    private let index: Int

    init(book: Book, index: Int) {
        self.book = book
        self.index = index
        super.init(frame: CGRect(origin: .zero, size: book.metrics.size))
        backgroundColor = .systemBackground
        isOpaque = true
        contentMode = .redraw

        let page = book.pages[index]
        isAccessibilityElement = true
        accessibilityLabel = (page.layout.storage.string as NSString).substring(with: page.characterRange)

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
        let origin = metrics.textRect.origin
        let layout = page.layout

        let glyphs = layout.layoutManager.glyphRange(for: layout.containers[page.pageInPrayer])
        layout.layoutManager.drawBackground(forGlyphRange: glyphs, at: origin)
        layout.layoutManager.drawGlyphs(forGlyphRange: glyphs, at: origin)

        if let dropCap = layout.dropCap, dropCap.containerIndex == page.pageInPrayer {
            dropCap.letter.draw(at: CGPoint(x: origin.x + dropCap.origin.x, y: origin.y + dropCap.origin.y))
        }

        drawCentered(page.sectionName, in: metrics.headerRect, font: .systemFont(ofSize: 13, weight: .medium))
        drawCentered("\(index + 1) of \(book.pages.count)", in: metrics.footerRect, font: .monospacedDigitSystemFont(ofSize: 13, weight: .regular))
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

/// Hosts one page inside the page curl controller. Taps in the middle of the page show or
/// hide the reading controls; taps near the edges turn the page.
final class PageViewController: UIViewController, UIGestureRecognizerDelegate {
    let index: Int
    private let book: Book
    var onCenterTap: (() -> Void)?

    init(book: Book, index: Int) {
        self.book = book
        self.index = index
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func loadView() {
        view = BookPageView(book: book, index: index)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }

    @objc private func handleTap() {
        onCenterTap?()
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let x = gestureRecognizer.location(in: view).x
        let width = view.bounds.width
        return x > width * 0.25 && x < width * 0.75
    }
}

/// Apple's real page curl (the same one Apple Books uses), brought into SwiftUI.
/// With Reduce Motion turned on, pages slide instead of curling.
struct PageCurlView: UIViewControllerRepresentable {
    let book: Book
    @Binding var currentPage: Int
    var reduceMotion: Bool
    var onCenterTap: () -> Void
    var onPageTurn: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        var options: [UIPageViewController.OptionsKey: Any] = [:]
        if !reduceMotion {
            options[.spineLocation] = UIPageViewController.SpineLocation.min.rawValue
        }
        let controller = UIPageViewController(
            transitionStyle: reduceMotion ? .scroll : .pageCurl,
            navigationOrientation: .horizontal,
            options: options
        )
        controller.isDoubleSided = false
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        controller.view.backgroundColor = .systemBackground
        context.coordinator.bookID = book.id
        controller.setViewControllers([context.coordinator.makePage(currentPage)], direction: .forward, animated: false)
        return controller
    }

    func updateUIViewController(_ controller: UIPageViewController, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        if coordinator.bookID != book.id {
            // The book was paginated again (new font, size or languages).
            coordinator.bookID = book.id
            controller.setViewControllers([coordinator.makePage(currentPage)], direction: .forward, animated: false)
        } else if let shown = controller.viewControllers?.first as? PageViewController, shown.index != currentPage {
            // Jump to a page chosen from Contents, Bookmarks or Search.
            let direction: UIPageViewController.NavigationDirection = currentPage > shown.index ? .forward : .reverse
            controller.setViewControllers([coordinator.makePage(currentPage)], direction: direction, animated: true)
        }
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: PageCurlView
        var bookID: UUID?

        init(parent: PageCurlView) {
            self.parent = parent
        }

        func makePage(_ index: Int) -> PageViewController {
            let clamped = min(max(index, 0), parent.book.pages.count - 1)
            let page = PageViewController(book: parent.book, index: clamped)
            page.onCenterTap = { [weak self] in self?.parent.onCenterTap() }
            return page
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let page = viewController as? PageViewController, page.index > 0 else { return nil }
            return makePage(page.index - 1)
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let page = viewController as? PageViewController, page.index + 1 < parent.book.pages.count else { return nil }
            return makePage(page.index + 1)
        }

        func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
            parent.onPageTurn()
        }

        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            guard completed, let page = pageViewController.viewControllers?.first as? PageViewController else { return }
            parent.currentPage = page.index
        }
    }
}
