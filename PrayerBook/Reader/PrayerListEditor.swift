import SwiftUI

/// The kinds of list a line of the prayer list can be part of.
enum PrayerListStyle: CaseIterable, Codable {
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
}

/// A piece of the prayer list: either plain text, any number of lines long, or one list item.
struct PrayerListBlock: Identifiable, Equatable {
    let id = UUID()
    var text: String
    /// Nil for plain text.
    var style: PrayerListStyle?
    var isChecked = false

    var isItem: Bool { style != nil }

    /// Every list item's field starts with this invisible character. When it's gone,
    /// backspace was pressed at the very start of the item, which SwiftUI's text fields
    /// can't report any other way.
    static let start = "\u{200B}"

    var shownText: String { text.replacingOccurrences(of: Self.start, with: "") }

    static func item(_ text: String, style: PrayerListStyle, isChecked: Bool = false) -> PrayerListBlock {
        PrayerListBlock(text: start + text, style: style, isChecked: isChecked)
    }

    // MARK: Saving as plain text: "[ ] ", "[x] ", "• " or "– " at the start of an item's line.

    private static let prefixes: [(String, PrayerListStyle, Bool)] = [
        ("[ ] ", .checklist, false), ("[x] ", .checklist, true), ("• ", .bullets, false), ("– ", .dashes, false),
    ]

    static func blocks(from text: String) -> [PrayerListBlock] {
        var blocks: [PrayerListBlock] = []
        var plain: [String] = []
        func flushPlain() {
            if !plain.isEmpty { blocks.append(PrayerListBlock(text: plain.joined(separator: "\n"))) }
            plain = []
        }
        for line in text.components(separatedBy: "\n") {
            if let match = prefixes.first(where: { line.hasPrefix($0.0) }) {
                flushPlain()
                blocks.append(.item(String(line.dropFirst(match.0.count)), style: match.1, isChecked: match.2))
            } else {
                plain.append(line)
            }
        }
        flushPlain()
        return blocks
    }

    static func text(from blocks: [PrayerListBlock]) -> String {
        blocks.map { (block: PrayerListBlock) -> String in
            let prefix: String = switch block.style {
            case .checklist: block.isChecked ? "[x] " : "[ ] "
            case .bullets: "• "
            case .dashes: "– "
            case nil: ""
            }
            return prefix + block.shownText
        }
        .joined(separator: "\n")
    }
}

/// The prayer list's text, all in SwiftUI. Plain text is one ordinary text box, with
/// Apple's selection and grabbers across lines. Selecting some lines and tapping a list
/// button in the bar above the keyboard turns just those lines into list items: their own
/// rows, with a circle to tick like Notes, a bullet or a dash. Return carries a list on.
struct PrayerListEditor: View {
    @Binding var text: String
    @Binding var isTyping: Bool
    let font: Font

    @State private var blocks: [PrayerListBlock] = []
    @State private var selections: [PrayerListBlock.ID: TextSelection] = [:]
    @FocusState private var focused: PrayerListBlock.ID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach($blocks) { $block in
                    if block.isItem {
                        itemRow($block)
                    } else {
                        textBox($block)
                    }
                }
                // Tapping below the last line types on it.
                Color.clear
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .contentShape(Rectangle())
                    .onTapGesture { focused = blocks.last?.id }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.basedOnSize)
        .font(font)
        .overlay(alignment: .topLeading) {
            if blocks.allSatisfy({ !$0.isItem && $0.text.isEmpty }) && focused == nil {
                Text("The people and things in your life you’d like to pray for…")
                    .foregroundStyle(.tertiary)
                    .font(font)
                    .allowsHitTesting(false)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                ForEach(PrayerListStyle.allCases, id: \.self) { style in
                    Button {
                        apply(style)
                    } label: {
                        Image(systemName: style.systemImage)
                    }
                    .accessibilityLabel(style.name)
                    .accessibilityAddTraits(focusedBlock?.style == style ? .isSelected : [])
                }
                Spacer()
            }
        }
        .onAppear {
            blocks = PrayerListBlock.blocks(from: text)
            if blocks.isEmpty { blocks = [PrayerListBlock(text: "")] }
        }
        .onChange(of: blocks) { _, blocks in
            text = PrayerListBlock.text(from: blocks)
        }
        .onChange(of: focused) { _, focused in
            if isTyping != (focused != nil) { isTyping = focused != nil }
        }
        .onChange(of: isTyping) { _, typing in
            if !typing { focused = nil }
        }
        .sensoryFeedback(.selection, trigger: blocks.map(\.isChecked))
    }

    private var focusedBlock: PrayerListBlock? {
        blocks.first { $0.id == focused }
    }

    // MARK: Rows

    /// Plain text: an ordinary text box, as tall as its lines.
    private func textBox(_ block: Binding<PrayerListBlock>) -> some View {
        let id = block.wrappedValue.id
        return TextEditor(text: block.text, selection: Binding(
            get: { selections[id] },
            set: { selections[id] = $0 }
        ))
        .focused($focused, equals: id)
        .scrollDisabled(true)
        .scrollContentBackground(.hidden)
        .frame(minHeight: 30)
        .fixedSize(horizontal: false, vertical: true)
        // TextEditor has its own margins; line it up with the list items.
        .padding(.horizontal, -5)
        .padding(.vertical, -8)
    }

    /// A list item: its circle, bullet or dash, then its text.
    private func itemRow(_ block: Binding<PrayerListBlock>) -> some View {
        let id = block.wrappedValue.id
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            switch block.wrappedValue.style {
            case .checklist:
                Button {
                    block.wrappedValue.isChecked.toggle()
                } label: {
                    Image(systemName: block.wrappedValue.isChecked ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(block.wrappedValue.isChecked ? "Checked" : "Not Checked")
            case .bullets:
                Text("•")
            case .dashes:
                Text("–")
            case nil:
                EmptyView()
            }
            TextField("", text: block.text, axis: .vertical)
                .focused($focused, equals: id)
                // In case return is taken as "done" rather than typed: start a new item anyway.
                .onSubmit { itemEdited(id, block.wrappedValue.text + "\n") }
                .onChange(of: block.wrappedValue.text) { _, newText in
                    itemEdited(id, newText)
                }
        }
    }

    // MARK: Making lists

    /// The list buttons. In plain text, the selected lines (or the cursor's line) become
    /// list items. On a list item, it switches to that list, or back to plain text if it's
    /// already that list.
    private func apply(_ style: PrayerListStyle) {
        guard let focused, let index = blocks.firstIndex(where: { $0.id == focused }) else { return }
        if blocks[index].isItem {
            if blocks[index].style == style {
                makePlain(at: index)
            } else {
                blocks[index].style = style
                blocks[index].isChecked = false
            }
        } else {
            makeList(fromTextAt: index, style: style)
        }
    }

    private func makeList(fromTextAt index: Int, style: PrayerListStyle) {
        let block = blocks[index]
        let text = block.text
        let range: Range<String.Index> = switch selections[block.id]?.indices {
        case .selection(let range)?: range
        case .multiSelection(let set)?: set.ranges.first ?? text.endIndex..<text.endIndex
        default: text.endIndex..<text.endIndex
        }
        let lower = min(range.lowerBound, text.endIndex)
        let upper = min(range.upperBound, text.endIndex)

        // Widen the selection to whole lines.
        let lineStart = text[..<lower].lastIndex(of: "\n").map { text.index(after: $0) } ?? text.startIndex
        let probe = upper > lower ? text.index(before: upper) : upper
        let lineEnd = probe < text.endIndex ? (text[probe...].firstIndex(of: "\n") ?? text.endIndex) : text.endIndex

        var before = String(text[..<lineStart])
        if before.hasSuffix("\n") { before.removeLast() }
        var after = String(text[lineEnd...])
        if after.hasPrefix("\n") { after.removeFirst() }
        let chosen = text[lineStart..<lineEnd].components(separatedBy: "\n")
        let items = chosen.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { PrayerListBlock.item($0, style: style) }
        let newItems = items.isEmpty ? [PrayerListBlock.item("", style: style)] : items

        var replacement: [PrayerListBlock] = []
        if lineStart > text.startIndex { replacement.append(PrayerListBlock(text: before)) }
        replacement += newItems
        if lineEnd < text.endIndex { replacement.append(PrayerListBlock(text: after)) }

        blocks.replaceSubrange(index...index, with: replacement)
        selections[block.id] = nil
        let target = newItems.last!.id
        Task { @MainActor in self.focused = target }
    }

    /// Turns a list item back into plain text, joining the plain text around it.
    private func makePlain(at index: Int) {
        var text = blocks[index].shownText
        var start = index
        var end = index
        if index > 0, !blocks[index - 1].isItem {
            text = blocks[index - 1].text + "\n" + text
            start -= 1
        }
        if index + 1 < blocks.count, !blocks[index + 1].isItem {
            text += "\n" + blocks[index + 1].text
            end += 1
        }
        let plain = PrayerListBlock(text: text)
        blocks.replaceSubrange(start...end, with: [plain])
        Task { @MainActor in self.focused = plain.id }
    }

    // MARK: Typing in list items

    /// Return and backspace, which arrive as changes to an item's text.
    private func itemEdited(_ id: PrayerListBlock.ID, _ newText: String) {
        guard let index = blocks.firstIndex(where: { $0.id == id }), let style = blocks[index].style else { return }
        let start = PrayerListBlock.start

        if let newline = newText.firstIndex(of: "\n") {
            let before = String(newText[..<newline])
            let after = String(newText[newText.index(after: newline)...]).replacingOccurrences(of: start, with: "")
            if before.replacingOccurrences(of: start, with: "").isEmpty && after.isEmpty {
                // Return on an empty item ends the list.
                blocks[index].text = start
                makePlain(at: index)
                return
            }
            // Otherwise what's after the cursor becomes the next item. The new item's field
            // only exists after this update, so move to it just after; until then the
            // keyboard stays with this one.
            blocks[index].text = before
            let next = PrayerListBlock.item(after, style: style)
            blocks.insert(next, at: index + 1)
            Task { @MainActor in self.focused = next.id }
            return
        }

        if !newText.contains(start) {
            // Backspace at the start of the item turns it back into plain text.
            blocks[index].text = start + newText
            makePlain(at: index)
            return
        }

        if !newText.hasPrefix(start) {
            // Typed before the invisible character: keep it at the front.
            blocks[index].text = start + newText.replacingOccurrences(of: start, with: "")
        }
    }
}
