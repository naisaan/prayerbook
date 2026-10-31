import SwiftUI
import UIKit

/// The kinds of list a line of the prayer list can be part of.
enum PrayerListStyle: CaseIterable {
    case checklist, bullets, dashes

    var systemImage: String {
        switch self {
        case .checklist: "checklist"
        case .bullets: "list.bullet"
        case .dashes: "list.dash"
        }
    }

    var name: LocalizedStringKey {
        switch self {
        case .checklist: "Checklist"
        case .bullets: "Bulleted List"
        case .dashes: "Dashed List"
        }
    }

    /// The text a bulleted or dashed line starts with. A checklist line starts with a
    /// checkbox instead.
    var textPrefix: String? {
        switch self {
        case .checklist: nil
        case .bullets: "• "
        case .dashes: "– "
        }
    }
}

/// The prayer list's text: Apple's text view, where a line can be a checklist item (with
/// a circle to tick, like Notes), a bullet or a dash. A bar floating above the keyboard turns
/// the selected lines into a list, and pressing return carries the list on to the next line.
///
/// It's saved as plain text: a checklist line is written "[ ] " or "[x] " at its start.
struct PrayerListTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var isTyping: Bool
    let font: UIFont

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        let coordinator = context.coordinator
        coordinator.textView = textView
        textView.delegate = coordinator
        textView.backgroundColor = .clear
        textView.textColor = .black
        textView.tintColor = .black
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.keyboardDismissMode = .interactive
        textView.alwaysBounceVertical = false
        textView.inputAccessoryView = coordinator.makeListBar()
        coordinator.font = font
        textView.attributedText = coordinator.attributedText(from: text)
        textView.typingAttributes = coordinator.baseAttributes

        let tap = UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.tapCheckbox(_:)))
        tap.delegate = coordinator
        textView.addGestureRecognizer(tap)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        if coordinator.font != font {
            coordinator.font = font
            textView.attributedText = coordinator.attributedText(from: text)
            textView.typingAttributes = coordinator.baseAttributes
        } else if coordinator.savedText != text {
            textView.attributedText = coordinator.attributedText(from: text)
        }
        if !isTyping && textView.isFirstResponder {
            textView.resignFirstResponder()
        }
    }

    // MARK: -

    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: PrayerListTextView
        weak var textView: UITextView?
        var font: UIFont = .systemFont(ofSize: 18)
        /// The text as last saved, so an update from SwiftUI doesn't reload what was just typed.
        var savedText: String = ""
        let bar = ListBarState()

        init(_ parent: PrayerListTextView) {
            self.parent = parent
        }

        var baseAttributes: [NSAttributedString.Key: Any] {
            [.font: font, .foregroundColor: UIColor.black]
        }

        // MARK: Reading and writing the saved text

        func attributedText(from text: String) -> NSAttributedString {
            savedText = text
            let result = NSMutableAttributedString()
            let lines = text.components(separatedBy: "\n")
            for (index, line) in lines.enumerated() {
                if line.hasPrefix("[ ] ") || line.hasPrefix("[x] ") {
                    result.append(checkbox(checked: line.hasPrefix("[x]")))
                    result.append(NSAttributedString(string: " " + line.dropFirst(4), attributes: baseAttributes))
                } else {
                    result.append(NSAttributedString(string: line, attributes: baseAttributes))
                }
                if index < lines.count - 1 {
                    result.append(NSAttributedString(string: "\n", attributes: baseAttributes))
                }
            }
            return result
        }

        func plainText(from attributed: NSAttributedString) -> String {
            var text = ""
            attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length)) { attributes, range, _ in
                if let box = attributes[.attachment] as? CheckboxAttachment {
                    text += box.isChecked ? "[x]" : "[ ]"
                } else {
                    text += (attributed.string as NSString).substring(with: range)
                }
            }
            return text
        }

        private func save() {
            guard let textView else { return }
            let text = plainText(from: textView.attributedText)
            savedText = text
            parent.text = text
        }

        // MARK: Checkboxes

        func checkbox(checked: Bool) -> NSAttributedString {
            let attachment = CheckboxAttachment(isChecked: checked, font: font)
            let string = NSMutableAttributedString(attachment: attachment)
            string.addAttributes(baseAttributes, range: NSRange(location: 0, length: string.length))
            return string
        }

        /// The checkbox under a tap, if there is one.
        private func checkbox(at point: CGPoint, in textView: UITextView) -> (CheckboxAttachment, Int)? {
            let layoutManager = textView.layoutManager
            let location = CGPoint(x: point.x - textView.textContainerInset.left, y: point.y - textView.textContainerInset.top)
            let glyph = layoutManager.glyphIndex(for: location, in: textView.textContainer)
            let index = layoutManager.characterIndexForGlyph(at: glyph)
            guard index < textView.textStorage.length,
                  let box = textView.textStorage.attribute(.attachment, at: index, effectiveRange: nil) as? CheckboxAttachment
            else { return nil }
            // A little more room than the circle itself, so it's easy to hit.
            let rect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: textView.textContainer)
            guard rect.insetBy(dx: -10, dy: -6).contains(location) else { return nil }
            return (box, index)
        }

        @objc func tapCheckbox(_ tap: UITapGestureRecognizer) {
            guard let textView, let hit = checkbox(at: tap.location(in: textView), in: textView) else { return }
            let (box, index) = hit
            let selection = textView.selectedRange
            textView.textStorage.replaceCharacters(in: NSRange(location: index, length: 1), with: checkbox(checked: !box.isChecked))
            textView.selectedRange = selection
            UISelectionFeedbackGenerator().selectionChanged()
            save()
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let textView else { return false }
            return checkbox(at: gestureRecognizer.location(in: textView), in: textView) != nil
        }

        /// Tapping a checkbox ticks it without moving the cursor or bringing up the keyboard.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
            other is UITapGestureRecognizer && other.view === textView
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            false
        }

        // MARK: Lines

        /// The style of the line in `range` (a paragraph range), and how long its prefix is.
        private func style(ofLineAt range: NSRange, in storage: NSTextStorage) -> (PrayerListStyle, Int)? {
            guard range.length > 0 else { return nil }
            if storage.attribute(.attachment, at: range.location, effectiveRange: nil) is CheckboxAttachment {
                let hasSpace = range.length > 1 && (storage.string as NSString).substring(with: NSRange(location: range.location + 1, length: 1)) == " "
                return (.checklist, hasSpace ? 2 : 1)
            }
            let line = (storage.string as NSString).substring(with: range)
            for style in [PrayerListStyle.bullets, .dashes] {
                if let prefix = style.textPrefix, line.hasPrefix(prefix) {
                    return (style, (prefix as NSString).length)
                }
            }
            return nil
        }

        private func prefix(for style: PrayerListStyle) -> NSAttributedString {
            if let text = style.textPrefix {
                return NSAttributedString(string: text, attributes: baseAttributes)
            }
            let box = NSMutableAttributedString(attributedString: checkbox(checked: false))
            box.append(NSAttributedString(string: " ", attributes: baseAttributes))
            return box
        }

        /// The paragraph ranges of every line the selection touches.
        private func selectedLines(in textView: UITextView) -> [NSRange] {
            let string = textView.textStorage.string as NSString
            let whole = string.paragraphRange(for: textView.selectedRange)
            var lines: [NSRange] = []
            var location = whole.location
            repeat {
                let line = string.paragraphRange(for: NSRange(location: location, length: 0))
                lines.append(line)
                location = NSMaxRange(line)
            } while location < NSMaxRange(whole)
            return lines
        }

        /// Turns the selected lines into the list, or back into plain lines if they already are one.
        func apply(_ style: PrayerListStyle) {
            guard let textView else { return }
            let storage = textView.textStorage
            let lines = selectedLines(in: textView)
            guard let first = lines.first, let last = lines.last else { return }
            let allAlready = lines.allSatisfy { self.style(ofLineAt: $0, in: storage)?.0 == style }
            let hadSelection = textView.selectedRange.length > 0
            var totalChange = 0
            storage.beginEditing()
            // From the last line up, so the earlier ranges stay right.
            for line in lines.reversed() {
                let oldLength = self.style(ofLineAt: line, in: storage)?.1 ?? 0
                let replacement = allAlready ? NSAttributedString() : prefix(for: style)
                storage.replaceCharacters(in: NSRange(location: line.location, length: oldLength), with: replacement)
                totalChange += replacement.length - oldLength
            }
            storage.endEditing()

            // The lines' text afterwards, without the last line's return.
            let string = storage.string as NSString
            var end = min(NSMaxRange(last) + totalChange, string.length)
            if end > first.location && string.substring(with: NSRange(location: end - 1, length: 1)) == "\n" {
                end -= 1
            }
            if hadSelection {
                // Keep the same lines selected, so another list can be picked right away.
                textView.selectedRange = NSRange(location: first.location, length: max(0, end - first.location))
            } else {
                // The cursor goes to the end of its line.
                textView.selectedRange = NSRange(location: end, length: 0)
            }
            textView.typingAttributes = baseAttributes
            save()
            updateBar()
        }

        // MARK: Typing

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            let storage = textView.textStorage
            let string = storage.string as NSString
            let line = string.paragraphRange(for: NSRange(location: range.location, length: 0))
            guard let lineStyle = style(ofLineAt: line, in: storage) else { return true }
            let (listStyle, prefixLength) = lineStyle

            if text == "\n" && range.length == 0 {
                let lineEnd = NSMaxRange(line) - (string.substring(with: line).hasSuffix("\n") ? 1 : 0)
                let content = string.substring(with: NSRange(location: line.location + prefixLength, length: lineEnd - line.location - prefixLength))
                if content.trimmingCharacters(in: .whitespaces).isEmpty {
                    // Return on an empty item ends the list.
                    storage.replaceCharacters(in: NSRange(location: line.location, length: prefixLength), with: "")
                    textView.selectedRange = NSRange(location: line.location, length: 0)
                } else {
                    // Otherwise the next line carries the list on.
                    let next = NSMutableAttributedString(string: "\n", attributes: baseAttributes)
                    next.append(prefix(for: listStyle))
                    storage.replaceCharacters(in: range, with: next)
                    textView.selectedRange = NSRange(location: range.location + next.length, length: 0)
                }
                textView.typingAttributes = baseAttributes
                save()
                return false
            }

            if text.isEmpty && range.length == 1 && range.location < line.location + prefixLength {
                // Deleting into the prefix removes all of it.
                storage.replaceCharacters(in: NSRange(location: line.location, length: prefixLength), with: "")
                textView.selectedRange = NSRange(location: line.location, length: 0)
                textView.typingAttributes = baseAttributes
                save()
                updateBar()
                return false
            }
            return true
        }

        func textViewDidChange(_ textView: UITextView) {
            save()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            textView.typingAttributes = baseAttributes
            updateBar()
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if !parent.isTyping { parent.isTyping = true }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if parent.isTyping { parent.isTyping = false }
        }

        // MARK: The list bar

        private func updateBar() {
            guard let textView else { return }
            let lines = selectedLines(in: textView)
            let styles = Set(lines.map { style(ofLineAt: $0, in: textView.textStorage)?.0 })
            bar.current = styles.count == 1 ? styles.first ?? nil : nil
        }

        func makeListBar() -> UIView {
            let host = UIHostingController(rootView: ListBar(state: bar) { [weak self] style in
                self?.apply(style)
            })
            host.view.backgroundColor = .clear
            host.sizingOptions = .intrinsicContentSize
            let container = UIInputView(frame: CGRect(x: 0, y: 0, width: 0, height: 64), inputViewStyle: .default)
            container.allowsSelfSizing = true
            container.backgroundColor = .clear
            container.addSubview(host.view)
            host.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                host.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                host.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                host.view.topAnchor.constraint(equalTo: container.topAnchor),
                host.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
            hostingController = host
            return container
        }

        private var hostingController: UIViewController?
    }
}

/// Which list the selected lines are, so its button shows as on.
@Observable
final class ListBarState {
    var current: PrayerListStyle?
}

/// The glass bar floating above the keyboard, with a button for each kind of list.
private struct ListBar: View {
    let state: ListBarState
    let onSelect: (PrayerListStyle) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(PrayerListStyle.allCases, id: \.self) { style in
                Button {
                    onSelect(style)
                } label: {
                    Image(systemName: style.systemImage)
                        .font(.system(size: 19, weight: .medium))
                        .frame(width: 52, height: 40)
                        .background {
                            if state.current == style {
                                Capsule().fill(.primary.opacity(0.15))
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(style.name)
                .accessibilityAddTraits(state.current == style ? .isSelected : [])
            }
        }
        .padding(6)
        .glassEffect(.regular.interactive(), in: .capsule)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .sensoryFeedback(.selection, trigger: state.current)
    }
}

/// A checklist item's circle, ticked or not, drawn from SF Symbols at the text's size.
final class CheckboxAttachment: NSTextAttachment {
    let isChecked: Bool

    init(isChecked: Bool, font: UIFont) {
        self.isChecked = isChecked
        super.init(data: nil, ofType: nil)
        let configuration = UIImage.SymbolConfiguration(font: font, scale: .large)
        let symbol = UIImage(systemName: isChecked ? "checkmark.circle.fill" : "circle", withConfiguration: configuration)
        image = symbol?.withTintColor(.black, renderingMode: .alwaysOriginal)
        if let size = image?.size {
            // Centered on the letters, not sitting on the baseline.
            bounds = CGRect(x: 0, y: (font.capHeight - size.height) / 2, width: size.width, height: size.height)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }
}
