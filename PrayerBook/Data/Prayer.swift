import Foundation

/// One prayer, exactly as it is stored in the original Prayer Book database.
struct Prayer: Identifiable, Hashable {
    let id: Int
    /// The section the prayer belongs to, such as "Aid and Assistance".
    let category: String
    /// The prayer text as simple HTML (`<p class="opening">`, `<span class="versal">`, …).
    let html: String
    /// The opening words, used as the prayer's title.
    let title: String
    let citation: String
    let author: String
    let languageCode: String
    let wordCount: Int
    /// Plain text version of the prayer, used for search and sharing.
    let searchText: String

    static func == (lhs: Prayer, rhs: Prayer) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// The prayer as plain text, ready to share.
    var shareText: String {
        var body = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.isEmpty {
            // A prayer added in the app (like "Intone, O My servant") has no plain text saved,
            // so take it from its markup: paragraphs on their own lines, tags left out.
            body = html
                .replacingOccurrences(of: "</p>", with: "\n\n")
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "\(body)\n\n— \(author)"
    }
}

/// A section of the book, such as "Healing", with its prayers sorted shortest to longest.
struct BookSection: Identifiable, Hashable {
    let language: Language
    let name: String
    let prayers: [Prayer]

    var id: String { "\(language.code)/\(name)" }

    static func == (lhs: BookSection, rhs: BookSection) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
