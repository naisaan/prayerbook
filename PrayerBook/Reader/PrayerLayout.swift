import UIKit

/// Splits one prayer into pages using TextKit: each page is a text container the size of the
/// page's text area. Also places the drop cap.
final class PrayerLayout {
    struct DropCap {
        let containerIndex: Int
        /// Where to draw the letter, relative to the page's text area.
        let origin: CGPoint
        let letter: NSAttributedString
        /// Where the letter belongs in the text. It's left out of `storage` and drawn on its own.
        let characterLocation: Int
    }

    let storage: NSTextStorage
    let layoutManager = NSLayoutManager()
    private(set) var containers: [NSTextContainer] = []
    private(set) var dropCap: DropCap?
    private let pageSize: CGSize
    /// Space kept free at the top of the first page, for a title drawn above the text.
    private let firstPageTop: CGFloat

    init(prayer: Prayer, isRightToLeft: Bool, typography: Typography, pageSize: CGSize, firstPageTop: CGFloat = 0) {
        let built = PrayerTextBuilder(
            typography: typography,
            isRightToLeft: isRightToLeft,
            showsTitle: PrayerTextBuilder.showsTitle(for: prayer)
        ).build(prayer)
        self.pageSize = pageSize
        self.firstPageTop = firstPageTop
        storage = NSTextStorage(attributedString: built.text)
        storage.addLayoutManager(layoutManager)
        fillPages()

        if let letter = built.dropCapLetter {
            placeDropCap(letter, at: built.dropCapLocation, typography: typography)
        }
    }

    var pageCount: Int { containers.count }

    func characterRange(forPage index: Int) -> NSRange {
        let glyphs = layoutManager.glyphRange(for: containers[index])
        return layoutManager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
    }

    /// The prayer's whole text, with the drop cap's letter where `storage` leaves it out.
    var fullText: String {
        guard let dropCap else { return storage.string }
        let text = NSMutableString(string: storage.string)
        text.insert(dropCap.letter.string, at: dropCap.characterLocation)
        return text as String
    }

    /// Turns a range of `storage` into the same passage of `fullText`. A passage starting
    /// right after the drop cap takes in its letter too.
    func fullTextRange(_ range: NSRange) -> NSRange {
        guard let dropCap else { return range }
        let location = dropCap.characterLocation
        let shift = dropCap.letter.length
        let start = range.location <= location ? range.location : range.location + shift
        let end = NSMaxRange(range) <= location ? NSMaxRange(range) : NSMaxRange(range) + shift
        return NSRange(location: start, length: end - start)
    }

    /// Turns a passage of `fullText` back into a range of `storage`.
    func storageRange(_ range: NSRange) -> NSRange {
        guard let dropCap else { return range }
        let location = dropCap.characterLocation
        let shift = dropCap.letter.length
        func convert(_ index: Int) -> Int { index <= location ? index : max(index - shift, location) }
        let start = convert(range.location)
        let end = min(convert(NSMaxRange(range)), storage.length)
        return NSRange(location: min(start, end), length: max(end - start, 0))
    }

    /// Adds pages until all of the text has a place, then removes any empty pages at the end.
    private func fillPages() {
        var index = 0
        while true {
            if index == containers.count {
                let container = NSTextContainer(size: pageSize)
                container.lineFragmentPadding = 0
                if containers.isEmpty && firstPageTop > 0 {
                    container.exclusionPaths = [UIBezierPath(rect: CGRect(x: 0, y: 0, width: pageSize.width, height: firstPageTop))]
                }
                layoutManager.addTextContainer(container)
                containers.append(container)
            }
            let glyphs = layoutManager.glyphRange(for: containers[index])
            let isFinished = NSMaxRange(glyphs) >= layoutManager.numberOfGlyphs
            // Stop if nothing fits on a page at all (only possible with a tiny page).
            if isFinished || glyphs.length == 0 || index >= 500 { break }
            index += 1
        }
        while containers.count > index + 1 {
            layoutManager.removeTextContainer(at: containers.count - 1)
            containers.removeLast()
        }
    }

    /// Draws the first letter three lines tall and wraps the text around it.
    private func placeDropCap(_ letter: String, at location: Int, typography: Typography) {
        guard location < storage.length else {
            restoreLetter(letter, at: location, typography: typography)
            return
        }

        let glyphIndex = layoutManager.glyphIndexForCharacter(at: location)
        let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
        guard let container = layoutManager.textContainer(forGlyphAt: glyphIndex, effectiveRange: nil),
              let containerIndex = containers.firstIndex(where: { $0 === container })
        else {
            restoreLetter(letter, at: location, typography: typography)
            return
        }

        let lines: CGFloat = 3
        let lineHeight = typography.lineHeight
        // If the three lines don't fit at the bottom of the page, use a normal letter instead.
        guard lineRect.minY + lines * lineHeight <= pageSize.height else {
            restoreLetter(letter, at: location, typography: typography)
            return
        }

        // Size the letter so it reaches from the top of the first line's capitals down to
        // the baseline of the third line.
        let bodyFont = typography.bodyFont
        let span = (lines - 1) * lineHeight + bodyFont.capHeight
        let reference = typography.font.uiFont(size: 100)
        let capFont = typography.font.uiFont(size: span / reference.capHeight * 100)
        let letterString = NSAttributedString(string: letter, attributes: [
            .font: capFont,
            .foregroundColor: Typography.textColor,
        ])

        let firstBaseline = lineRect.minY + layoutManager.location(forGlyphAt: glyphIndex).y
        let lastBaseline = firstBaseline + (lines - 1) * lineHeight
        let letterWidth = ceil(letterString.size().width)
        let gap = (bodyFont.pointSize * 0.3).rounded()

        container.exclusionPaths.append(UIBezierPath(rect: CGRect(
            x: 0,
            y: lineRect.minY,
            width: letterWidth + gap,
            height: lines * lineHeight - 1
        )))
        dropCap = DropCap(
            containerIndex: containerIndex,
            origin: CGPoint(x: 0, y: lastBaseline - capFont.ascender),
            letter: letterString,
            characterLocation: location
        )
        fillPages()
    }

    private func restoreLetter(_ letter: String, at location: Int, typography: Typography) {
        let attributes: [NSAttributedString.Key: Any] = location < storage.length
            ? storage.attributes(at: location, effectiveRange: nil)
            : [.font: typography.bodyFont, .foregroundColor: Typography.textColor]
        storage.insert(NSAttributedString(string: letter, attributes: attributes), at: min(location, storage.length))
        fillPages()
    }
}
