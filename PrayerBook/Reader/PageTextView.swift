import UIKit

/// Lets the reader press and hold to select a page's text, with Apple's own selection handles,
/// magnifier and edit menu. It's a see-through text view laid over the page: it lays out a copy
/// of the prayer in the same page-sized boxes, so every word sits exactly where the page drew
/// it, but it draws none of the text itself. What you see is still the page's own drawing.
final class PageTextView: UITextView {
    // The text view only holds on to its text container, so keep the rest of the copy alive.
    private let copiedStorage: NSTextStorage
    private let copiedLayoutManager: NSLayoutManager
    private let dropCap: PrayerLayout.DropCap?

    init(prayerPage: PrayerPage, origin: CGPoint) {
        let layout = prayerPage.layout
        copiedStorage = NSTextStorage(attributedString: layout.storage)
        copiedLayoutManager = InvisibleLayoutManager()
        copiedStorage.addLayoutManager(copiedLayoutManager)
        dropCap = layout.dropCap

        // The pages before this one too, so this page starts at the same word.
        var page = NSTextContainer()
        for original in layout.containers.prefix(prayerPage.pageInPrayer + 1) {
            let container = NSTextContainer(size: original.size)
            container.lineFragmentPadding = original.lineFragmentPadding
            container.exclusionPaths = original.exclusionPaths
            container.widthTracksTextView = false
            container.heightTracksTextView = false
            copiedLayoutManager.addTextContainer(container)
            page = container
        }

        super.init(frame: CGRect(origin: origin, size: page.size), textContainer: page)
        isEditable = false
        isSelectable = true
        isScrollEnabled = false
        clipsToBounds = false
        backgroundColor = .clear
        textContainerInset = .zero
        writingToolsBehavior = .none
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    var hasSelection: Bool { selectedRange.length > 0 }

    func clearSelection() {
        selectedRange = NSRange(location: selectedRange.location, length: 0)
    }

    /// Copies plain text, with the drop cap's letter put back where it belongs.
    override func copy(_ sender: Any?) {
        let text = NSMutableString(string: (textStorage.string as NSString).substring(with: selectedRange))
        if let dropCap, selectedRange.location <= dropCap.characterLocation,
           dropCap.characterLocation < NSMaxRange(selectedRange) {
            text.insert(dropCap.letter.string, at: dropCap.characterLocation - selectedRange.location)
        }
        UIPasteboard.general.string = text as String
    }

    /// Apple's suggested edit menu without Translate, and without Select All, which would
    /// select the parts of the prayer on other pages.
    static func menuWithoutTranslate(_ elements: [UIMenuElement]) -> [UIMenuElement] {
        elements.compactMap { element in
            if let menu = element as? UIMenu {
                if menu.identifier.rawValue.localizedCaseInsensitiveContains("translate") { return nil }
                let children = menuWithoutTranslate(menu.children)
                return children.isEmpty ? nil : menu.replacingChildren(children)
            }
            if let command = element as? UICommand {
                let action = NSStringFromSelector(command.action)
                if action.localizedCaseInsensitiveContains("translate") || action == "selectAll:" { return nil }
            }
            if let action = element as? UIAction,
               action.identifier.rawValue.localizedCaseInsensitiveContains("translate") {
                return nil
            }
            return element
        }
    }
}

/// Lays text out but never draws it.
private final class InvisibleLayoutManager: NSLayoutManager {
    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {}
    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {}
}
