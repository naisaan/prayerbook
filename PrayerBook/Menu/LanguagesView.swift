import SwiftUI

/// Turn languages on or off, like the original app. Each language adds its own sections.
struct LanguagesView: View {
    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Language.all) { language in
                        Toggle(isOn: binding(for: language)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(language.name)
                                if language.name != language.englishName {
                                    Text(language.englishName)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        // Keep at least one language on.
                        .disabled(library.isEnabled(language) && library.enabledLanguageCodes.count == 1)
                    }
                } footer: {
                    Text("The book shows prayers in every language that's turned on, each with its own sections.")
                }
            }
            .navigationTitle("Languages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton { dismiss() }
                }
            }
        }
    }

    private func binding(for language: Language) -> Binding<Bool> {
        Binding(
            get: { library.isEnabled(language) },
            set: { library.setLanguage(language, enabled: $0) }
        )
    }
}
