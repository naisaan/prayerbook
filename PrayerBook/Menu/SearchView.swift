import SwiftUI

/// Search every prayer in the book, with recent searches, like Apple Books' "Search Book".
struct SearchView: View {
    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss

    let onOpen: (Int, String) -> Void

    @State private var query = ""
    @State private var isSearching = false
    @State private var results: [SearchResult] = []

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        NavigationStack {
            List {
                if trimmedQuery.isEmpty {
                    if !library.recentSearches.isEmpty {
                        Section {
                            ForEach(library.recentSearches, id: \.self) { term in
                                Button { query = term } label: {
                                    Label(term, systemImage: "magnifyingglass")
                                }
                                .tint(.primary)
                            }
                        } header: {
                            HStack {
                                Text("Recent Searches")
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(.primary)
                                    .textCase(nil)
                                Spacer()
                                Button("Clear") { library.clearRecentSearches() }
                                    .textCase(nil)
                            }
                        }
                    }
                } else {
                    ForEach(results) { result in
                        Button {
                            library.addRecentSearch(trimmedQuery)
                            onOpen(result.prayer.id, trimmedQuery)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.prayer.title)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text(highlighted(result.snippet))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                                Text(result.prayer.category)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .tint(.primary)
                    }
                }
            }
            .overlay {
                if !trimmedQuery.isEmpty && results.isEmpty {
                    ContentUnavailableView.search(text: trimmedQuery)
                }
            }
            .navigationTitle("Search Book")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, isPresented: $isSearching, prompt: "In this book")
            .onSubmit(of: .search) { library.addRecentSearch(trimmedQuery) }
            .task(id: query) {
                // Wait for a short pause in typing before searching.
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                results = library.search(trimmedQuery)
            }
            .onAppear { isSearching = true }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton { dismiss() }
                }
            }
        }
    }

    /// Makes the searched words stand out in the snippet.
    private func highlighted(_ snippet: String) -> AttributedString {
        var text = AttributedString(snippet)
        for word in trimmedQuery.split(whereSeparator: \.isWhitespace).map(String.init) {
            var searchStart = text.startIndex
            while searchStart < text.endIndex,
                  let range = text[searchStart...].range(of: word, options: [.caseInsensitive, .diacriticInsensitive]) {
                text[range].foregroundColor = .primary
                text[range].font = .subheadline.weight(.semibold)
                searchStart = range.upperBound
            }
        }
        return text
    }
}
