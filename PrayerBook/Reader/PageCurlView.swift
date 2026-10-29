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
        if let textPage = page.textPage {
            accessibilityLabel = (textPage.layout.storage.string as NSString).substring(with: textPage.characterRange)
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
            drawTitle(page.sectionName, opening: false)
        case .prayer(let prayerPage):
            drawPrayerPage(prayerPage, origin: metrics.textRect.origin)
            drawCentered(page.sectionName, in: metrics.headerRect, font: .systemFont(ofSize: 13, weight: .medium))
        case .opening(let prayerPage):
            if prayerPage.pageInPrayer == 0 {
                drawTitle(page.sectionName, opening: true)
            } else {
                drawCentered(page.sectionName, in: metrics.headerRect, font: .systemFont(ofSize: 13, weight: .medium))
            }
            drawPrayerPage(prayerPage, origin: metrics.textRect.origin)
        }

        let number = showsTotal ? String(localized: "\(index + 1) of \(book.pages.count)") : "\(index + 1)"
        drawCentered(number, in: metrics.footerRect, font: .monospacedDigitSystemFont(ofSize: 13, weight: .regular))
    }

    /// The prayer a link at this point opens, if there's a link there.
    func prayerLink(at point: CGPoint) -> Int? {
        guard let prayerPage = book.pages[index].prayerPage else { return nil }
        let layout = prayerPage.layout
        let container = layout.containers[prayerPage.pageInPrayer]
        let origin = book.metrics.textRect.origin
        let local = CGPoint(x: point.x - origin.x, y: point.y - origin.y)
        let glyph = layout.layoutManager.glyphIndex(for: local, in: container)
        let character = layout.layoutManager.characterIndexForGlyph(at: glyph)
        guard character < layout.storage.length,
              let prayerID = layout.storage.attribute(.prayerLink, at: character, effectiveRange: nil) as? Int
        else { return nil }
        // Only count taps on the link itself, with a little room around it for a fingertip.
        let box = layout.layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: container)
        let lineRange = layout.layoutManager.lineFragmentUsedRect(forGlyphAt: glyph, effectiveRange: nil)
        let target = box.union(lineRange).insetBy(dx: -12, dy: -12)
        return target.contains(local) ? prayerID : nil
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

    /// A title, large and centered, with a thin line beneath it. A section's title sits a little
    /// above the middle of the page, like a chapter opening; the book's title sits near the top,
    /// above the opening verse.
    private func drawTitle(_ name: String, opening: Bool) {
        let typography = book.typography
        let textRect = book.metrics.textRect

        let title = TitlePage.title(name, typography: typography)
        let height = TitlePage.height(of: title, width: textRect.width)
        let top = opening
            ? textRect.minY + TitlePage.openingTitleOffset(textHeight: textRect.height)
            : textRect.minY + textRect.height * 0.38 - height / 2
        title.draw(with: CGRect(x: textRect.minX, y: top, width: textRect.width, height: height),
                   options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)

        let lineWidth: CGFloat = 44
        let lineY = top + height + TitlePage.lineGap(typography)
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
    /// True when the whole book is mirrored to turn right to left; the page is mirrored back
    /// so its text still reads normally.
    private let isMirrored: Bool
    private var pageView: BookPageView?
    var onCenterTap: (() -> Void)?
    var onOpenPrayer: ((Int) -> Void)?

    init(book: Book, index: Int, showsTotal: Bool, isMirrored: Bool) {
        self.book = book
        self.index = index
        self.initialShowsTotal = showsTotal
        self.isMirrored = isMirrored
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func loadView() {
        let container = UIView(frame: CGRect(origin: .zero, size: book.metrics.size))
        container.backgroundColor = Typography.pageColor
        let page = BookPageView(book: book, index: index, showsTotal: initialShowsTotal)
        page.frame = container.bounds
        page.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        if isMirrored { page.transform = CGAffineTransform(scaleX: -1, y: 1) }
        container.addSubview(page)
        pageView = page
        view = container
    }

    var showsTotal: Bool {
        get { pageView?.showsTotal ?? initialShowsTotal }
        set { pageView?.showsTotal = newValue }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }

    /// The prayer a link at this point (in this controller's view) opens, if there's a link there.
    func prayerLink(at point: CGPoint) -> Int? {
        guard let pageView else { return nil }
        return pageView.prayerLink(at: pageView.convert(point, from: view))
    }

    @objc private func handleTap(_ tap: UITapGestureRecognizer) {
        if let prayerID = prayerLink(at: tap.location(in: view)) {
            onOpenPrayer?(prayerID)
        } else {
            onCenterTap?()
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if prayerLink(at: gestureRecognizer.location(in: view)) != nil { return true }
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
    private let isMirrored: Bool

    init(book: Book, index: Int, isMirrored: Bool) {
        self.book = book
        self.index = index
        self.isMirrored = isMirrored
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
        // In a mirrored book the whole controller is already flipped, which mirrors this too.
        showThrough.transform = isMirrored ? .identity : CGAffineTransform(scaleX: -1, y: 1)
        showThrough.alpha = 0.12
        showThrough.isAccessibilityElement = false
        container.addSubview(showThrough)

        view = container
    }
}

/// Apple's real page curl (the same one Apple Books uses), brought into SwiftUI.
/// With Reduce Motion turned on, pages slide instead of curling.
/// A right-to-left book (Persian) is the same controller mirrored: the spine sits on the right
/// and pages turn from left to right, while each page is mirrored back so it reads normally.
struct PageCurlView: UIViewControllerRepresentable {
    let book: Book
    @Binding var currentPage: Int
    var isRightToLeft: Bool
    var showsTotal: Bool
    var reduceMotion: Bool
    var onCenterTap: () -> Void
    var onPageTurn: () -> Void
    var onOpenPrayer: (Int) -> Void

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
        // The mirroring is done by hand below, so UIKit must not flip anything on its own.
        controller.view.semanticContentAttribute = .forceLeftToRight
        controller.view.transform = isRightToLeft ? CGAffineTransform(scaleX: -1, y: 1) : .identity
        context.coordinator.isMirrored = isRightToLeft
        // A tap on a link opens it instead of turning the page.
        for case let tap as UITapGestureRecognizer in controller.gestureRecognizers {
            tap.delegate = context.coordinator
        }
        context.coordinator.pageController = controller
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

        if coordinator.bookID != book.id || coordinator.isMirrored != isRightToLeft {
            // The book was paginated again (new font, size or languages), or changed direction.
            coordinator.bookID = book.id
            coordinator.isMirrored = isRightToLeft
            controller.view.transform = isRightToLeft ? CGAffineTransform(scaleX: -1, y: 1) : .identity
            coordinator.show(currentPage, in: controller, from: nil, animated: false)
        } else if let shown = coordinator.shownIndex(in: controller), shown != currentPage {
            // Jump to a page chosen from Contents, Bookmarks or Search.
            coordinator.show(currentPage, in: controller, from: shown, animated: true)
        }
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate, UIGestureRecognizerDelegate {
        var parent: PageCurlView
        var bookID: UUID?
        var isMirrored = false
        weak var pageController: UIPageViewController?

        init(parent: PageCurlView) {
            self.parent = parent
        }

        private var pageCount: Int { parent.book.pages.count }

        private func clamped(_ index: Int) -> Int {
            min(max(index, 0), pageCount - 1)
        }

        func makePage(_ index: Int) -> PageViewController {
            let page = PageViewController(book: parent.book, index: clamped(index), showsTotal: parent.showsTotal, isMirrored: isMirrored)
            page.onCenterTap = { [weak self] in self?.parent.onCenterTap() }
            page.onOpenPrayer = { [weak self] in self?.parent.onOpenPrayer($0) }
            return page
        }

        func makeBack(_ index: Int) -> BackPageViewController {
            BackPageViewController(book: parent.book, index: clamped(index), isMirrored: isMirrored)
        }

        /// Stops the page curl's own taps from turning the page when the tap is on a link.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let page = pageController?.viewControllers?.first as? PageViewController else { return true }
            return page.prayerLink(at: gestureRecognizer.location(in: page.view)) == nil
        }

        func shownIndex(in controller: UIPageViewController) -> Int? {
            (controller.viewControllers?.first as? PageViewController)?.index
        }

        func show(_ index: Int, in controller: UIPageViewController, from previous: Int?, animated: Bool) {
            let forward = previous.map { index > $0 } ?? true
            var controllers: [UIViewController] = [makePage(index)]
            // A double-sided curl needs the back of the turning page, but only when the
            // change is animated. Without animation UIKit takes just the front page.
            if controller.isDoubleSided && animated {
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
