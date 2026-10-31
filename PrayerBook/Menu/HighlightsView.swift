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
                                        HighlightRow(highlight: highlight, prayer: library.prayersByID[highlight.prayerID])
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
                    let notes = highlights.filter(\.hasNote)
                    ForEach(notes) { highlight in
                        Button { onOpen(highlight) } label: {
                            HighlightRow(highlight: highlight, prayer: library.prayersByID[highlight.prayerID])
                        }
                        .tint(.primary)
                    }
                    .onDelete { offsets in
                        for offset in offsets { Highlights.shared.setNote(nil, for: notes[offset].id) }
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
                } else if tab == .notes && !highlights.contains(where: \.hasNote) {
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

/// A highlighted passage, shown the way it looks on the page, with its prayer beneath.
private struct HighlightRow: View {
    let highlight: Highlight
    let prayer: Prayer?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            passage
                .font(.body)
                .lineLimit(5)
            if let note = highlight.note, highlight.hasNote {
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
