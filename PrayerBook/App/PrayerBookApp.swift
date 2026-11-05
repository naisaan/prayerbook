import SwiftUI
import UIKit

@main
struct PrayerBookApp: App {
    @State private var library = Library()
    @State private var settings = ReaderSettings()

    var body: some Scene {
        WindowGroup {
            ReaderView()
                .environment(library)
                .environment(settings)
                // Once the window is on screen, then whenever it's changed in Themes & Settings.
                .task { apply(settings.appearance) }
                .onChange(of: settings.appearance) { _, appearance in
                    apply(appearance)
                }
        }
    }

    /// Sets light or dark on the app's windows, or hands it back to the phone's own setting for
    /// Automatic (the default). SwiftUI's preferredColorScheme can't go back to the phone's setting
    /// once it has been Light or Dark, so the window is told directly.
    private func apply(_ appearance: Appearance) {
        let style: UIUserInterfaceStyle = switch appearance {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows { window.overrideUserInterfaceStyle = style }
        }
    }
}
