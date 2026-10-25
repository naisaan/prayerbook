import SwiftUI
import UIKit

/// The three reading fonts. All of them come with iOS.
enum ReaderFont: String, CaseIterable, Identifiable {
    case sanFrancisco, newYork, helvetica

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sanFrancisco: "San Francisco"
        case .newYork: "New York"
        case .helvetica: "Helvetica"
        }
    }

    func uiFont(size: CGFloat, weight: UIFont.Weight = .regular, italic: Bool = false) -> UIFont {
        var font: UIFont
        switch self {
        case .sanFrancisco:
            font = .systemFont(ofSize: size, weight: weight)
        case .newYork:
            let system = UIFont.systemFont(ofSize: size, weight: weight)
            font = system.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: size) } ?? system
        case .helvetica:
            let name = weight >= .semibold ? "Helvetica-Bold" : "Helvetica"
            font = UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight)
        }
        if italic,
           let descriptor = font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.union(.traitItalic)) {
            font = UIFont(descriptor: descriptor, size: size)
        }
        return font
    }

    func font(size: CGFloat) -> Font {
        Font(uiFont(size: size) as CTFont)
    }
}

/// Everything that changes how the text is laid out. When any of it changes, the book is
/// paginated again.
struct Typography: Equatable {
    var font: ReaderFont
    var size: CGFloat
    var dropCap: Bool

    /// Pure black in light mode, pure white in dark mode.
    static let textColor = UIColor { traits in
        traits.userInterfaceStyle == .dark ? .white : .black
    }
    static let secondaryColor = UIColor.secondaryLabel

    /// Pure white in light mode, pure black in dark mode.
    static let pageColor = UIColor { traits in
        traits.userInterfaceStyle == .dark ? .black : .white
    }

    var bodyFont: UIFont { font.uiFont(size: size) }

    /// Every body line is exactly this tall, so pages and the drop cap line up perfectly.
    var lineHeight: CGFloat { (bodyFont.lineHeight * 1.3).rounded() }
}
