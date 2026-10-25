import Foundation

/// Reads the small amount of HTML used in the prayer database: paragraphs with a class,
/// the decorative first letter (`versal`), italics, superscripts and line breaks.
enum PrayerMarkup {
    enum Style {
        case body, opening, noIndent, instruction, instructionCaps
    }

    struct Run {
        var text: String
        var isItalic = false
        var isSuperscript = false
        var isVersal = false
    }

    struct Paragraph {
        var style: Style
        var runs: [Run]
    }

    static let lineBreak = "\u{2028}"

    static func paragraphs(from html: String) -> [Paragraph] {
        let range = NSRange(html.startIndex..., in: html)
        let paragraphs: [Paragraph] = paragraphPattern.matches(in: html, range: range).compactMap { match in
            guard let innerRange = Range(match.range(at: 2), in: html) else { return nil }
            let attributes = Range(match.range(at: 1), in: html).map { String(html[$0]) } ?? ""
            let runs = normalized(runs(in: String(html[innerRange])))
            guard !runs.isEmpty else { return nil }
            return Paragraph(style: style(for: attributes), runs: runs)
        }
        guard paragraphs.isEmpty else { return paragraphs }

        // A couple of prayers have no <p> tags at all: treat blank lines as paragraph breaks.
        return html.components(separatedBy: "\n\n").compactMap { block in
            let runs = normalized(runs(in: block))
            return runs.isEmpty ? nil : Paragraph(style: .body, runs: runs)
        }
    }

    // A paragraph runs until its closing tag, the next paragraph, or the end of the text
    // (a few prayers forget to close their paragraphs).
    private static let paragraphPattern = try! NSRegularExpression(
        pattern: #"<p\b([^>]*)>(.*?)(?=</p>|<p\b|\z)"#,
        options: [.caseInsensitive, .dotMatchesLineSeparators]
    )

    private static let tokenPattern = try! NSRegularExpression(pattern: #"<[^>]*>|[^<]+"#)

    private static func style(for attributes: String) -> Style {
        let attributes = attributes.lowercased()
        if attributes.contains("commentcaps") { return .instructionCaps }
        if attributes.contains("comment") { return .instruction }
        if attributes.contains("opening") { return .opening }
        if attributes.contains("noindent") { return .noIndent }
        return .body
    }

    private static func runs(in html: String) -> [Run] {
        var runs: [Run] = []
        var italicDepth = 0
        var isSuperscript = false
        var openSpans: [Bool] = [] // true for a versal span

        for match in tokenPattern.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            guard let range = Range(match.range, in: html) else { continue }
            let token = String(html[range])

            guard token.hasPrefix("<") else {
                runs.append(Run(
                    text: decodeEntities(token),
                    isItalic: italicDepth > 0,
                    isSuperscript: isSuperscript,
                    isVersal: openSpans.contains(true)
                ))
                continue
            }

            let tag = token.lowercased()
            let isClosing = tag.hasPrefix("</")
            let name = String(tag.drop(while: { $0 == "<" || $0 == "/" }).prefix(while: { $0.isLetter }))
            switch name {
            case "em", "i":
                italicDepth = max(0, italicDepth + (isClosing ? -1 : 1))
            case "sup":
                isSuperscript = !isClosing
            case "span":
                if isClosing {
                    _ = openSpans.popLast()
                } else {
                    openSpans.append(tag.contains("versal"))
                }
            case "br":
                runs.append(Run(text: lineBreak))
            default:
                break
            }
        }
        return runs
    }

    /// Collapses runs of spaces and newlines into single spaces and trims the paragraph.
    private static func normalized(_ runs: [Run]) -> [Run] {
        var output: [Run] = []
        var previousWasSpace = true

        func trimTrailingSpace() {
            guard var last = output.last, last.text.hasSuffix(" ") else { return }
            output.removeLast()
            last.text.removeLast()
            if !last.text.isEmpty { output.append(last) }
        }

        for var run in runs {
            if run.text == lineBreak {
                trimTrailingSpace()
                if !output.isEmpty { output.append(run) }
                previousWasSpace = true
                continue
            }
            var text = ""
            for character in run.text {
                if character.isWhitespace {
                    if !previousWasSpace { text.append(" ") }
                    previousWasSpace = true
                } else {
                    text.append(character)
                    previousWasSpace = false
                }
            }
            if !text.isEmpty {
                run.text = text
                output.append(run)
            }
        }

        while let last = output.last, last.text == lineBreak || last.text.hasSuffix(" ") {
            if last.text == lineBreak {
                output.removeLast()
            } else {
                trimTrailingSpace()
            }
        }
        return output
    }

    private static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        return text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}
