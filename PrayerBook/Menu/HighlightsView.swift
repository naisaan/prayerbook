import SwiftUI

/// Highlights and underlines, grouped by color, and the notes written on them.
struct HighlightsView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case highlights = "Highlights"
        case notes = "Notes"
        var id: String { rawValue }
    }

    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var tab: Tab = .highlights

    let onOpen: (Highlight) -> Void
    /// Opens a prayer at its first page, for a note on a whole prayer.
    let onOpenPrayer: (Int) -> Void

    /// A note in the Notes list: on a highlight, or on a whole prayer.
    private enum NoteItem: Identifiable {
        case highlight(Highlight)
        case prayer(PrayerNote)

        var id: String {
            switch self {
            case .highlight(let highlight): highlight.id.uuidString
            case .prayer(let note): "prayer-\(note.prayerID)"
            }
        }

        var created: Date {
            switch self {
            case .highlight(let highlight): highlight.created
            case .prayer(let note): note.created
            }
        }
    }

    /// Every note in the languages that are turned on, newest first.
    private var notes: [NoteItem] {
        let onHighlights = highlights.filter(\.hasNote).map(NoteItem.highlight)
        let onPrayers = Highlights.shared.prayerNotes
            .filter { library.prayersByID[$0.prayerID] != nil }
            .map(NoteItem.prayer)
        return (onHighlights + onPrayers).sorted { $0.created > $1.created }
    }

    /// Every style, in the order its group appears: the highlighter colors, then the underlines.
    private static let styles: [HighlightStyle] =
        HighlightColor.allCases.map { .highlight($0) } + UnderlineColor.allCases.map { .underline($0) }

    /// Highlights in the languages that are turned on, newest first.
    private var highlights: [Highlight] {
        Highlights.shared.all.filter { library.prayersByID[$0.prayerID] != nil }
    }

    var body: some View {
        NavigationStack {
            List {
                if tab == .highlights {
                    let visible = highlights
                    ForEach(Self.styles, id: \.self) { style in
                        let group = visible.filter { $0.style == style }
                        if !group.isEmpty {
                            Section {
                                ForEach(group) { highlight in
                                    Button { onOpen(highlight) } label: {
                                        HighlightRow(highlight: highlight, prayer: library.prayersByID[highlight.prayerID], showsNote: false)
                                    }
                                    .tint(.primary)
                                }
                                .onDelete { offsets in
                                    for offset in offsets { Highlights.shared.remove(group[offset].id) }
                                }
                            } header: {
                                header(for: style)
                            }
                        }
                    }
                } else {
                    let items = notes
                    ForEach(items) { item in
                        switch item {
                        case .highlight(let highlight):
                            Button { onOpen(highlight) } label: {
                                HighlightRow(highlight: highlight, prayer: library.prayersByID[highlight.prayerID], showsNote: true)
                            }
                            .tint(.primary)
                        case .prayer(let note):
                            Button { onOpenPrayer(note.prayerID) } label: {
                                PrayerNoteRow(note: note, prayer: library.prayersByID[note.prayerID])
                            }
                            .tint(.primary)
                        }
                    }
                    .onDelete { offsets in
                        for offset in offsets {
                            switch items[offset] {
                            case .highlight(let highlight): Highlights.shared.setNote(nil, for: highlight.id)
                            case .prayer(let note): Highlights.shared.removePrayerNote(for: note.prayerID)
                            }
                        }
                    }
                }
            }
            .overlay {
                if tab == .highlights && highlights.isEmpty {
                    ContentUnavailableView(
                        "No Highlights",
                        systemImage: "highlighter",
                        description: Text("Press and hold on a prayer’s words, then tap Highlight.")
                    )
                } else if tab == .notes && notes.isEmpty {
                    ContentUnavailableView(
                        "No Notes",
                        systemImage: "note.text",
                        description: Text("Press and hold on a prayer’s words, then tap Add Note.")
                    )
                }
            }
            .navigationTitle(LocalizedStringKey(tab.rawValue))
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                Picker("Show", selection: $tab) {
                    ForEach(Tab.allCases) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func header(for style: HighlightStyle) -> some View {
        switch style {
        case .highlight(let color):
            Label {
                Text(color.name)
            } icon: {
                Circle()
                    .fill(Color(uiColor: color.swatch))
                    .frame(width: 14, height: 14)
            }
        case .underline(let color):
            Label {
                Text(color.name(isDark: colorScheme == .dark))
            } icon: {
                Image(systemName: "underline")
                    .foregroundStyle(Color(uiColor: color.color))
            }
        }
    }
}

/// A note on a whole prayer: the prayer's title, larger, beside a bar in the note's color,
/// then the note and the prayer's section.
private struct PrayerNoteRow: View {
    let note: PrayerNote
    let prayer: Prayer?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(prayer?.title ?? "")
                .font(.title3.weight(.semibold))
                .lineLimit(2)
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(uiColor: note.color.swatch))
                        .frame(width: 3)
                }
            Label {
                Text(note.text)
                    .lineLimit(4)
            } icon: {
                Image(systemName: "note.text")
                    .foregroundStyle(Color(uiColor: note.color.swatch))
            }
            .font(.subheadline)
            if let category = prayer?.category, !category.isEmpty {
                Text(category)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

/// A highlighted passage, shown the way it looks on the page, with its prayer beneath.
private struct HighlightRow: View {
    let highlight: Highlight
    let prayer: Prayer?
    /// The note's text is written out in the Notes list. In the Highlights list an icon
    /// only says there is one.
    let showsNote: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                passage
                    .font(.body)
                    .lineLimit(5)
                if !showsNote && highlight.hasNote {
                    Spacer(minLength: 8)
                    Image(systemName: "note.text")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Note")
                }
            }
            if showsNote, let note = highlight.note, highlight.hasNote {
                Label {
                    Text(note)
                        .lineLimit(4)
                } icon: {
                    Image(systemName: "note.text")
                        .foregroundStyle(Color(uiColor: highlight.style.markerColor))
                }
                .font(.subheadline)
            }
            if let prayer {
                Text([prayer.title, prayer.category].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var passage: some View {
        let text = highlight.text
            .split(whereSeparator: \.isNewline)
            .joined(separator: " ")
        switch highlight.style {
        case .highlight(let color):
            Text(text)
                .padding(.horizontal, 4)
                .background(Color(uiColor: color.fill), in: .rect(cornerRadius: 4))
        case .underline(let color):
            Text(text)
                .underline(color: Color(uiColor: color.color))
        }
    }
}
