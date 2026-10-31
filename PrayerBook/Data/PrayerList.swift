import Foundation
import Observation

/// The reader's prayer list: free text, saved on the device as it's typed.
@Observable
final class PrayerList {
    static let shared = PrayerList()

    private let defaults = UserDefaults.standard
    private static let key = "prayerListText"

    var text: String {
        didSet { defaults.set(text, forKey: Self.key) }
    }

    private init() {
        text = defaults.string(forKey: Self.key) ?? ""
    }
}
