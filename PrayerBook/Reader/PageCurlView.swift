import SwiftUI
import UIKit

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

/// Hosts one page inside the page curl controller. Taps in the middle of the page show or
/// hide the reading controls; taps near the edges turn the page.
final class PageViewController: UIViewController, UIGestureRecognizerDelegate {
    let index: Int
    private let book: Book
    private let initialShowsTotal: Bool
    var onCenterTap: (() -> Void)?

    init(book: Book, index: Int, showsTotal: Bool) {
        self.book = book
        self.index = index
        self.initialShowsTotal = showsTotal
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func loadView() {
        view = BookPageView(book: book, index: index, showsTotal: initialShowsTotal)
    }

    var showsTotal: Bool {
        get { (viewIfLoaded as? BookPageView)?.showsTotal ?? initialShowsTotal }
        set { (viewIfLoaded as? BookPageView)?.showsTotal = newValue }
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

/// The back of a page, seen while it curls over. Like a real sheet of paper (and Apple Books),
/// it's the page color with the front's text faintly showing through, mirrored.
final class BackPageViewController: UIViewController {
    let index: Int
    private let book: Book

    init(book: Book, index: Int) {
        self.book = book
        self.index = index
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func loadView() {
        let container = UIView(frame: CGRect(origin: .zero, size: book.metrics.size))
        container.backgroundColor = Typography.pageColor

        let showThrough = BookPageView(book: book, index: index, showsTotal: false)
        showThrough.frame = container.bounds
        showThrough.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        showThrough.transform = CGAffineTransform(scaleX: -1, y: 1)
        showThrough.alpha = 0.12
        showThrough.isAccessibilityElement = false
        container.addSubview(showThrough)

        view = container
    }
}

/// Apple's real page curl (the same one Apple Books uses), brought into SwiftUI.
/// With Reduce Motion turned on, pages slide instead of curling.
struct PageCurlView: UIViewControllerRepresentable {
    let book: Book
    @Binding var currentPage: Int
    var showsTotal: Bool
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
        // Double-sided so the back of a curling page is a real, dark-in-dark-mode page.
        controller.isDoubleSided = !reduceMotion
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        controller.view.backgroundColor = Typography.pageColor
        context.coordinator.bookID = book.id
        context.coordinator.show(currentPage, in: controller, from: nil, animated: false)
        return controller
    }

    func updateUIViewController(_ controller: UIPageViewController, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        for case let page as PageViewController in controller.viewControllers ?? [] {
            page.showsTotal = showsTotal
        }

        if coordinator.bookID != book.id {
            // The book was paginated again (new font, size or languages).
            coordinator.bookID = book.id
            coordinator.show(currentPage, in: controller, from: nil, animated: false)
        } else if let shown = coordinator.shownIndex(in: controller), shown != currentPage {
            // Jump to a page chosen from Contents, Bookmarks or Search.
            coordinator.show(currentPage, in: controller, from: shown, animated: true)
        }
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: PageCurlView
        var bookID: UUID?

        init(parent: PageCurlView) {
            self.parent = parent
        }

        private var pageCount: Int { parent.book.pages.count }

        private func clamped(_ index: Int) -> Int {
            min(max(index, 0), pageCount - 1)
        }

        func makePage(_ index: Int) -> PageViewController {
            let page = PageViewController(book: parent.book, index: clamped(index), showsTotal: parent.showsTotal)
            page.onCenterTap = { [weak self] in self?.parent.onCenterTap() }
            return page
        }

        func makeBack(_ index: Int) -> BackPageViewController {
            BackPageViewController(book: parent.book, index: clamped(index))
        }

        func shownIndex(in controller: UIPageViewController) -> Int? {
            (controller.viewControllers?.first as? PageViewController)?.index
        }

        func show(_ index: Int, in controller: UIPageViewController, from previous: Int?, animated: Bool) {
            let forward = previous.map { index > $0 } ?? true
            var controllers: [UIViewController] = [makePage(index)]
            if controller.isDoubleSided {
                // With a double-sided curl, UIKit also wants the back of the page being turned.
                controllers.append(makeBack(forward ? (previous ?? index - 1) : index))
            }
            controller.setViewControllers(controllers, direction: forward ? .forward : .reverse, animated: animated)
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            if let back = viewController as? BackPageViewController {
                return makePage(back.index)
            }
            guard let page = viewController as? PageViewController, page.index > 0 else { return nil }
            return pageViewController.isDoubleSided ? makeBack(page.index - 1) : makePage(page.index - 1)
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            if let back = viewController as? BackPageViewController {
                return back.index + 1 < pageCount ? makePage(back.index + 1) : nil
            }
            guard let page = viewController as? PageViewController else { return nil }
            if pageViewController.isDoubleSided {
                return page.index + 1 < pageCount ? makeBack(page.index) : nil
            }
            return page.index + 1 < pageCount ? makePage(page.index + 1) : nil
        }

        func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
            parent.onPageTurn()
        }

        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            guard completed, let index = shownIndex(in: pageViewController) else { return }
            parent.currentPage = index
        }
    }
}
