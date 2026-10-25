import SwiftUI

/// Every section of the book. Tap a section to see its prayers, shortest first.
struct ContentsView: View {
    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss

    let currentPrayerID: Int?
    let progress: Int
    let onOpen: (Int) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ProgressView(value: Double(progress), total: 100) {
                        Text("\(progress)% read")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(library.enabledLanguages) { language in
                    Section {
                        ForEach(library.sections.filter { $0.language == language }) { section in
                            NavigationLink(value: section) {
                                HStack {
                                    Text(section.name)
                                    Spacer()
                                    if section.prayers.contains(where: { $0.id == currentPrayerID }) {
                                        Image(systemName: "book.fill")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text("\(section.prayers.count)")
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        if library.enabledLanguages.count > 1 {
                            Text(language.name)
                        }
                    }
                }
            }
            .navigationTitle("Contents")
            .navigationDestination(for: BookSection.self) { section in
                SectionPrayersView(section: section, currentPrayerID: currentPrayerID, onOpen: onOpen)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton { dismiss() }
                }
            }
        }
    }
}

private struct SectionPrayersView: View {
    let section: BookSection
    let currentPrayerID: Int?
    let onOpen: (Int) -> Void

    var body: some View {
        List(section.prayers) { prayer in
            Button { onOpen(prayer.id) } label: {
                PrayerRow(prayer: prayer, showsSection: false, isCurrent: prayer.id == currentPrayerID)
            }
            .tint(.primary)
        }
        .navigationTitle(section.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A prayer in a list: its opening words, author and length.
struct PrayerRow: View {
    let prayer: Prayer
    var showsSection = true
    var isCurrent = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(prayer.title)
                    .font(.body)
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                Text(details)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if isCurrent {
                Image(systemName: "book.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var details: String {
        var parts = [prayer.author, "\(prayer.wordCount) words"]
        if showsSection { parts.insert(prayer.category, at: 0) }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

/// The round × button used to close sheets.
struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
        }
        .accessibilityLabel("Close")
    }
}
