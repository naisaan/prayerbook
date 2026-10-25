import Foundation
import SQLite3

/// Reads prayers from `pbdb.db`, the database that ships with the original Prayer Book app.
final class PrayerDatabase {
    private var handle: OpaquePointer?

    init() {
        guard let url = Bundle.main.url(forResource: "pbdb", withExtension: "db") else {
            assertionFailure("pbdb.db is missing from the app")
            return
        }
        // The database is part of the app bundle, so open it read-only.
        let path = "file:\(url.path)?immutable=1"
        if sqlite3_open_v2(path, &handle, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) != SQLITE_OK {
            assertionFailure("Could not open pbdb.db")
            handle = nil
        }
    }

    deinit {
        sqlite3_close(handle)
    }

    /// All prayers written in the given languages.
    func prayers(languageCodes: [String]) -> [Prayer] {
        guard let handle, !languageCodes.isEmpty else { return [] }

        let placeholders = Array(repeating: "?", count: languageCodes.count).joined(separator: ", ")
        let sql = """
            SELECT id, category, prayerText, openingWords, citation, author, language, wordCount, searchText
            FROM prayers WHERE language IN (\(placeholders))
            """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }

        for (index, code) in languageCodes.enumerated() {
            sqlite3_bind_text(statement, Int32(index + 1), code, -1, transient)
        }

        var prayers: [Prayer] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            prayers.append(Prayer(
                id: Int(sqlite3_column_int64(statement, 0)),
                category: text(statement, 1),
                html: text(statement, 2),
                title: text(statement, 3),
                citation: text(statement, 4),
                author: text(statement, 5),
                languageCode: text(statement, 6),
                wordCount: Int(sqlite3_column_int64(statement, 7)),
                searchText: text(statement, 8)
            ))
        }
        return prayers
    }

    private func text(_ statement: OpaquePointer?, _ column: Int32) -> String {
        guard let value = sqlite3_column_text(statement, column) else { return "" }
        return String(cString: value)
    }

    /// Tells SQLite to copy bound strings (Swift's `SQLITE_TRANSIENT`).
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}
