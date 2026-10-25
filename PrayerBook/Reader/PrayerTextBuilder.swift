import UIKit

/// Turns a prayer into styled text: title, ornament, instructions, the prayer itself and its author.
struct PrayerTextBuilder {
    let typography: Typography
    let isRightToLeft: Bool
    let showsTitle: Bool

    /// Most prayers start straight away. Only these sections, and the Prayer for the Dead,
    /// show each prayer's title above it.
    static let titledSections: Set<String> = ["Huqúqu'lláh", "Occasional Prayers", "Special Tablets", "Obligatory"]

    static func showsTitle(for prayer: Prayer) -> Bool {
        titledSections.contains(prayer.category)
            || prayer.title.localizedCaseInsensitiveCompare("Prayer for the Dead") == .orderedSame
    }

    struct Result {
        let text: NSAttributedString
        /// The decorative first letter, taken out of the text so it can be drawn as a drop cap.
        let dropCapLetter: String?
        /// Where the drop cap letter was in the text.
        let dropCapLocation: Int
    }

    func build(_ prayer: Prayer) -> Result {
        let text = NSMutableAttributedString()
        let size = typography.size

        if showsTitle {
            // Title, centered and italic, like a chapter title in Apple Books.
            let titleStyle = NSMutableParagraphStyle()
            titleStyle.alignment = .center
            titleStyle.lineHeightMultiple = 1.05
            titleStyle.paragraphSpacing = size * 0.5
            titleStyle.baseWritingDirection = writingDirection
            text.append(NSAttributedString(string: prayer.title + "\n", attributes: [
                .font: typography.font.uiFont(size: size * 1.25, weight: .semibold, italic: !isRightToLeft),
                .foregroundColor: Typography.textColor,
                .paragraphStyle: titleStyle,
                .kern: -0.2,
            ]))

            // A short, thin, solid line under the title. The dashes themselves are invisible:
            // only their strikethrough shows, which draws one unbroken line.
            let lineStyle = NSMutableParagraphStyle()
            lineStyle.alignment = .center
            lineStyle.paragraphSpacing = size * 0.9
            text.append(NSAttributedString(string: "\u{2014}\u{2014}\u{2014}\u{2014}\n", attributes: [
                .font: typography.font.uiFont(size: size * 0.9),
                .foregroundColor: UIColor.clear,
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .strikethroughColor: Typography.secondaryColor,
                .paragraphStyle: lineStyle,
            ]))
        }

        var dropCapLetter: String?
        var dropCapLocation = 0
        var usedVersal = false

        for paragraph in PrayerMarkup.paragraphs(from: prayer.html) {
            let paragraphStart = text.length
            let style = paragraphStyle(for: paragraph.style)
            for run in paragraph.runs {
                if run.isVersal && !usedVersal {
                    usedVersal = true
                    if typography.dropCap && !isRightToLeft && text.length == paragraphStart
                        && paragraph.style != .instruction && paragraph.style != .instructionCaps {
                        dropCapLetter = run.text
                        dropCapLocation = text.length
                        continue
                    }
                }
                let string = paragraph.style == .instructionCaps ? run.text.uppercased() : run.text
                text.append(NSAttributedString(string: string, attributes: attributes(for: run, in: paragraph.style, paragraphStyle: style)))
            }
            text.append(NSAttributedString(string: "\n", attributes: [.paragraphStyle: style, .font: typography.bodyFont]))
        }

        // The author, set to the trailing side like a signature.
        if !prayer.author.isEmpty {
            let authorStyle = NSMutableParagraphStyle()
            authorStyle.alignment = isRightToLeft ? .left : .right
            authorStyle.paragraphSpacingBefore = size * 0.4
            authorStyle.paragraphSpacing = size * 0.6
            authorStyle.baseWritingDirection = writingDirection
            text.append(NSAttributedString(string: "— \(prayer.author)\n", attributes: [
                .font: typography.font.uiFont(size: size * 0.95, italic: !isRightToLeft),
                .foregroundColor: Typography.textColor,
                .paragraphStyle: authorStyle,
            ]))
        }

        if !prayer.citation.isEmpty {
            let citationStyle = NSMutableParagraphStyle()
            citationStyle.baseWritingDirection = writingDirection
            citationStyle.paragraphSpacingBefore = size * 0.4
            text.append(NSAttributedString(string: prayer.citation, attributes: [
                .font: typography.font.uiFont(size: size * 0.7),
                .foregroundColor: Typography.secondaryColor,
                .paragraphStyle: citationStyle,
            ]))
        }

        // Drop the final line break so the prayer doesn't end with an empty line.
        if text.string.hasSuffix("\n") {
            text.deleteCharacters(in: NSRange(location: text.length - 1, length: 1))
        }

        return Result(text: text, dropCapLetter: dropCapLetter, dropCapLocation: dropCapLocation)
    }

    private var writingDirection: NSWritingDirection {
        isRightToLeft ? .rightToLeft : .natural
    }

    private func paragraphStyle(for style: PrayerMarkup.Style) -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        let lineHeight = typography.lineHeight
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
        paragraph.paragraphSpacing = typography.size * 0.7
        paragraph.alignment = .justified
        paragraph.hyphenationFactor = isRightToLeft ? 0 : 0.6
        paragraph.baseWritingDirection = writingDirection

        switch style {
        case .instructionCaps:
            paragraph.alignment = .center
            paragraph.minimumLineHeight = (lineHeight * 0.85).rounded()
            paragraph.maximumLineHeight = (lineHeight * 0.85).rounded()
        case .instruction:
            paragraph.alignment = .natural
            paragraph.minimumLineHeight = (lineHeight * 0.9).rounded()
            paragraph.maximumLineHeight = (lineHeight * 0.9).rounded()
        case .body, .opening, .noIndent:
            break
        }
        return paragraph
    }

    private func attributes(for run: PrayerMarkup.Run, in style: PrayerMarkup.Style, paragraphStyle: NSParagraphStyle) -> [NSAttributedString.Key: Any] {
        let size = typography.size
        var fontSize = size
        var italic = run.isItalic
        var attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: Typography.textColor,
            .paragraphStyle: paragraphStyle,
        ]

        switch style {
        case .instructionCaps:
            fontSize = size * 0.8
            italic = true
            attributes[.kern] = 0.6
        case .instruction:
            fontSize = size * 0.88
            italic = true
        case .body, .opening, .noIndent:
            break
        }

        if run.isSuperscript {
            fontSize *= 0.65
            attributes[.baselineOffset] = size * 0.35
        }

        attributes[.font] = typography.font.uiFont(size: fontSize, italic: italic && !isRightToLeft)
        return attributes
    }
}
