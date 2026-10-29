import SwiftUI

/// Every section of the book. Tap a section to see its prayers, shortest first.
struct ContentsView: View {
    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss

    let currentPrayerID: Int?
    let progress: Int
    let onOpen: (Int) -> Void

    @State private var confirmingReset = false
    @State private var expandedBookmarks: Set<String> = []
    @State private var renamingList: BookmarkList?
    @State private var renameText = ""
    @State private var deletingList: BookmarkList?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ProgressView(value: Double(progress), total: 100) {
                        HStack {
                            Text("\(progress)% read")
                            Spacer()
                            if progress > 0 {
                                Button("Start Over") { confirmingReset = true }
                                    .buttonStyle(.borderless)
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("A prayer counts as read once you reach its last page.")
                }
                if let obligatory {
                    Section("Obligatory Prayers") {
                        ForEach(obligatory.prayers) { prayer in
                            Button { onOpen(prayer.id) } label: {
                                HStack {
                                    Text(prayer.title)
                                    Spacer()
                                    if prayer.id == currentPrayerID {
                                        Image(systemName: "book.fill")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .tint(.primary)
                        }
                        NavigationLink("Alláh-u-Abhá (95 Times)", value: ContentsDestination.allahuAbha)
                    }
                }
                if !library.bookmarkedPrayers.isEmpty {
                    Section {
                        BookmarkGroup(
                            name: "Bookmarks",
                            color: .red,
                            prayers: library.bookmarkedPrayers,
                            currentPrayerID: currentPrayerID,
                            isExpanded: expansion("bookmarks"),
                            onOpen: onOpen,
                            onDelete: { library.removeBookmarks(at: $0) }
                        )
                    }
                }
                ForEach(library.bookmarkLists) { list in
                    Section {
                        BookmarkGroup(
                            name: list.name,
                            color: list.color,
                            prayers: library.prayers(in: list),
                            currentPrayerID: currentPrayerID,
                            isExpanded: expansion(list.id.uuidString),
                            onOpen: onOpen,
                            onDelete: { library.removePrayers(at: $0, from: list) }
                        )
                        .contextMenu {
                            Button("Rename", systemImage: "pencil") {
                                renameText = list.name
                                renamingList = list
                            }
                            Button("Delete List", systemImage: "trash", role: .destructive) {
                                deletingList = list
                            }
                        }
                    }
                }
                ForEach(library.enabledLanguages) { language in
                    Section {
                        ForEach(library.sections.filter { $0.language == language && $0 != obligatory }) { section in
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
            .confirmationDialog("Start reading progress over?", isPresented: $confirmingReset, titleVisibility: .visible) {
                Button("Start Over", role: .destructive) { library.resetProgress() }
            } message: {
                Text("Your bookmarks and recent prayers are kept.")
            }
            .navigationDestination(for: BookSection.self) { section in
                SectionPrayersView(section: section, currentPrayerID: currentPrayerID, onOpen: onOpen)
            }
            .alert("Rename List", isPresented: isPresenting($renamingList)) {
                TextField("Name", text: $renameText)
                Button("Cancel", role: .cancel) {}
                Button("Rename") {
                    if let renamingList { library.renameBookmarkList(renamingList.id, to: renameText) }
                }
            }
            .confirmationDialog(
                "Delete “\(deletingList?.name ?? "")”?",
                isPresented: isPresenting($deletingList),
                titleVisibility: .visible
            ) {
                Button("Delete List", role: .destructive) {
                    if let deletingList { library.deleteBookmarkList(deletingList.id) }
                }
            } message: {
                Text("The prayers stay in the book; only this list is removed.")
            }
            .navigationDestination(for: ContentsDestination.self) { _ in
                AllahuAbhaView()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton { dismiss() }
                }
            }
        }
    }

    private func expansion(_ key: String) -> Binding<Bool> {
        Binding(
            get: { expandedBookmarks.contains(key) },
            set: { isOn in
                if isOn { expandedBookmarks.insert(key) } else { expandedBookmarks.remove(key) }
            }
        )
    }

    private func isPresenting(_ item: Binding<BookmarkList?>) -> Binding<Bool> {
        Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })
    }

    /// The English obligatory prayers, pinned to the top with the Alláh-u-Abhá counter.
    private var obligatory: BookSection? {
        library.sections.first { $0.language.code == "en" && $0.name == "Obligatory Prayers" }
    }
}

private enum ContentsDestination: Hashable {
    case allahuAbha
}

/// A bookmark list that opens on tap to show its prayers.
private struct BookmarkGroup: View {
    let name: String
    let color: BookmarkColor
    let prayers: [Prayer]
    let currentPrayerID: Int?
    @Binding var isExpanded: Bool
    let onOpen: (Int) -> Void
    let onDelete: (IndexSet) -> Void

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if prayers.isEmpty {
                Text("Tap this list’s bookmark button in the menu while reading to add a prayer.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(prayers) { prayer in
                Button { onOpen(prayer.id) } label: {
                    PrayerRow(prayer: prayer, isCurrent: prayer.id == currentPrayerID)
                }
                .tint(.primary)
            }
            .onDelete(perform: onDelete)
        } label: {
            HStack {
                Label {
                    Text(name)
                } icon: {
                    BookmarkBadge(size: 28, color: color)
                        .accessibilityHidden(true)
                }
                Spacer()
                Text("\(prayers.count)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SectionPrayersView: View {
    @Environment(Library.self) private var library
    let section: BookSection
    let currentPrayerID: Int?
    let onOpen: (Int) -> Void

    var body: some View {
        List(section.prayers) { prayer in
            Button { onOpen(prayer.id) } label: {
                PrayerRow(prayer: prayer, showsSection: false, isCurrent: prayer.id == currentPrayerID, isRead: library.isRead(prayer.id))
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
    var isRead = false

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
            } else if isRead {
                Image(systemName: "checkmark")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Read")
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
