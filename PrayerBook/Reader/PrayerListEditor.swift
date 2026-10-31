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

/// One line of the prayer list.
struct PrayerListLine: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var style: PrayerListStyle?
    var isChecked = false

    /// Every field starts with this invisible character. When it's gone, backspace was
    /// pressed at the very start of the line, which SwiftUI's text fields can't report any
    /// other way.
    static let start = "\u{200B}"

    var shownText: String { text.replacingOccurrences(of: Self.start, with: "") }

    // MARK: Saving as plain text: "[ ] ", "[x] ", "• " or "– " at the start of a line.

    static func lines(from text: String) -> [PrayerListLine] {
        text.components(separatedBy: "\n").map { (line: String) -> PrayerListLine in
            for (prefix, style, checked) in [("[ ] ", PrayerListStyle.checklist, false), ("[x] ", .checklist, true),
                                             ("• ", .bullets, false), ("– ", .dashes, false)]
            where line.hasPrefix(prefix) {
                return PrayerListLine(text: start + String(line.dropFirst(prefix.count)), style: style, isChecked: checked)
            }
            return PrayerListLine(text: start + line, style: nil)
        }
    }

    static func text(from lines: [PrayerListLine]) -> String {
        lines.map { (line: PrayerListLine) -> String in
            let prefix: String = switch line.style {
            case .checklist: line.isChecked ? "[x] " : "[ ] "
            case .bullets: "• "
            case .dashes: "– "
            case nil: ""
            }
            return prefix + line.shownText
        }
        .joined(separator: "\n")
    }
}

/// The prayer list's text, all in SwiftUI: each line is its own text field, which can be a
/// checklist item (with a circle to tick, like Notes), a bullet or a dash. A bar above the
/// keyboard turns the line being typed into a list, and return carries the list on.
struct PrayerListEditor: View {
    @Binding var text: String
    @Binding var isTyping: Bool
    let font: Font

    @State private var lines: [PrayerListLine] = []
    @FocusState private var focused: PrayerListLine.ID?
    /// Apple's multiple selection: every line gets a circle, and tapping or dragging down
    /// the circles picks several lines to turn into a list at once.
    @State private var isSelecting = false
    @State private var selection = Set<PrayerListLine.ID>()

    var body: some View {
        List(selection: $selection) {
            ForEach($lines) { $line in
                row($line)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 3, leading: 0, bottom: 3, trailing: 0))
            }
            // Tapping below the last line types on it.
            Color.clear
                .frame(height: 100)
                .contentShape(Rectangle())
                .onTapGesture { if !isSelecting { focused = lines.last?.id } }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .selectionDisabled()
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(isSelecting ? .active : .inactive))
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.basedOnSize)
        .font(font)
        .overlay(alignment: .topLeading) {
            if lines.allSatisfy({ $0.shownText.isEmpty && $0.style == nil }) && focused == nil && !isSelecting {
                Text("The people and things in your life you’d like to pray for…")
                    .foregroundStyle(.tertiary)
                    .font(font)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottom) {
            if isSelecting {
                selectionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.3), value: isSelecting)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                ForEach(PrayerListStyle.allCases, id: \.self) { style in
                    Button {
                        toggle(style)
                    } label: {
                        Image(systemName: style.systemImage)
                    }
                    .accessibilityLabel(style.name)
                    .accessibilityAddTraits(focusedLine?.style == style ? .isSelected : [])
                }
                Spacer()
                Button("Select") { startSelecting() }
            }
        }
        .onAppear { lines = PrayerListLine.lines(from: text) }
        .onChange(of: lines) { _, lines in
            text = PrayerListLine.text(from: lines)
        }
        .onChange(of: focused) { _, focused in
            if isTyping != (focused != nil) { isTyping = focused != nil }
        }
        .onChange(of: isTyping) { _, typing in
            if !typing { focused = nil }
        }
        .sensoryFeedback(.selection, trigger: lines.map(\.isChecked))
    }

    /// While picking lines: a list button for each kind of list, and Done.
    private var selectionBar: some View {
        HStack(spacing: 4) {
            ForEach(PrayerListStyle.allCases, id: \.self) { style in
                Button {
                    apply(style, to: selection)
                } label: {
                    Image(systemName: style.systemImage)
                        .font(.system(size: 19, weight: .medium))
                        .frame(width: 48, height: 40)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(selection.isEmpty)
                .accessibilityLabel(style.name)
            }
            Button("Done") { isSelecting = false }
                .font(.body.weight(.semibold))
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
        }
        .padding(6)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.bottom, 4)
    }

    /// Puts the keyboard away and starts picking lines, beginning with the one being typed.
    private func startSelecting() {
        selection = focused.map { [$0] } ?? []
        focused = nil
        isSelecting = true
    }

    private func row(_ line: Binding<PrayerListLine>) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            switch line.wrappedValue.style {
            case .checklist:
                Button {
                    line.wrappedValue.isChecked.toggle()
                } label: {
                    Image(systemName: line.wrappedValue.isChecked ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(line.wrappedValue.isChecked ? "Checked" : "Not Checked")
            case .bullets:
                Text("•")
            case .dashes:
                Text("–")
            case nil:
                EmptyView()
            }
            TextField("", text: line.text, axis: .vertical)
                .focused($focused, equals: line.wrappedValue.id)
                // While picking lines, a tap picks the line instead of typing in it.
                .allowsHitTesting(!isSelecting)
                // In case return is taken as "done" rather than typed: start a new line anyway.
                .onSubmit { edited(line.wrappedValue.id, line.wrappedValue.text + "\n") }
                .onChange(of: line.wrappedValue.text) { _, newText in
                    edited(line.wrappedValue.id, newText)
                }
        }
    }

    private var focusedLine: PrayerListLine? {
        lines.first { $0.id == focused }
    }

    // MARK: Editing

    /// Turns the line being typed into the list, or back into a plain line if it already is one.
    private func toggle(_ style: PrayerListStyle) {
        guard let focused else { return }
        apply(style, to: [focused])
    }

    /// Turns the lines into the list, or back into plain lines if they all already are one.
    private func apply(_ style: PrayerListStyle, to ids: Set<PrayerListLine.ID>) {
        let chosen = lines.indices.filter { ids.contains(lines[$0].id) }
        guard !chosen.isEmpty else { return }
        let allAlready = chosen.allSatisfy { lines[$0].style == style }
        for index in chosen {
            if lines[index].style != style || allAlready { lines[index].isChecked = false }
            lines[index].style = allAlready ? nil : style
        }
    }

    /// Return and backspace, which arrive as changes to a line's text.
    private func edited(_ id: PrayerListLine.ID, _ newText: String) {
        guard let index = lines.firstIndex(where: { $0.id == id }) else { return }
        let start = PrayerListLine.start

        if let newline = newText.firstIndex(of: "\n") {
            // Return: what's after the cursor moves to a new line, which carries the list on.
            let before = String(newText[..<newline])
            let after = String(newText[newText.index(after: newline)...]).replacingOccurrences(of: start, with: "")
            let style = lines[index].style
            if style != nil && before.replacingOccurrences(of: start, with: "").isEmpty && after.isEmpty {
                // Return on an empty item ends the list.
                lines[index].text = start
                lines[index].style = nil
                return
            }
            lines[index].text = before
            let next = PrayerListLine(text: start + after, style: style)
            lines.insert(next, at: index + 1)
            // The new line's field only exists after this update, so move to it just after.
            // Until then the keyboard stays with this line instead of going away.
            Task { @MainActor in focused = next.id }
            return
        }

        if !newText.contains(start) {
            // Backspace at the start of the line.
            if lines[index].style != nil {
                lines[index].style = nil
                lines[index].text = start + newText
            } else if index > 0 {
                // A plain line joins the one above.
                // Move to the line above first, so the keyboard stays up when this one goes.
                let removed = lines[index].id
                lines[index - 1].text += newText
                lines[index].text = start
                focused = lines[index - 1].id
                Task { @MainActor in lines.removeAll { $0.id == removed } }
            } else {
                lines[index].text = start + newText
            }
            return
        }

        if !newText.hasPrefix(start) {
            // Typed before the invisible character: keep it at the front.
            lines[index].text = start + newText.replacingOccurrences(of: start, with: "")
        }
    }
}
