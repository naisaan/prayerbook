import SwiftUI

/// The screen for writing a note: what it's about quoted in the book's font, with room to
/// type beneath it. The check button saves; swiping the screen away leaves the note as it was.
///
/// A note on a highlight quotes the highlighted passage, in the highlight's color. A note on
/// a whole prayer quotes the prayer's title, larger, with the note's own color to pick.
struct NoteEditorView: View {
    enum Subject {
        case highlight(Highlight)
        case prayer(title: String, note: PrayerNote?)
    }

    let subject: Subject
    let font: ReaderFont
    /// Called with the note's text, and for a prayer note its color.
    let onSave: (String, HighlightColor) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var text: String
    @State private var color: HighlightColor
    @FocusState private var isTyping: Bool

    init(subject: Subject, font: ReaderFont, onSave: @escaping (String, HighlightColor) -> Void) {
        self.subject = subject
        self.font = font
        self.onSave = onSave
        switch subject {
        case .highlight(let highlight):
            _text = State(initialValue: highlight.note ?? "")
            _color = State(initialValue: Highlights.shared.lastHighlightColor)
        case .prayer(_, let note):
            _text = State(initialValue: note?.text ?? "")
            _color = State(initialValue: note?.color ?? Highlights.shared.lastHighlightColor)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                HStack(spacing: 6) {
                    Text("Note").fontWeight(.semibold)
                    Text(date).foregroundStyle(.secondary)
                }
                .font(.title3)
                Spacer()
                Button {
                    onSave(text, color)
                    dismiss()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
                        .frame(width: 52, height: 52)
                        .background(Color.primary, in: .circle)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Save")
            }

            // The bar beside the quote is exactly as tall as the quote's lines.
            quote
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 17)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(uiColor: markerColor))
                        .frame(width: 3)
                }

            if case .prayer = subject {
                colorPicker
            }

            TextEditor(text: $text)
                .focused($isTyping)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, -5)
                .padding(.top, -8)
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Add a note…")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .onAppear { isTyping = true }
        .sensoryFeedback(.selection, trigger: color)
    }

    @ViewBuilder
    private var quote: some View {
        switch subject {
        case .highlight(let highlight):
            Text(highlight.text.split(whereSeparator: \.isNewline).joined(separator: " "))
                .font(font.font(size: 16))
                .lineLimit(6)
        case .prayer(let title, _):
            Text(title)
                .font(font.font(size: 22))
                .lineLimit(3)
        }
    }

    /// The four highlight colors, for the square beside a prayer's heading.
    private var colorPicker: some View {
        HStack(spacing: 18) {
            ForEach(HighlightColor.allCases, id: \.self) { option in
                Button { color = option } label: {
                    Circle()
                        .fill(Color(uiColor: option.swatch))
                        .frame(width: 28, height: 28)
                        .padding(4)
                        .overlay {
                            if option == color {
                                Circle().strokeBorder(Color.primary, lineWidth: 2)
                            }
                        }
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(option.name)
                .accessibilityAddTraits(option == color ? .isSelected : [])
            }
        }
    }

    private var markerColor: UIColor {
        switch subject {
        case .highlight(let highlight): highlight.style.markerColor
        case .prayer: color.swatch
        }
    }

    /// When the note (or its highlight) was made, with the date too if it wasn't today.
    private var date: String {
        let created: Date
        switch subject {
        case .highlight(let highlight): created = highlight.created
        case .prayer(_, let note): created = note?.created ?? .now
        }
        return Calendar.current.isDateInToday(created)
            ? created.formatted(date: .omitted, time: .shortened)
            : created.formatted(date: .abbreviated, time: .shortened)
    }
}
