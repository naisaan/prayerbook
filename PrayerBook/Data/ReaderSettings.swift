import SwiftUI
import Observation

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var title: String {
        switch self {
        case .system: "Automatic"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var systemImage: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }
}

/// The reader's choices: appearance, font, text size, drop cap, and where they stopped reading.
/// Everything is saved so it is the same next time the app opens.
@Observable
final class ReaderSettings {
    private let defaults = UserDefaults.standard

    /// Text sizes in points, from smallest to largest.
    static let sizes: [CGFloat] = [14, 15, 16, 17, 18, 19, 20, 22, 24, 26, 28, 32]

    var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    var font: ReaderFont {
        didSet { defaults.set(font.rawValue, forKey: Keys.font) }
    }

    var textSizeIndex: Int {
        didSet { defaults.set(textSizeIndex, forKey: Keys.textSize) }
    }

    var dropCap: Bool {
        didSet { defaults.set(dropCap, forKey: Keys.dropCap) }
    }

    /// The prayer on screen when the reader last turned a page.
    @ObservationIgnored var lastPrayerID: Int? {
        didSet { defaults.set(lastPrayerID, forKey: Keys.lastPrayer) }
    }

    /// How far into that prayer the page started, so we can return to the same page.
    @ObservationIgnored var lastCharacterIndex: Int {
        didSet { defaults.set(lastCharacterIndex, forKey: Keys.lastCharacter) }
    }

    init() {
        let defaults = UserDefaults.standard
        appearance = defaults.string(forKey: Keys.appearance).flatMap { Appearance(rawValue: $0) } ?? .system
        font = defaults.string(forKey: Keys.font).flatMap { ReaderFont(rawValue: $0) } ?? .newYork
        textSizeIndex = defaults.object(forKey: Keys.textSize) as? Int ?? 5
        dropCap = defaults.object(forKey: Keys.dropCap) as? Bool ?? true
        lastPrayerID = defaults.object(forKey: Keys.lastPrayer) as? Int
        lastCharacterIndex = defaults.integer(forKey: Keys.lastCharacter)
    }

    var canDecreaseTextSize: Bool { textSizeIndex > 0 }
    var canIncreaseTextSize: Bool { textSizeIndex < Self.sizes.count - 1 }

    func decreaseTextSize() {
        if canDecreaseTextSize { textSizeIndex -= 1 }
    }

    func increaseTextSize() {
        if canIncreaseTextSize { textSizeIndex += 1 }
    }

    var typography: Typography {
        let index = min(max(textSizeIndex, 0), Self.sizes.count - 1)
        return Typography(font: font, size: Self.sizes[index], dropCap: dropCap)
    }

    private enum Keys {
        static let appearance = "appearance"
        static let font = "font"
        static let textSize = "textSize"
        static let dropCap = "dropCap"
        static let lastPrayer = "lastPrayer"
        static let lastCharacter = "lastCharacter"
    }
}
