import Foundation
import Observation

/// Someone or something the reader wants to pray for.
struct PrayerIntention: Identifiable, Codable, Hashable {
    let id: UUID
    var text: String
    let created: Date
}

/// The reader's prayer list, saved on the device.
@Observable
final class PrayerList {
    static let shared = PrayerList()

    private let defaults = UserDefaults.standard
    private static let key = "prayerList"

    /// In the order the reader keeps them.
    private(set) var intentions: [PrayerIntention]

    private init() {
        intentions = defaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode([PrayerIntention].self, from: $0) } ?? []
    }

    func add(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        intentions.append(PrayerIntention(id: UUID(), text: trimmed, created: .now))
        save()
    }

    func remove(atOffsets offsets: IndexSet) {
        intentions.remove(atOffsets: offsets)
        save()
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        intentions.move(fromOffsets: source, toOffset: destination)
        save()
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(intentions), forKey: Self.key)
    }
}
