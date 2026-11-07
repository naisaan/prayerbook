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

    /// Every language in the database. English comes first because it is the default; the rest
    /// are in order of their English names.
    static let all: [Language] = [
        english,
        Language(code: "ar", name: "العربية", englishName: "Arabic", isRightToLeft: true),
        Language(code: "bi", name: "Bislama", englishName: "Bislama (Vanuatu)", isRightToLeft: false),
        Language(code: "ny", name: "Chichewa", englishName: "Chichewa", isRightToLeft: false),
        Language(code: "zh-Hans", name: "简体中文", englishName: "Chinese (Simplified)", isRightToLeft: false),
        Language(code: "cs", name: "Čeština", englishName: "Czech", isRightToLeft: false),
        Language(code: "nl", name: "Nederlands", englishName: "Dutch", isRightToLeft: false),
        Language(code: "fj", name: "Vakaviti", englishName: "Fijian", isRightToLeft: false),
        Language(code: "fil", name: "Filipino", englishName: "Filipino", isRightToLeft: false),
        Language(code: "fr", name: "Français", englishName: "French", isRightToLeft: false),
        Language(code: "de", name: "Deutsch", englishName: "German", isRightToLeft: false),
        Language(code: "kl", name: "Kalaallisut", englishName: "Greenlandic", isRightToLeft: false),
        Language(code: "gu", name: "ગુજરાતી", englishName: "Gujarati", isRightToLeft: false),
        Language(code: "ht", name: "Kreyol Ayisyen", englishName: "Haitian Creole", isRightToLeft: false),
        Language(code: "hi", name: "हिंदी", englishName: "Hindi", isRightToLeft: false),
        Language(code: "is", name: "Íslenska", englishName: "Icelandic", isRightToLeft: false),
        Language(code: "id", name: "Bahasa Indonesia", englishName: "Indonesian", isRightToLeft: false),
        Language(code: "it", name: "Italiano", englishName: "Italian", isRightToLeft: false),
        Language(code: "ik", name: "Iñupiaq", englishName: "Iñupiaq", isRightToLeft: false),
        Language(code: "ja", name: "日本語", englishName: "Japanese", isRightToLeft: false),
        Language(code: "kn", name: "ಕನ್ನಡ", englishName: "Kannada", isRightToLeft: false),
        Language(code: "gil", name: "Kiribati", englishName: "Kiribati", isRightToLeft: false),
        Language(code: "ko", name: "한국어", englishName: "Korean", isRightToLeft: false),
        Language(code: "ml", name: "മലയാളം", englishName: "Malayalam", isRightToLeft: false),
        Language(code: "mr", name: "मराठी", englishName: "Marathi", isRightToLeft: false),
        Language(code: "mh", name: "Marshallese", englishName: "Marshallese", isRightToLeft: false),
        Language(code: "mi", name: "Māori", englishName: "Māori", isRightToLeft: false),
        Language(code: "ne", name: "नेपाली", englishName: "Nepali", isRightToLeft: false),
        Language(code: "or", name: "ଓଡ଼ିଆ", englishName: "Odia", isRightToLeft: false),
        Language(code: "fa", name: "فارسی", englishName: "Persian", isRightToLeft: true),
        Language(code: "pt-BR", name: "Português (BR)", englishName: "Portuguese (Brazil)", isRightToLeft: false),
        Language(code: "ru", name: "Русский", englishName: "Russian", isRightToLeft: false),
        Language(code: "sm", name: "Samoan", englishName: "Samoan", isRightToLeft: false),
        Language(code: "sk", name: "Slovenčina", englishName: "Slovak", isRightToLeft: false),
        Language(code: "es", name: "Español", englishName: "Spanish", isRightToLeft: false),
        Language(code: "sw", name: "Kiswahili", englishName: "Swahili", isRightToLeft: false),
        Language(code: "ta", name: "தமிழ்", englishName: "Tamil", isRightToLeft: false),
        Language(code: "te", name: "తెలుగు", englishName: "Telugu", isRightToLeft: false),
        Language(code: "tpi", name: "Tok Pisin", englishName: "Tok Pisin", isRightToLeft: false),
        Language(code: "to", name: "Tongan", englishName: "Tongan", isRightToLeft: false),
        Language(code: "tr", name: "Türkçe", englishName: "Turkish", isRightToLeft: false),
        Language(code: "ur", name: "اُردُو", englishName: "Urdu", isRightToLeft: true),
        Language(code: "vi", name: "Tiếng Việt", englishName: "Vietnamese", isRightToLeft: false),
    ]

    static func with(code: String) -> Language? {
        all.first { $0.code == code }
    }
}
