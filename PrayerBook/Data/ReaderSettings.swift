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
        case .system: String(localized: "Automatic")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
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

/// The reader's choices: appearance, font, text size, drop cap, menu style, and where they stopped reading.
/// Everything is saved so it is the same next time the app opens.
@Observable
final class ReaderSettings {
    private let defaults = UserDefaults.standard

    /// The smallest and largest text sizes, in points. The size moves in 1 point steps
    /// with the buttons, and smoothly with a pinch.
    static let textSizeRange: ClosedRange<CGFloat> = 12...40

    var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    var font: ReaderFont {
        didSet { defaults.set(font.rawValue, forKey: Keys.font) }
    }

    var textSize: CGFloat {
        didSet { defaults.set(Double(textSize), forKey: Keys.textSizePoints) }
    }

    var dropCap: Bool {
        didSet { defaults.set(dropCap, forKey: Keys.dropCap) }
    }

    /// Lines end where the words end instead of running edge to edge. Off by default; it
    /// turns on with Greenlandic and off without it.
    var naturalAlignment: Bool {
        didSet { defaults.set(naturalAlignment, forKey: Keys.naturalAlignment) }
    }

    /// The blue prayer list card in the page's corner. Turning it off only hides it; the list stays saved.
    var showsPrayerList: Bool {
        didSet { defaults.set(showsPrayerList, forKey: Keys.showsPrayerList) }
    }

    /// The menu button stays on screen all the time. Off, it comes and goes with a tap, like
    /// the page count.
    var alwaysShowsMenu: Bool {
        didSet { defaults.set(alwaysShowsMenu, forKey: Keys.alwaysShowsMenu) }
    }

    /// Liquid Glass menus instead of the solid ones. Off by default, since solid is easier to read.
    var liquidGlassMenus: Bool {
        didSet { defaults.set(liquidGlassMenus, forKey: Keys.liquidGlassMenus) }
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
        if let points = defaults.object(forKey: Keys.textSizePoints) as? Double {
            textSize = CGFloat(points)
        } else {
            // Earlier versions saved a position in a short list of sizes.
            let oldSizes: [CGFloat] = [14, 15, 16, 17, 18, 19, 20, 22, 24, 26, 28, 32]
            let index = defaults.object(forKey: Keys.textSize) as? Int ?? 5
            textSize = oldSizes[min(max(index, 0), oldSizes.count - 1)]
        }
        dropCap = defaults.object(forKey: Keys.dropCap) as? Bool ?? true
        liquidGlassMenus = defaults.bool(forKey: Keys.liquidGlassMenus)
        naturalAlignment = defaults.bool(forKey: Keys.naturalAlignment)
        showsPrayerList = defaults.object(forKey: Keys.showsPrayerList) as? Bool ?? true
        alwaysShowsMenu = defaults.object(forKey: Keys.alwaysShowsMenu) as? Bool ?? true
        lastPrayerID = defaults.object(forKey: Keys.lastPrayer) as? Int
        lastCharacterIndex = defaults.integer(forKey: Keys.lastCharacter)
    }

    var canDecreaseTextSize: Bool { textSize > Self.textSizeRange.lowerBound }
    var canIncreaseTextSize: Bool { textSize < Self.textSizeRange.upperBound }

    func decreaseTextSize() {
        setTextSize(textSize.rounded() - 1)
    }

    func increaseTextSize() {
        setTextSize(textSize.rounded() + 1)
    }

    /// Sets the text size, kept inside the allowed range and rounded to half a point.
    func setTextSize(_ size: CGFloat) {
        let clamped = min(max(size, Self.textSizeRange.lowerBound), Self.textSizeRange.upperBound)
        let rounded = (clamped * 2).rounded() / 2
        if rounded != textSize { textSize = rounded }
    }

    var typography: Typography {
        let size = min(max(textSize, Self.textSizeRange.lowerBound), Self.textSizeRange.upperBound)
        return Typography(font: font, size: size, dropCap: dropCap, justified: !naturalAlignment)
    }

    private enum Keys {
        static let appearance = "appearance"
        static let font = "font"
        static let textSize = "textSize"
        static let textSizePoints = "textSizePoints"
        static let dropCap = "dropCap"
        static let liquidGlassMenus = "liquidGlassMenus"
        static let showsPrayerList = "showsPrayerList"
        static let naturalAlignment = "naturalAlignment"
        static let alwaysShowsMenu = "alwaysShowsMenu"
        static let lastPrayer = "lastPrayer"
        static let lastCharacter = "lastCharacter"
    }
}
