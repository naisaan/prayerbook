import SwiftUI

/// Saved prayers and recently read prayers.
struct BookmarksView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case bookmarks = "Bookmarks"
        case recents = "Recents"
        var id: String { rawValue }
    }

    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab = .bookmarks

    let onOpen: (Int) -> Void

    var body: some View {
        NavigationStack {
            List {
                switch tab {
                case .bookmarks:
                    ForEach(library.bookmarkedPrayers) { prayer in
                        Button { onOpen(prayer.id) } label: { PrayerRow(prayer: prayer) }
                            .tint(.primary)
                    }
                    .onDelete { library.removeBookmarks(at: $0) }
                case .recents:
                    ForEach(library.recentPrayers) { prayer in
                        Button { onOpen(prayer.id) } label: { PrayerRow(prayer: prayer) }
                            .tint(.primary)
                    }
                }
            }
            .overlay {
                if tab == .bookmarks && library.bookmarkedPrayers.isEmpty {
                    ContentUnavailableView(
                        "No Bookmarks",
                        systemImage: "bookmark",
                        description: Text("Open the menu while reading and tap the bookmark button to save a prayer.")
                    )
                } else if tab == .recents && library.recentPrayers.isEmpty {
                    ContentUnavailableView(
                        "Nothing Read Yet",
                        systemImage: "clock",
                        description: Text("Prayers you read will appear here.")
                    )
                }
            }
            .navigationTitle(tab.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                Picker("Show", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if tab == .recents && !library.recentPrayers.isEmpty {
                        Button("Clear") { library.clearRecents() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton { dismiss() }
                }
            }
        }
    }
}
