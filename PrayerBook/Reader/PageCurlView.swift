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
        NotificationCenter.default.addObserver(self, selector: #selector(highlightsDidChange), name: .highlightsDidChange, object: nil)
    }

    @objc private func highlightsDidChange() {
        setNeedsDisplay()
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

    // MARK: Highlights

    /// One line of a highlighted passage, in this view's coordinates.
    struct HighlightLine {
        let minX: CGFloat
        let maxX: CGFloat
        let baseline: CGFloat
        let font: UIFont
        /// Set for the drop cap, which gets a box around just its letter.
        var fixedBox: CGRect? = nil

        /// The rounded box drawn behind the words, from the tops of the tallest letters to
        /// just below the lowest.
        var box: CGRect {
            fixedBox ?? CGRect(x: minX - 2, y: baseline - font.ascender - 1, width: maxX - minX + 4, height: font.ascender - font.descender + 3)
        }
    }

    /// Where the drop cap's letter is on this page, if it's on this page: a box around the
    /// letter, and its baseline.
    var dropCapPlacement: (box: CGRect, baseline: CGFloat)? {
        guard let prayerPage = book.pages[index].textPage,
              let dropCap = prayerPage.layout.dropCap,
              dropCap.containerIndex == prayerPage.pageInPrayer,
              let font = dropCap.letter.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        else { return nil }
        let origin = book.metrics.textRect.origin
        let left = origin.x + dropCap.origin.x
        let baseline = origin.y + dropCap.origin.y + font.ascender
        let width = ceil(dropCap.letter.size().width)
        let box = CGRect(x: left - 3, y: baseline - font.capHeight - 4, width: width + 6, height: font.capHeight + 8)
        return (box, baseline)
    }

    /// The highlighted passages on this page, each with its lines.
    private func highlightedLines() -> [(Highlight, [HighlightLine])] {
        guard let prayerPage = book.pages[index].prayerPage else { return [] }
        return Highlights.shared.highlights(inPrayer: prayerPage.prayer.id).compactMap { highlight in
            let found = lines(for: highlight, in: prayerPage)
            return found.isEmpty ? nil : (highlight, found)
        }
    }

    private func lines(for highlight: Highlight, in prayerPage: PrayerPage) -> [HighlightLine] {
        let layout = prayerPage.layout
        let layoutManager = layout.layoutManager
        let container = layout.containers[prayerPage.pageInPrayer]
        let origin = book.metrics.textRect.origin
        var lines: [HighlightLine] = []

        // The drop cap is drawn on its own, so it gets its own box when the highlight takes it in.
        if let dropCap = layout.dropCap,
           NSLocationInRange(dropCap.characterLocation, highlight.range),
           let placement = dropCapPlacement {
            lines.append(HighlightLine(
                minX: placement.box.minX + 3,
                maxX: placement.box.maxX - 3,
                baseline: placement.baseline,
                font: book.typography.bodyFont,
                fixedBox: placement.box
            ))
        }

        let visible = NSIntersectionRange(layout.storageRange(highlight.range), prayerPage.characterRange)
        guard visible.length > 0 else { return lines }

        let text = layout.storage.string as NSString
        let glyphs = layoutManager.glyphRange(forCharacterRange: visible, actualCharacterRange: nil)
        layoutManager.enumerateLineFragments(forGlyphRange: glyphs) { lineRect, _, lineContainer, lineGlyphs, _ in
            guard lineContainer === container else { return }
            var characters = layoutManager.characterRange(forGlyphRange: NSIntersectionRange(lineGlyphs, glyphs), actualGlyphRange: nil)
            // Leave out spaces and line breaks at the end of the line.
            while characters.length > 0,
                  let last = UnicodeScalar(text.character(at: NSMaxRange(characters) - 1)),
                  CharacterSet.whitespacesAndNewlines.contains(last) {
                characters.length -= 1
            }
            guard characters.length > 0 else { return }
            let part = layoutManager.glyphRange(forCharacterRange: characters, actualCharacterRange: nil)
            let bounds = layoutManager.boundingRect(forGlyphRange: part, in: container)
            let font = layout.storage.attribute(.font, at: characters.location, effectiveRange: nil) as? UIFont
                ?? self.book.typography.bodyFont
            let baseline = lineRect.minY + layoutManager.location(forGlyphAt: part.location).y
            lines.append(HighlightLine(minX: origin.x + bounds.minX, maxX: origin.x + bounds.maxX, baseline: origin.y + baseline, font: font))
        }
        return lines
    }

    /// The highlight at this point, if there's one there.
    func highlight(at point: CGPoint) -> Highlight? {
        highlightedLines().first { _, lines in
            lines.contains { $0.box.insetBy(dx: -4, dy: -4).contains(point) }
        }?.0
    }

    /// The area a highlight covers on this page.
    func frame(of highlightID: UUID) -> CGRect? {
        guard let lines = highlightedLines().first(where: { $0.0.id == highlightID })?.1 else { return nil }
        return lines.map(\.box).reduce(CGRect.null) { $0.union($1) }
    }

    // MARK: Notes

    static let noteMarkerSize: CGFloat = 10

    /// The squares in the margins beside highlights with notes, on the page where each
    /// highlight starts, level with its first line. The first note on the page goes in the
    /// left margin, the next in the right, and so on.
    func noteMarkers() -> [(highlight: Highlight, rect: CGRect)] {
        guard let prayerPage = book.pages[index].prayerPage else { return [] }
        let layout = prayerPage.layout
        let starts = highlightedLines().filter { highlight, _ in
            guard highlight.hasNote else { return false }
            // The drop cap starts the text, so a highlight starting there starts on its page.
            if let dropCap = layout.dropCap, highlight.location <= dropCap.characterLocation {
                return dropCap.containerIndex == prayerPage.pageInPrayer
            }
            return NSLocationInRange(layout.storageRange(highlight.range).location, prayerPage.characterRange)
        }
        let size = Self.noteMarkerSize
        let margin = PageMetrics.sideMargin
        return starts
            .map { highlight, lines in (highlight, lines.map(\.box).min { $0.minY < $1.minY }!) }
            .sorted { $0.1.minY < $1.1.minY }
            .enumerated()
            .map { position, item in
                let centerX = position.isMultiple(of: 2) ? margin / 2 : bounds.width - margin / 2
                let rect = CGRect(x: centerX - size / 2, y: item.1.midY - size / 2, width: size, height: size)
                return (item.0, rect)
            }
    }

    /// The note whose margin square is at this point, with room for a fingertip.
    func noteMarker(at point: CGPoint) -> Highlight? {
        noteMarkers().first { $0.rect.insetBy(dx: -14, dy: -14).contains(point) }?.highlight
    }

    /// The square beside the heading of a prayer's first page when the whole prayer has a
    /// note: a little bigger than a highlight's, in the top left corner.
    func prayerNoteMarker() -> (note: PrayerNote, rect: CGRect)? {
        guard let prayerPage = book.pages[index].prayerPage, prayerPage.pageInPrayer == 0,
              let note = Highlights.shared.prayerNote(for: prayerPage.prayer.id)
        else { return nil }
        let size: CGFloat = 13
        let header = book.metrics.headerRect
        let rect = CGRect(x: PageMetrics.sideMargin / 2 - size / 2, y: header.midY - size / 2, width: size, height: size)
        return (note, rect)
    }

    /// Whether the whole prayer's note square is at this point, with room for a fingertip.
    func prayerNoteMarker(at point: CGPoint) -> PrayerNote? {
        guard let marker = prayerNoteMarker(), marker.rect.insetBy(dx: -14, dy: -14).contains(point) else { return nil }
        return marker.note
    }

    private func drawNoteMarkers() {
        for marker in noteMarkers() {
            marker.highlight.style.markerColor.setFill()
            UIBezierPath(roundedRect: marker.rect, cornerRadius: 2.5).fill()
        }
        if let marker = prayerNoteMarker() {
            marker.note.color.swatch.setFill()
            UIBezierPath(roundedRect: marker.rect, cornerRadius: 3).fill()
        }
    }

    private func drawHighlights() {
        for (highlight, lines) in highlightedLines() {
            for line in lines {
                switch highlight.style {
                case .highlight(let color):
                    color.fill.setFill()
                    UIBezierPath(roundedRect: line.box, cornerRadius: 4).fill()
                case .underline(let color):
                    let size = line.font.pointSize
                    let y = line.baseline + max(3, size * 0.18)
                    let path = UIBezierPath()
                    path.move(to: CGPoint(x: line.minX, y: y))
                    path.addLine(to: CGPoint(x: line.maxX, y: y))
                    path.lineWidth = max(2.5, size * 0.14)
                    path.lineCapStyle = .round
                    color.color.setStroke()
                    path.stroke()
                }
            }
        }
    }

    private func drawPrayerPage(_ prayerPage: PrayerPage, origin: CGPoint) {
        let layout = prayerPage.layout
        let glyphs = layout.layoutManager.glyphRange(for: layout.containers[prayerPage.pageInPrayer])
        layout.layoutManager.drawBackground(forGlyphRange: glyphs, at: origin)
        drawHighlights()
        drawNoteMarkers()
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
/// hide the reading controls; taps near the edges turn the page. Pressing and holding on the
/// text selects it, to highlight or underline it.
final class PageViewController: UIViewController, UIGestureRecognizerDelegate, UITextViewDelegate, UIEditMenuInteractionDelegate {
    let index: Int
    /// Where the page sits in the page curl. The same as `index`, except in a right-to-left
    /// book, where the order is reversed.
    let displayIndex: Int
    private let book: Book
    private let initialShowsTotal: Bool
    var onCenterTap: (() -> Void)?
    var onOpenPrayer: ((Int) -> Void)?
    private var textView: PageTextView?
    /// Sits over the drop cap, which the text view can't select because the letter is drawn
    /// on its own. Pressing and holding it selects the first word, letter included, and it
    /// tints like a selection whenever the selection takes in the letter.
    private var dropCapTarget: UIView?
    private var dropCapMenu: UIEditMenuInteraction?
    /// The colors shown over a highlight while it's being changed.
    private var palette: HighlightPalette?
    /// The menu shown when a highlight is tapped, and the highlight it's for.
    private var highlightMenu: UIEditMenuInteraction?
    private var menuHighlightID: UUID?
    private var highlightMenuIsShowing = false
    /// Sits over the heading at the top of a prayer page. Pressing and holding it offers a
    /// note on the whole prayer.
    private var headingMenu: UIEditMenuInteraction?
    /// Whether text was selected, or the colors were showing, when the latest tap started.
    /// That tap only clears them.
    private var tapStartedBusy = false

    init(book: Book, index: Int, displayIndex: Int, showsTotal: Bool) {
        self.book = book
        self.index = index
        self.displayIndex = displayIndex
        self.initialShowsTotal = showsTotal
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func loadView() {
        view = BookPageView(book: book, index: index, showsTotal: initialShowsTotal)
    }

    private var pageView: BookPageView? { viewIfLoaded as? BookPageView }

    var showsTotal: Bool {
        get { pageView?.showsTotal ?? initialShowsTotal }
        set { pageView?.showsTotal = newValue }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.delegate = self
        view.addGestureRecognizer(tap)
        let highlightMenu = UIEditMenuInteraction(delegate: self)
        view.addInteraction(highlightMenu)
        self.highlightMenu = highlightMenu

        if let prayerPage = book.pages[index].textPage {
            let textView = PageTextView(prayerPage: prayerPage, origin: book.metrics.textRect.origin)
            textView.delegate = self
            view.addSubview(textView)
            self.textView = textView
        }

        if let placement = pageView?.dropCapPlacement, book.pages[index].prayerPage != nil {
            let target = UIView(frame: placement.box)
            target.layer.cornerRadius = 4
            let press = UILongPressGestureRecognizer(target: self, action: #selector(handleDropCapPress))
            target.addGestureRecognizer(press)
            let menu = UIEditMenuInteraction(delegate: self)
            target.addInteraction(menu)
            view.addSubview(target)
            dropCapTarget = target
            dropCapMenu = menu
        }

        if book.pages[index].prayerPage != nil {
            let metrics = book.metrics
            let top = metrics.safeArea.top
            let heading = UIView(frame: CGRect(x: 0, y: top, width: metrics.size.width, height: max(metrics.textRect.minY - top - 4, 24)))
            let press = UILongPressGestureRecognizer(target: self, action: #selector(handleHeadingPress))
            heading.addGestureRecognizer(press)
            let menu = UIEditMenuInteraction(delegate: self)
            heading.addInteraction(menu)
            view.addSubview(heading)
            headingMenu = menu
        }
    }

    // MARK: Prayer notes

    @objc private func handleHeadingPress(_ press: UILongPressGestureRecognizer) {
        guard press.state == .began else { return }
        dismissPalette(animated: true)
        textView?.clearSelection()
        UISelectionFeedbackGenerator().selectionChanged()
        headingMenu?.presentEditMenu(with: UIEditMenuConfiguration(identifier: nil, sourcePoint: press.location(in: press.view)))
    }

    private func headingMenuContents() -> UIMenu? {
        guard let prayer = book.pages[index].prayerPage?.prayer else { return nil }
        let hasNote = Highlights.shared.prayerNote(for: prayer.id) != nil
        let note = UIAction(
            title: hasNote ? String(localized: "Edit Note") : String(localized: "Add Note"),
            image: UIImage(systemName: hasNote ? "note.text" : "note.text.badge.plus")
        ) { [weak self] _ in
            self?.openPrayerNote()
        }
        guard hasNote else { return UIMenu(children: [note]) }
        let remove = UIAction(title: String(localized: "Remove Note"), image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
            Highlights.shared.removePrayerNote(for: prayer.id)
        }
        return UIMenu(children: [note, remove])
    }

    /// Opens the note screen for the whole prayer, quoting its title.
    private func openPrayerNote() {
        guard let prayer = book.pages[index].prayerPage?.prayer else { return }
        dismissPalette(animated: false)
        let subject = NoteEditorView.Subject.prayer(title: prayer.title, note: Highlights.shared.prayerNote(for: prayer.id))
        let editor = UIHostingController(rootView: NoteEditorView(subject: subject, font: book.typography.font) { text, color in
            Highlights.shared.setPrayerNote(text, color: color, for: prayer.id)
        })
        present(editor, animated: true)
    }

    // MARK: Drop cap

    @objc private func handleDropCapPress(_ press: UILongPressGestureRecognizer) {
        guard press.state == .began,
              let textView,
              let location = book.pages[index].prayerPage?.layout.dropCap?.characterLocation
        else { return }
        dismissPalette(animated: true)
        // The first word after the letter. When the letter is a word on its own, like "O",
        // a space comes first.
        let text = textView.textStorage.string as NSString
        let afterLetter = NSRange(location: location, length: text.length - location)
        let wordStart = text.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.inverted, range: afterLetter)
        let start = wordStart.location == NSNotFound ? location : wordStart.location
        let space = text.rangeOfCharacter(from: .whitespacesAndNewlines, range: NSRange(location: start, length: text.length - start))
        let end = space.location == NSNotFound ? text.length : space.location

        // Apple's own "select the word here", the same as pressing and holding a word, so the
        // blue handles and the usual menu appear. The letter joins the selection on its own.
        textView.becomeFirstResponder()
        textView.selectedRange = NSRange(location: start, length: 0)
        textView.select(nil)
        UISelectionFeedbackGenerator().selectionChanged()
        if textView.selectedRange.length == 0 {
            // If iOS didn't select it, select the word ourselves and show the menu.
            textView.selectedRange = NSRange(location: start, length: max(end - start, 0))
            let point = press.location(in: press.view)
            dropCapMenu?.presentEditMenu(with: UIEditMenuConfiguration(identifier: nil, sourcePoint: point))
        }
    }

    func editMenuInteraction(_ interaction: UIEditMenuInteraction, menuFor configuration: UIEditMenuConfiguration, suggestedActions: [UIMenuElement]) -> UIMenu? {
        if interaction === highlightMenu {
            return menuHighlightID.flatMap(menu(forHighlight:))
        }
        if interaction === headingMenu {
            return headingMenuContents()
        }
        guard let textView else { return nil }
        let copy = UIAction(title: String(localized: "Copy"), image: UIImage(systemName: "doc.on.doc")) { [weak textView] _ in
            textView?.copy(nil)
            textView?.clearSelection()
        }
        let menu = self.textView(textView, editMenuForTextIn: textView.selectedRange, suggestedActions: [copy])
        return menu
    }

    func editMenuInteraction(_ interaction: UIEditMenuInteraction, targetRectFor configuration: UIEditMenuConfiguration) -> CGRect {
        if interaction === highlightMenu {
            return menuHighlightID.flatMap { pageView?.frame(of: $0) } ?? .zero
        }
        if interaction === headingMenu {
            return CGRect(origin: configuration.sourcePoint, size: .zero)
        }
        return dropCapTarget?.bounds ?? .zero
    }

    func editMenuInteraction(_ interaction: UIEditMenuInteraction, willPresentMenuFor configuration: UIEditMenuConfiguration, animator: any UIEditMenuInteractionAnimating) {
        if interaction === highlightMenu { highlightMenuIsShowing = true }
    }

    func editMenuInteraction(_ interaction: UIEditMenuInteraction, willDismissMenuFor configuration: UIEditMenuConfiguration, animator: any UIEditMenuInteractionAnimating) {
        if interaction === highlightMenu { highlightMenuIsShowing = false }
    }

    /// Tints the drop cap like the rest of the selection when the selection takes it in.
    func textViewDidChangeSelection(_ textView: UITextView) {
        guard let dropCapTarget, let textView = textView as? PageTextView else { return }
        dropCapTarget.backgroundColor = textView.selectionIncludesDropCap ? textView.tintColor.withAlphaComponent(0.25) : nil
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        dismissPalette(animated: false)
    }

    var hasSelection: Bool { textView?.hasSelection ?? false }

    /// The page stays put while text is selected or the highlight colors are showing.
    var blocksPageTurn: Bool { hasSelection || palette != nil || highlightMenuIsShowing }

    // MARK: Edit menu

    func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        let system = PageTextView.menuWithoutTranslate(suggestedActions)
        // Only prayers can be highlighted, not the verse on the book's opening page, and only
        // when some text is actually selected.
        guard book.pages[index].prayerPage != nil, range.length > 0 else { return UIMenu(children: system) }
        let highlight = UIAction(title: String(localized: "Highlight"), image: UIImage(systemName: "highlighter")) { [weak self] _ in
            // Read the selection when tapped: the menu can outlive the selection it was made for.
            guard let self, let selected = self.textView?.selectionWithDropCap else { return }
            self.addHighlight(selected)
        }
        let note = UIAction(title: String(localized: "Add Note"), image: UIImage(systemName: "note.text.badge.plus")) { [weak self] _ in
            guard let self, let selected = self.textView?.selectionWithDropCap else { return }
            self.addHighlight(selected, opensNote: true)
        }
        return UIMenu(children: [highlight, note] + system)
    }

    /// The menu for a tapped highlight: change its color, add or edit its note, copy it or
    /// remove it. With a note, Remove asks whether to remove just the note or both.
    private func menu(forHighlight id: UUID) -> UIMenu? {
        guard let highlight = Highlights.shared.highlight(withID: id) else { return nil }
        let colors = UIAction(title: String(localized: "Highlight"), image: UIImage(systemName: "highlighter")) { [weak self] _ in
            self?.showPalette(for: id)
        }
        let note = UIAction(
            title: highlight.hasNote ? String(localized: "Edit Note") : String(localized: "Add Note"),
            image: UIImage(systemName: highlight.hasNote ? "note.text" : "note.text.badge.plus")
        ) { [weak self] _ in
            self?.openNote(for: id)
        }
        let copy = UIAction(title: String(localized: "Copy"), image: UIImage(systemName: "doc.on.doc")) { _ in
            UIPasteboard.general.string = highlight.text
        }
        let removeBoth = UIAction(
            title: highlight.hasNote ? String(localized: "Remove Highlight & Note") : String(localized: "Remove"),
            image: UIImage(systemName: "trash"),
            attributes: .destructive
        ) { _ in
            Highlights.shared.remove(id)
        }
        let remove: UIMenuElement
        if highlight.hasNote {
            let removeNote = UIAction(title: String(localized: "Remove Note"), image: UIImage(systemName: "note.text"), attributes: .destructive) { _ in
                Highlights.shared.setNote(nil, for: id)
            }
            remove = UIMenu(title: String(localized: "Remove…"), image: UIImage(systemName: "trash"), options: .destructive, children: [removeNote, removeBoth])
        } else {
            remove = removeBoth
        }
        return UIMenu(children: [colors, note, copy, remove])
    }

    private func showHighlightMenu(for id: UUID, at point: CGPoint) {
        dismissPalette(animated: false)
        menuHighlightID = id
        highlightMenu?.presentEditMenu(with: UIEditMenuConfiguration(identifier: nil, sourcePoint: point))
    }

    /// Opens the note screen for a highlight, to write or change its note.
    private func openNote(for id: UUID) {
        guard let highlight = Highlights.shared.highlight(withID: id) else { return }
        dismissPalette(animated: false)
        let editor = UIHostingController(rootView: NoteEditorView(subject: .highlight(highlight), font: book.typography.font) { text, _ in
            Highlights.shared.setNote(text, for: id)
        })
        present(editor, animated: true)
    }

    // MARK: Highlights

    private func addHighlight(_ range: NSRange, opensNote: Bool = false) {
        guard let prayerPage = book.pages[index].prayerPage, range.length > 0 else { return }
        let layout = prayerPage.layout
        let fullText = layout.fullText as NSString
        let highlight = Highlights.shared.add(prayerID: prayerPage.prayer.id, range: layout.fullTextRange(range)) {
            fullText.substring(with: $0)
        }
        textView?.clearSelection()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if opensNote {
            openNote(for: highlight.id)
        } else {
            showPalette(for: highlight.id)
        }
    }

    /// Shows the colors just below the highlight, or above it if there's no room below.
    private func showPalette(for highlightID: UUID) {
        dismissPalette(animated: false)
        guard let highlight = Highlights.shared.highlight(withID: highlightID),
              let frame = pageView?.frame(of: highlightID)
        else { return }

        let palette = HighlightPalette(style: highlight.style) { [weak self] style, closes in
            Highlights.shared.setStyle(style, for: highlightID)
            UISelectionFeedbackGenerator().selectionChanged()
            if closes { self?.dismissPalette(animated: true) }
        } onRemove: { [weak self] in
            Highlights.shared.remove(highlightID)
            self?.dismissPalette(animated: true)
        }
        let size = palette.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        let bounds = view.bounds
        let gap: CGFloat = 12
        let below = frame.maxY + gap
        let y = below + size.height <= bounds.height - book.metrics.safeArea.bottom - 8
            ? below
            : max(frame.minY - gap - size.height, book.metrics.safeArea.top + 8)
        let x = min(max(bounds.midX - size.width / 2, 12), bounds.width - size.width - 12)
        palette.frame = CGRect(origin: CGPoint(x: x, y: y), size: size)
        view.addSubview(palette)
        self.palette = palette
        palette.appear()
    }

    private func dismissPalette(animated: Bool) {
        guard let palette else { return }
        self.palette = nil
        palette.disappear(animated: animated)
    }

    // MARK: Taps

    /// The prayer a link at this point opens, if there's a link there.
    func prayerLink(at point: CGPoint) -> Int? {
        pageView?.prayerLink(at: point)
    }

    /// Whether a tap here is for the page itself (a link, a highlight or a note's square)
    /// rather than for turning the page.
    func takesTap(at point: CGPoint) -> Bool {
        prayerLink(at: point) != nil || pageView?.prayerNoteMarker(at: point) != nil
            || pageView?.noteMarker(at: point) != nil || pageView?.highlight(at: point) != nil
    }

    @objc private func handleTap(_ tap: UITapGestureRecognizer) {
        guard !hasSelection else { return }
        let point = tap.location(in: view)
        if let prayerID = prayerLink(at: point) {
            onOpenPrayer?(prayerID)
        } else if pageView?.prayerNoteMarker(at: point) != nil {
            openPrayerNote()
        } else if let noted = pageView?.noteMarker(at: point) {
            openNote(for: noted.id)
        } else if let highlight = pageView?.highlight(at: point) {
            showHighlightMenu(for: highlight.id, at: point)
        } else {
            onCenterTap?()
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Taps on the colors are for their buttons.
        if let palette, let touched = touch.view, touched.isDescendant(of: palette) { return false }
        tapStartedBusy = blocksPageTurn
        return true
    }

    /// Lets taps on the text show the controls even though the text view watches taps too,
    /// but not when the touch was a press and hold that selected text.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        !(other is UILongPressGestureRecognizer)
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let point = gestureRecognizer.location(in: view)
        if tapStartedBusy {
            // A small drag of a selection handle can look like a tap, so leave the selection
            // to the text view, which clears it on a real tap, unless the tap was well away
            // from the text.
            if let textView, !textView.frame.insetBy(dx: -24, dy: -24).contains(point) {
                textView.clearSelection()
            }
            dismissPalette(animated: true)
            return false
        }
        if takesTap(at: point) { return true }
        let width = view.bounds.width
        return point.x > width * 0.25 && point.x < width * 0.75
    }
}

/// The back of a page, seen while it curls over. Like a real sheet of paper (and Apple Books),
/// it's the page color with the front's text faintly showing through, mirrored.
final class BackPageViewController: UIViewController {
    let index: Int
    let displayIndex: Int
    private let book: Book

    init(book: Book, index: Int, displayIndex: Int) {
        self.book = book
        self.index = index
        self.displayIndex = displayIndex
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
/// A right-to-left book (Persian) uses the same curl with the pages in reverse order, so it
/// opens at the back from a Western point of view and each page turns to the right.
struct PageCurlView: UIViewControllerRepresentable {
    let book: Book
    @Binding var currentPage: Int
    var isReversed: Bool
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
        // A tap on a link opens it instead of turning the page, and the page stays put
        // while text is selected.
        for gesture in controller.gestureRecognizers {
            gesture.delegate = context.coordinator
        }
        context.coordinator.pageController = controller
        context.coordinator.bookID = book.id
        context.coordinator.isReversed = isReversed
        context.coordinator.show(currentPage, in: controller, from: nil, animated: false)
        return controller
    }

    func updateUIViewController(_ controller: UIPageViewController, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        for case let page as PageViewController in controller.viewControllers ?? [] {
            page.showsTotal = showsTotal
        }

        if coordinator.bookID != book.id || coordinator.isReversed != isReversed {
            // The book was paginated again (new font, size or languages), or changed direction.
            coordinator.bookID = book.id
            coordinator.isReversed = isReversed
            coordinator.show(currentPage, in: controller, from: nil, animated: false)
        } else if let shown = coordinator.shownIndex(in: controller), shown != currentPage {
            // Jump to a page chosen from Contents, Bookmarks or Search.
            coordinator.show(currentPage, in: controller, from: shown, animated: true)
        }
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate, UIGestureRecognizerDelegate {
        var parent: PageCurlView
        var bookID: UUID?
        var isReversed = false
        weak var pageController: UIPageViewController?

        init(parent: PageCurlView) {
            self.parent = parent
        }

        private var pageCount: Int { parent.book.pages.count }

        private func clamped(_ index: Int) -> Int {
            min(max(index, 0), pageCount - 1)
        }

        /// Turns a position in the page curl into a page of the book, or back again.
        private func bookIndex(_ displayIndex: Int) -> Int {
            isReversed ? pageCount - 1 - displayIndex : displayIndex
        }

        /// Everything below works in page curl positions; only the pages and `currentPage`
        /// deal in book pages.
        func makePage(_ displayIndex: Int) -> PageViewController {
            let display = clamped(displayIndex)
            let page = PageViewController(book: parent.book, index: bookIndex(display), displayIndex: display, showsTotal: parent.showsTotal)
            page.onCenterTap = { [weak self] in self?.parent.onCenterTap() }
            page.onOpenPrayer = { [weak self] in self?.parent.onOpenPrayer($0) }
            return page
        }

        func makeBack(_ displayIndex: Int) -> BackPageViewController {
            let display = clamped(displayIndex)
            return BackPageViewController(book: parent.book, index: bookIndex(display), displayIndex: display)
        }

        /// While text is selected or the highlight colors are showing, touches go to them
        /// (dragging the selection's handles, or a tap to clear it) instead of turning the page.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let page = pageController?.viewControllers?.first as? PageViewController else { return true }
            return !page.blocksPageTurn
        }

        /// Stops the page curl's own taps from turning the page when the tap is on a link or
        /// a highlight.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard gestureRecognizer is UITapGestureRecognizer,
                  let page = pageController?.viewControllers?.first as? PageViewController
            else { return true }
            return !page.takesTap(at: gestureRecognizer.location(in: page.view))
        }

        /// The book page on screen.
        func shownIndex(in controller: UIPageViewController) -> Int? {
            (controller.viewControllers?.first as? PageViewController)?.index
        }

        /// Shows a book page, turning toward it from the book page `previous` when animated.
        func show(_ bookPage: Int, in controller: UIPageViewController, from previousPage: Int?, animated: Bool) {
            let index = bookIndex(bookPage)
            let previous = previousPage.map(bookIndex)
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
                return makePage(back.displayIndex)
            }
            guard let page = viewController as? PageViewController, page.displayIndex > 0 else { return nil }
            return pageViewController.isDoubleSided ? makeBack(page.displayIndex - 1) : makePage(page.displayIndex - 1)
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            if let back = viewController as? BackPageViewController {
                return back.displayIndex + 1 < pageCount ? makePage(back.displayIndex + 1) : nil
            }
            guard let page = viewController as? PageViewController else { return nil }
            if pageViewController.isDoubleSided {
                return page.displayIndex + 1 < pageCount ? makeBack(page.displayIndex) : nil
            }
            return page.displayIndex + 1 < pageCount ? makePage(page.displayIndex + 1) : nil
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
