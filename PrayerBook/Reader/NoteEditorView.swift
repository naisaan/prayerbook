import SwiftUI

/// The screen for writing a note on a highlight: the passage quoted in the book's font, with
/// room to type beneath it. The check button saves; swiping the screen away leaves the note
/// as it was.
struct NoteEditorView: View {
    let highlight: Highlight
    let font: ReaderFont
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var text: String
    @FocusState private var isTyping: Bool

    init(highlight: Highlight, font: ReaderFont, onSave: @escaping (String) -> Void) {
        self.highlight = highlight
        self.font = font
        self.onSave = onSave
        _text = State(initialValue: highlight.note ?? "")
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
                    onSave(text)
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
            Text(highlight.text.split(whereSeparator: \.isNewline).joined(separator: " "))
                .font(font.font(size: 16))
                .foregroundStyle(.secondary)
                .lineLimit(6)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 17)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(uiColor: highlight.style.markerColor))
                        .frame(width: 3)
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
    }

    /// The time the highlight was made, with the date too if it wasn't today.
    private var date: String {
        Calendar.current.isDateInToday(highlight.created)
            ? highlight.created.formatted(date: .omitted, time: .shortened)
            : highlight.created.formatted(date: .abbreviated, time: .shortened)
    }
}
