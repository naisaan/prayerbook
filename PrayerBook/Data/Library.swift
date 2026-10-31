import Foundation
import Observation

/// A search match, with a short piece of the prayer around the words that matched.
struct SearchResult: Identifiable {
    let prayer: Prayer
    let snippet: String
    var id: Int { prayer.id }
}

/// The color of a bookmark list. The original list is red; the reader's own lists take blue,
/// green and purple, in that order.
enum BookmarkColor: String, Codable, CaseIterable {
    case red, blue, green, purple
}

/// One of the reader's own bookmark lists, made with the + button in the menu.
struct BookmarkList: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var color: BookmarkColor
    var prayerIDs: [Int]
}

/// Everything the app knows about the prayers: which languages are on, the sections in book
/// order, bookmarks, recently read prayers and recent searches.
@Observable
final class Library {
    private let database = PrayerDatabase()
    private let defaults = UserDefaults.standard

    private(set) var enabledLanguageCodes: [String]
    /// The whole book: sections grouped by language, prayers shortest to longest.
    private(set) var sections: [BookSection] = []
    private(set) var bookmarks: [Int]
    /// The reader's own bookmark lists, oldest first. There can be up to three.
    private(set) var bookmarkLists: [BookmarkList]
    private(set) var recents: [Int]
    private(set) var recentSearches: [String]
    /// Prayers read to their last page. Used for the "% read" progress.
    private(set) var readPrayers: Set<Int>
    private(set) var prayersByID: [Int: Prayer] = [:]

    init() {
        let defaults = UserDefaults.standard
        enabledLanguageCodes = defaults.stringArray(forKey: Keys.languages) ?? [Language.english.code]
        bookmarks = defaults.array(forKey: Keys.bookmarks) as? [Int] ?? []
        bookmarkLists = defaults.data(forKey: Keys.bookmarkLists)
            .flatMap { try? JSONDecoder().decode([BookmarkList].self, from: $0) } ?? []
        recents = defaults.array(forKey: Keys.recents) as? [Int] ?? []
        recentSearches = defaults.stringArray(forKey: Keys.recentSearches) ?? []
        readPrayers = Set(defaults.array(forKey: Keys.readPrayers) as? [Int] ?? [])
        reload()
    }

    // MARK: Languages

    var enabledLanguages: [Language] {
        Language.all.filter { enabledLanguageCodes.contains($0.code) }
    }

    func isEnabled(_ language: Language) -> Bool {
        enabledLanguageCodes.contains(language.code)
    }

    /// Turns a language on or off. At least one language always stays on.
    func setLanguage(_ language: Language, enabled: Bool) {
        var codes = Set(enabledLanguageCodes)
        if enabled {
            codes.insert(language.code)
        } else {
            guard codes.count > 1 else { return }
            codes.remove(language.code)
        }
        enabledLanguageCodes = Language.all.map(\.code).filter(codes.contains)
        defaults.set(enabledLanguageCodes, forKey: Keys.languages)
        reload()
    }

    private func reload() {
        let prayers = database.prayers(languageCodes: enabledLanguageCodes)
        prayersByID = Dictionary(prayers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        var result: [BookSection] = []
        for language in enabledLanguages {
            let grouped = Dictionary(grouping: prayers.filter { $0.languageCode == language.code }, by: \.category)
            for name in grouped.keys.sorted(by: Self.sectionOrder) {
                let sorted = grouped[name, default: []].sorted {
                    ($0.wordCount, $0.title) < ($1.wordCount, $1.title)
                }
                result.append(BookSection(language: language, name: name, prayers: sorted))
            }
        }
        sections = result
    }

    /// The obligatory prayers open the book, right after its title page.
    nonisolated private static let firstSections: Set<String> = ["Obligatory Prayers", "Preghiere obbligatorie", "Pinngitsoorani Qinnutissat"]

    /// The obligatory prayers first, then alphabetical, ignoring a leading "The", like the original app.
    nonisolated private static func sectionOrder(_ lhs: String, _ rhs: String) -> Bool {
        if firstSections.contains(lhs) != firstSections.contains(rhs) {
            return firstSections.contains(lhs)
        }
        func key(_ name: String) -> String {
            name.hasPrefix("The ") ? String(name.dropFirst(4)) : name
        }
        return key(lhs).localizedCaseInsensitiveCompare(key(rhs)) == .orderedAscending
    }

    // MARK: Bookmarks

    func isBookmarked(_ prayerID: Int) -> Bool {
        bookmarks.contains(prayerID)
    }

    func toggleBookmark(_ prayerID: Int) {
        if let index = bookmarks.firstIndex(of: prayerID) {
            bookmarks.remove(at: index)
        } else {
            bookmarks.insert(prayerID, at: 0)
        }
        defaults.set(bookmarks, forKey: Keys.bookmarks)
    }

    func removeBookmarks(at offsets: IndexSet) {
        let visible = bookmarkedPrayers.map(\.id)
        let removed = Set(offsets.map { visible[$0] })
        bookmarks.removeAll { removed.contains($0) }
        defaults.set(bookmarks, forKey: Keys.bookmarks)
    }

    /// Bookmarked prayers in the languages that are turned on.
    var bookmarkedPrayers: [Prayer] {
        bookmarks.compactMap { prayersByID[$0] }
    }

    // MARK: Bookmark lists

    static let maxBookmarkLists = 3

    var canAddBookmarkList: Bool { bookmarkLists.count < Self.maxBookmarkLists }

    /// Makes a new list with the next free color.
    func addBookmarkList(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let used = Set(bookmarkLists.map(\.color))
        guard canAddBookmarkList, !trimmed.isEmpty,
              let color = [BookmarkColor.blue, .green, .purple].first(where: { !used.contains($0) })
        else { return }
        bookmarkLists.append(BookmarkList(id: UUID(), name: trimmed, color: color, prayerIDs: []))
        saveBookmarkLists()
    }

    func renameBookmarkList(_ listID: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = bookmarkLists.firstIndex(where: { $0.id == listID }) else { return }
        bookmarkLists[index].name = trimmed
        saveBookmarkLists()
    }

    func deleteBookmarkList(_ listID: UUID) {
        bookmarkLists.removeAll { $0.id == listID }
        saveBookmarkLists()
    }

    func isBookmarked(_ prayerID: Int, in listID: UUID) -> Bool {
        bookmarkLists.first { $0.id == listID }?.prayerIDs.contains(prayerID) ?? false
    }

    func toggleBookmark(_ prayerID: Int, in listID: UUID) {
        guard let index = bookmarkLists.firstIndex(where: { $0.id == listID }) else { return }
        if let position = bookmarkLists[index].prayerIDs.firstIndex(of: prayerID) {
            bookmarkLists[index].prayerIDs.remove(at: position)
        } else {
            bookmarkLists[index].prayerIDs.insert(prayerID, at: 0)
        }
        saveBookmarkLists()
    }

    /// The prayers in a list, in the languages that are turned on.
    func prayers(in list: BookmarkList) -> [Prayer] {
        list.prayerIDs.compactMap { prayersByID[$0] }
    }

    func removePrayers(at offsets: IndexSet, from list: BookmarkList) {
        let visible = prayers(in: list).map(\.id)
        let removed = Set(offsets.map { visible[$0] })
        guard let index = bookmarkLists.firstIndex(where: { $0.id == list.id }) else { return }
        bookmarkLists[index].prayerIDs.removeAll { removed.contains($0) }
        saveBookmarkLists()
    }

    /// The color of the first list holding this prayer (red first), for the badge on its page.
    func bookmarkColor(for prayerID: Int) -> BookmarkColor? {
        if isBookmarked(prayerID) { return .red }
        return bookmarkLists.first { $0.prayerIDs.contains(prayerID) }?.color
    }

    private func saveBookmarkLists() {
        defaults.set(try? JSONEncoder().encode(bookmarkLists), forKey: Keys.bookmarkLists)
    }

    // MARK: Recents

    func noteOpened(_ prayerID: Int) {
        guard recents.first != prayerID else { return }
        recents.removeAll { $0 == prayerID }
        recents.insert(prayerID, at: 0)
        recents = Array(recents.prefix(30))
        defaults.set(recents, forKey: Keys.recents)
    }

    func clearRecents() {
        recents = []
        defaults.set(recents, forKey: Keys.recents)
    }

    var recentPrayers: [Prayer] {
        recents.compactMap { prayersByID[$0] }
    }

    // MARK: Reading progress

    func isRead(_ prayerID: Int) -> Bool {
        readPrayers.contains(prayerID)
    }

    func markRead(_ prayerID: Int) {
        guard !readPrayers.contains(prayerID) else { return }
        readPrayers.insert(prayerID)
        defaults.set(Array(readPrayers), forKey: Keys.readPrayers)
    }

    /// Whole-number percentage of the given prayers that have been read.
    func percentRead(of prayerIDs: [Int]) -> Int {
        guard !prayerIDs.isEmpty else { return 0 }
        let read = prayerIDs.filter { readPrayers.contains($0) }.count
        let percent = Int((Double(read) / Double(prayerIDs.count) * 100).rounded())
        // Show at least 1% as soon as one prayer is read, and 100% only when all are.
        if read > 0 && percent == 0 { return 1 }
        if read < prayerIDs.count && percent == 100 { return 99 }
        return percent
    }

    func resetProgress() {
        readPrayers = []
        defaults.set([Int](), forKey: Keys.readPrayers)
    }

    // MARK: Search

    /// Prayers containing every word of the query, in book order.
    func search(_ query: String) -> [SearchResult] {
        let words = query.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty, query.count >= 2 else { return [] }

        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        var results: [SearchResult] = []
        for section in sections {
            for prayer in section.prayers {
                let text = prayer.searchText
                guard words.allSatisfy({ text.range(of: $0, options: options) != nil }),
                      let match = text.range(of: words[0], options: options)
                else { continue }
                results.append(SearchResult(prayer: prayer, snippet: Self.snippet(in: text, around: match)))
            }
        }
        return results
    }

    private static func snippet(in text: String, around match: Range<String.Index>) -> String {
        let start = text.index(match.lowerBound, offsetBy: -40, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(match.upperBound, offsetBy: 90, limitedBy: text.endIndex) ?? text.endIndex
        var snippet = text[start..<end]
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        if start > text.startIndex { snippet = "…" + snippet }
        if end < text.endIndex { snippet += "…" }
        return snippet
    }

    func addRecentSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        recentSearches.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        recentSearches.insert(trimmed, at: 0)
        recentSearches = Array(recentSearches.prefix(10))
        defaults.set(recentSearches, forKey: Keys.recentSearches)
    }

    func clearRecentSearches() {
        recentSearches = []
        defaults.set(recentSearches, forKey: Keys.recentSearches)
    }

    private enum Keys {
        static let languages = "enabledLanguages"
        static let bookmarks = "bookmarks"
        static let bookmarkLists = "bookmarkLists"
        static let recents = "recents"
        static let recentSearches = "recentSearches"
        static let readPrayers = "readPrayers"
    }
}
