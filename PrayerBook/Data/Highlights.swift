import Foundation
import Observation
import UIKit

/// The four highlighter colors.
enum HighlightColor: String, Codable, CaseIterable {
    case yellow, green, blue, pink

    /// The color of the dot in the highlight menu.
    var swatch: UIColor {
        switch self {
        case .yellow: UIColor(hex: 0xEFD139)
        case .green: UIColor(hex: 0x98DC81)
        case .blue: UIColor(hex: 0x95B9FF)
        case .pink: UIColor(hex: 0xFF9CB4)
        }
    }

    /// The color behind highlighted text: the swatch, softened so the text stays easy to read.
    /// In dark mode it's deeper, so white text still stands out.
    var fill: UIColor {
        let swatch = swatch
        return UIColor { traits in
            swatch.withAlphaComponent(traits.userInterfaceStyle == .dark ? 0.55 : 0.6)
        }
    }

    var name: String {
        switch self {
        case .yellow: String(localized: "Yellow")
        case .green: String(localized: "Green")
        case .blue: String(localized: "Blue")
        case .pink: String(localized: "Pink")
        }
    }
}

/// The four underline colors. `ink` is the text's own color: black in light mode, white in dark.
enum UnderlineColor: String, Codable, CaseIterable {
    case ink, red, blue, green

    var color: UIColor {
        switch self {
        case .ink: Typography.textColor
        case .red: UIColor(hex: 0xC71812)
        case .blue: UIColor(hex: 0x1F5FD6)
        case .green: UIColor(hex: 0x2B6E3F)
        }
    }

    /// The name of the color, which for `ink` depends on light or dark mode.
    func name(isDark: Bool) -> String {
        switch self {
        case .ink: isDark ? String(localized: "White") : String(localized: "Black")
        case .red: String(localized: "Red")
        case .blue: String(localized: "Blue")
        case .green: String(localized: "Green")
        }
    }
}

enum HighlightStyle: Codable, Hashable {
    case highlight(HighlightColor)
    case underline(UnderlineColor)

    /// The color of the square in the margin by a note, and of the bar beside its quote.
    var markerColor: UIColor {
        switch self {
        case .highlight(let color): color.swatch
        case .underline(let color): color.color
        }
    }
}

/// A highlighted or underlined passage of a prayer.
struct Highlight: Identifiable, Codable, Hashable {
    let id: UUID
    let prayerID: Int
    /// Where the passage is in the prayer's whole text (with the drop cap letter in its place),
    /// so it stays put when the font, size or drop cap setting changes.
    var location: Int
    var length: Int
    var style: HighlightStyle
    var text: String
    let created: Date
    /// What the reader wrote about the passage, if anything.
    var note: String? = nil

    var range: NSRange { NSRange(location: location, length: length) }

    var hasNote: Bool { !(note ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

/// A note on a whole prayer, written from the prayer's heading.
struct PrayerNote: Identifiable, Codable, Hashable {
    let prayerID: Int
    var text: String
    var color: HighlightColor
    let created: Date

    var id: Int { prayerID }
}

extension Notification.Name {
    static let highlightsDidChange = Notification.Name("highlightsDidChange")
}

/// Every highlight and underline, saved on the device.
@Observable
final class Highlights {
    static let shared = Highlights()

    private let defaults = UserDefaults.standard
    /// Newest first.
    private(set) var all: [Highlight]
    /// The color a new highlight gets: the one picked last.
    private(set) var lastHighlightColor: HighlightColor
    /// The color an underline gets: the one picked last.
    private(set) var lastUnderlineColor: UnderlineColor
    /// Notes on whole prayers, newest first.
    private(set) var prayerNotes: [PrayerNote]

    private init() {
        all = defaults.data(forKey: Keys.highlights)
            .flatMap { try? JSONDecoder().decode([Highlight].self, from: $0) } ?? []
        prayerNotes = defaults.data(forKey: Keys.prayerNotes)
            .flatMap { try? JSONDecoder().decode([PrayerNote].self, from: $0) } ?? []
        lastHighlightColor = defaults.string(forKey: Keys.lastHighlightColor).flatMap(HighlightColor.init) ?? .yellow
        lastUnderlineColor = defaults.string(forKey: Keys.lastUnderlineColor).flatMap(UnderlineColor.init) ?? .ink
    }

    func highlights(inPrayer prayerID: Int) -> [Highlight] {
        all.filter { $0.prayerID == prayerID }
    }

    func highlight(withID id: UUID) -> Highlight? {
        all.first { $0.id == id }
    }

    /// Highlights a passage in the last color picked. Where it covers part of an older
    /// highlight, the new one takes that part over and the rest of the older one stays.
    /// `text` gives the prayer's text for a range, to save with the highlight.
    @discardableResult
    func add(prayerID: Int, range: NSRange, text: (NSRange) -> String) -> Highlight {
        var kept: [Highlight] = []
        for old in all {
            guard old.prayerID == prayerID, NSIntersectionRange(old.range, range).length > 0 else {
                kept.append(old)
                continue
            }
            let before = NSRange(location: old.location, length: max(range.location - old.location, 0))
            let after = NSRange(location: NSMaxRange(range), length: max(NSMaxRange(old.range) - NSMaxRange(range), 0))
            // The older highlight's note stays with the first piece left of it.
            var note = old.note
            for part in [before, after] where part.length > 0 {
                let piece = text(part)
                guard !piece.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                kept.append(Highlight(id: UUID(), prayerID: prayerID, location: part.location, length: part.length,
                                      style: old.style, text: piece, created: old.created, note: note))
                note = nil
            }
        }
        let highlight = Highlight(
            id: UUID(),
            prayerID: prayerID,
            location: range.location,
            length: range.length,
            style: .highlight(lastHighlightColor),
            text: text(range),
            created: .now
        )
        all = [highlight] + kept
        save()
        return highlight
    }

    func setStyle(_ style: HighlightStyle, for id: UUID) {
        guard let index = all.firstIndex(where: { $0.id == id }) else { return }
        all[index].style = style
        switch style {
        case .highlight(let color):
            lastHighlightColor = color
            defaults.set(color.rawValue, forKey: Keys.lastHighlightColor)
        case .underline(let color):
            lastUnderlineColor = color
            defaults.set(color.rawValue, forKey: Keys.lastUnderlineColor)
        }
        save()
    }

    /// Saves a note on a highlight. An empty note removes it.
    func setNote(_ note: String?, for id: UUID) {
        guard let index = all.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        all[index].note = trimmed.isEmpty ? nil : note
        save()
    }

    func prayerNote(for prayerID: Int) -> PrayerNote? {
        prayerNotes.first { $0.prayerID == prayerID }
    }

    /// Saves a note on a whole prayer. An empty note removes it.
    func setPrayerNote(_ text: String, color: HighlightColor, for prayerID: Int) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return removePrayerNote(for: prayerID)
        }
        if let index = prayerNotes.firstIndex(where: { $0.prayerID == prayerID }) {
            prayerNotes[index].text = text
            prayerNotes[index].color = color
        } else {
            prayerNotes.insert(PrayerNote(prayerID: prayerID, text: text, color: color, created: .now), at: 0)
        }
        save()
    }

    func removePrayerNote(for prayerID: Int) {
        prayerNotes.removeAll { $0.prayerID == prayerID }
        save()
    }

    func remove(_ id: UUID) {
        all.removeAll { $0.id == id }
        save()
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(all), forKey: Keys.highlights)
        defaults.set(try? JSONEncoder().encode(prayerNotes), forKey: Keys.prayerNotes)
        NotificationCenter.default.post(name: .highlightsDidChange, object: self)
    }

    private enum Keys {
        static let highlights = "highlights"
        static let prayerNotes = "prayerNotes"
        static let lastHighlightColor = "lastHighlightColor"
        static let lastUnderlineColor = "lastUnderlineColor"
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
