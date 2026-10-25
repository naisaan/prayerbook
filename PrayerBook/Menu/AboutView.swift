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
                        Text("Prayer Book")
                            .font(ReaderFont.newYork.font(size: 30).weight(.semibold))
                        Text("Version \(version)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }

                Section("Credits") {
                    Text("Based on the Prayer Book app by Arash Payan, which provides the prayers and their translations.")
                    Link("Original Prayer Book source code", destination: URL(string: "https://github.com/arashpayan/prayer-book")!)
                    Link("Prayer Book website", destination: URL(string: "https://www.prayerbook.app/")!)
                }

                Section("Sources") {
                    Text("All Bahá’í sacred writings copyright Bahá’í International Community.")
                    Link("Bahá’í Reference Library", destination: URL(string: "https://www.bahai.org/library/authoritative-texts/prayers/")!)
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
