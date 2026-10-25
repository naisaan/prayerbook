import Foundation

/// A language the prayers are available in. Matches the languages of the original app.
struct Language: Identifiable, Hashable {
    let code: String
    /// The language's name in its own language, such as "Deutsch".
    let name: String
    let englishName: String
    let isRightToLeft: Bool

    var id: String { code }

    static let english = Language(code: "en", name: "English", englishName: "English", isRightToLeft: false)

    /// Every language in the database. English comes first because it is the default.
    static let all: [Language] = [
        english,
        Language(code: "cs", name: "Čeština", englishName: "Czech", isRightToLeft: false),
        Language(code: "de", name: "Deutsch", englishName: "German", isRightToLeft: false),
        Language(code: "es", name: "Español", englishName: "Spanish", isRightToLeft: false),
        Language(code: "fr", name: "Français", englishName: "French", isRightToLeft: false),
        Language(code: "is", name: "Íslenska", englishName: "Icelandic", isRightToLeft: false),
        Language(code: "nl", name: "Nederlands", englishName: "Dutch", isRightToLeft: false),
        Language(code: "sk", name: "Slovenčina", englishName: "Slovak", isRightToLeft: false),
        Language(code: "fj", name: "Vakaviti", englishName: "Fijian", isRightToLeft: false),
        Language(code: "fa", name: "فارسی", englishName: "Persian", isRightToLeft: true),
    ]

    static func with(code: String) -> Language? {
        all.first { $0.code == code }
    }
}
