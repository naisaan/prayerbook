import SwiftUI

@main
struct PrayerBookApp: App {
    @State private var library = Library()
    @State private var settings = ReaderSettings()

    var body: some Scene {
        WindowGroup {
            ReaderView()
                .environment(library)
                .environment(settings)
                .preferredColorScheme(settings.appearance.colorScheme)
        }
    }
}
