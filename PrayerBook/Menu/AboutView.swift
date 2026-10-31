import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 6) {
                        Text("Bahá’í Prayer Book")
                            .font(.system(size: 30, weight: .bold))
                        Text("Version \(version)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }

                Section("Bahá’í Faith") {
                    Text("This app is an individual initiative. It is not an official publication of the Bahá’í Faith and is not endorsed by any Bahá’í institution.")
                    Link("Official Bahá’í Website", destination: URL(string: "https://www.bahai.org/")!)
                    Link("What do Bahá’ís Believe?", destination: URL(string: "https://www.bahai.org/beliefs")!)
                }

                Section("Credits") {
                    Text("This app was vibe-coded and made with Love by [Naisaan Nadimi](https://naisaannadimi.net)")
                }

                Section("Dedications") {
                    Text("I dedicate this app to my parents Bahman and Jalal, to the Triangle Bahá’í Community, and Torpignattara.")
                }

                Section("Sources") {
                    Text("All Bahá’í sacred writings copyright Bahá’í International Community.")
                    Link("Bahá’í Reference Library", destination: URL(string: "https://www.bahai.org/library/authoritative-texts/prayers/")!)
                }

                Section("Privacy Policy") {
                    Text("This app does not collect, store, or share any personal information. It has no accounts, ads, analytics, or tracking. Your bookmarks, reading progress, and settings are saved only on your device and are never sent anywhere.")
                    Link("Read the full Privacy Policy", destination: URL(string: "https://github.com/naisaan/prayerbook/blob/main/PRIVACY.md")!)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton { dismiss() }
                }
            }
        }
    }
}
