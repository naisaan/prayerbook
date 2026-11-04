import SwiftUI

/// Every section of the book. Tap a section to see its prayers, shortest first.
struct ContentsView: View {
    @Environment(Library.self) private var library
    @Environment(ReaderSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    let currentPrayerID: Int?
    let onOpen: (Int) -> Void

    @State private var showsCounter = false
    @State private var expandedBookmarks: Set<String> = []
    @State private var renamingList: BookmarkList?
    @State private var renameText = ""
    @State private var deletingList: BookmarkList?

    var body: some View {
        NavigationStack {
            List {
                // Only with English on: the five steps are in English only, and "Intone, O My
                // servant" opens the English book.
                if library.enabledLanguageCodes.contains(Language.english.code) {
                    Section {
                        // Shoghi Effendi's five steps, on a page of their own.
                        NavigationLink(value: ContentsDestination.fiveSteps) {
                            Text(verbatim: FiveStepsView.title)
                        }
                    } header: {
                        // Above the five steps, in the same small gray as before.
                        Button { onOpen(TitlePage.intone.id) } label: {
                            Text(verbatim: "Intone, O My servant…")
                        }
                        .buttonStyle(.plain)
                        .font(.footnote)
                        .fontWeight(.regular)
                        .textCase(nil)
                        .foregroundStyle(.secondary)
                    }
                }
                if let obligatory {
                    Section("Daily Prayers") {
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
                        // Opens full screen, on the page's own black or white.
                        Button { showsCounter = true } label: {
                            HStack {
                                Text("Alláh-u-Abhá (95 Times)")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .tint(.primary)
                    }
                }
                if !library.bookmarkedPrayers.isEmpty || !library.bookmarkLists.isEmpty {
                    // All the bookmark lists together in one block.
                    Section {
                        if !library.bookmarkedPrayers.isEmpty {
                            BookmarkGroup(
                                name: String(localized: "Bookmarks"),
                                color: .red,
                                prayers: library.bookmarkedPrayers,
                                currentPrayerID: currentPrayerID,
                                isExpanded: expansion("bookmarks"),
                                onOpen: onOpen,
                                onDelete: { library.removeBookmarks(at: $0) }
                            )
                        }
                        ForEach(library.bookmarkLists) { list in
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
                }
                if library.enabledLanguages.count > 1 {
                    // With more than one language, each language folds up in its own block, so
                    // the reader sees every language at a glance and opens only the one they want.
                    ForEach(library.enabledLanguages) { language in
                        let sections = sections(in: language)
                        Section {
                            DisclosureGroup(isExpanded: expansion("language-\(language.code)")) {
                                ForEach(sections) { section in sectionRow(section) }
                            } label: {
                                HStack {
                                    Text(language.name)
                                    Spacer()
                                    if sections.contains(where: { $0.prayers.contains { $0.id == currentPrayerID } }) {
                                        Image(systemName: "book.fill")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } header: {
                            if language == library.enabledLanguages.first {
                                Text("Prayers")
                            }
                        }
                        // Half the usual gap between the languages, so they read as a set.
                        .listSectionSpacing(language == library.enabledLanguages.last ? .default : .custom(16))
                    }
                } else if let language = library.enabledLanguages.first {
                    Section("Prayers") {
                        ForEach(sections(in: language)) { section in sectionRow(section) }
                    }
                }
            }
            .navigationTitle("Contents")
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
            .navigationDestination(for: ContentsDestination.self) { destination in
                switch destination {
                case .fiveSteps: FiveStepsView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showsCounter) {
                NavigationStack {
                    AllahuAbhaView()
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button { showsCounter = false } label: {
                                    Label("Back", systemImage: "chevron.left")
                                }
                            }
                        }
                }
                .environment(settings)
                .environment(library)
            }
        }
    }

    private func sections(in language: Language) -> [BookSection] {
        library.sections.filter { $0.language == language && $0 != obligatory }
    }

    /// A section of prayers, with how many prayers it holds.
    private func sectionRow(_ section: BookSection) -> some View {
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
    case fiveSteps
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
        var parts = [prayer.author, String(localized: "\(prayer.wordCount) words")]
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
