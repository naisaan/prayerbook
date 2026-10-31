import SwiftUI

/// The round menu button in the bottom corner, with Apple Books' icon:
/// two lines over three dots.
struct MenuButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            MenuGlyph()
                .frame(width: 52, height: 52)
                .contentShape(.circle)
        }
        .buttonStyle(PressableButtonStyle())
        .foregroundStyle(.primary)
        .menuSurface(.circle)
        .accessibilityLabel("Menu")
    }
}

/// Two short lines above three dots.
private struct MenuGlyph: View {
    var body: some View {
        VStack(spacing: 4) {
            Capsule().frame(width: 20, height: 2.5)
            Capsule().frame(width: 20, height: 2.5)
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().frame(width: 4, height: 4)
                }
            }
            .padding(.top, 1)
        }
    }
}

extension BookmarkColor {
    var color: Color {
        switch self {
        case .red: .red
        case .blue: .blue
        case .green: .green
        case .purple: .purple
        }
    }
}

/// The bookmark badge shown on bookmarked pages, in the color of the prayer's bookmark list.
struct BookmarkBadge: View {
    var size: CGFloat = 26
    var color: BookmarkColor = .red

    var body: some View {
        Image(systemName: "bookmark.fill")
            .font(.system(size: size * 0.46, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.color, in: .circle)
            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
            .accessibilityLabel("Bookmarked")
    }
}

/// The stack of buttons that grows out of the menu button, like Apple Books.
struct ReaderMenu: View {
    @Environment(Library.self) private var library

    let progress: Int
    let highlightCount: Int
    let isBookmarked: Bool
    /// Nil on a section title page, where there's no prayer to share or bookmark.
    let shareText: String?
    let onSelect: (ReaderSheet) -> Void
    let onToggleBookmark: (() -> Void)?
    /// Nil on a section title page, like `onToggleBookmark`.
    let currentPrayerID: Int?
    let onToggleList: (UUID) -> Void
    let onAddList: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            VStack(alignment: .trailing, spacing: 8) {
                MenuRow(title: "Contents · \(progress)%", systemImage: "list.bullet", progress: Double(progress) / 100) {
                    onSelect(.contents)
                }
                MenuRow(title: "Highlights & Notes", systemImage: "highlighter", detail: highlightCount > 0 ? "\(highlightCount)" : nil) {
                    onSelect(.highlights)
                }
                MenuRow(title: "Search Book", systemImage: "magnifyingglass") {
                    onSelect(.search)
                }
                MenuRow(title: "Themes & Settings", systemImage: "textformat.size") {
                    onSelect(.settings)
                }
                MenuRow(title: "Languages", systemImage: "globe") {
                    onSelect(.languages)
                }

                HStack(spacing: 8) {
                    // The + makes a new bookmark list. It stays on the outside, and each new
                    // list's button appears between it and the older ones.
                    if library.canAddBookmarkList {
                        Button(action: onAddList) {
                            CircleIcon(systemImage: "plus")
                        }
                        .buttonStyle(PressableButtonStyle())
                        .menuSurface(.circle)
                        .accessibilityLabel("New bookmark list")
                    }

                    if let onToggleBookmark, let currentPrayerID {
                        // Once there's more than one list, each button shows its color even when off.
                        let showsColors = !library.bookmarkLists.isEmpty
                        ForEach(Array(library.bookmarkLists.reversed())) { list in
                            BookmarkToggle(
                                color: list.color,
                                isOn: list.prayerIDs.contains(currentPrayerID),
                                showsColor: true,
                                name: list.name
                            ) { onToggleList(list.id) }
                        }
                        BookmarkToggle(color: .red, isOn: isBookmarked, showsColor: showsColors, name: String(localized: "Bookmarks"), action: onToggleBookmark)
                    }

                    if let shareText {
                        ShareLink(item: shareText) {
                            CircleIcon(systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(PressableButtonStyle())
                        .menuSurface(.circle)
                        .accessibilityLabel("Share prayer")
                    }
                }
            }
        }
    }
}

private struct MenuRow: View {
    @Environment(ReaderSettings.self) private var settings

    let title: LocalizedStringKey
    let systemImage: String
    var detail: String? = nil
    /// How much of the book is read, shown as a fill behind the row like Apple Books.
    var progress: Double? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer(minLength: 24)
                if let detail {
                    Text(detail)
                        .monospacedDigit()
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .medium))
                }
            }
            .font(.system(size: 17))
            .padding(.horizontal, 22)
            .frame(width: 290, height: 52)
            .background(alignment: .leading) {
                if let progress, !settings.liquidGlassMenus {
                    GeometryReader { proxy in
                        Rectangle()
                            .fill(Color.menuProgressFill)
                            .frame(width: proxy.size.width * min(max(progress, 0), 1))
                    }
                    .clipShape(.capsule)
                }
            }
            .contentShape(.capsule)
        }
        .buttonStyle(PressableButtonStyle())
        .foregroundStyle(.primary)
        .menuSurface(.capsule)
    }
}

/// A bookmark button for one list: filled with the list's color when the prayer is in it.
private struct BookmarkToggle: View {
    let color: BookmarkColor
    let isOn: Bool
    let showsColor: Bool
    let name: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CircleIcon(systemImage: isOn ? "bookmark.fill" : "bookmark")
                .foregroundStyle(isOn ? Color.white : showsColor ? color.color : Color.primary)
        }
        .buttonStyle(PressableButtonStyle())
        .menuSurface(.circle, tint: isOn ? color.color : nil)
        .accessibilityLabel(isOn ? Text("Remove from \(name)") : Text("Add to \(name)"))
    }
}

private struct CircleIcon: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 18, weight: .medium))
            .frame(width: 52, height: 52)
            .contentShape(.circle)
    }
}

/// Shrinks a little the moment it's pressed, so every tap feels answered right away.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// The look of the menu's buttons: solid gray like Apple Books, or Liquid Glass when that's
/// turned on in Themes & Settings.
private struct MenuSurface<S: Shape>: ViewModifier {
    @Environment(ReaderSettings.self) private var settings
    let shape: S
    let tint: Color?
    let interactive: Bool

    func body(content: Content) -> some View {
        if settings.liquidGlassMenus {
            content.glassEffect(glass, in: shape)
        } else {
            content
                .background(tint ?? Color.menuFill, in: shape)
                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        }
    }

    private var glass: Glass {
        let base = tint.map { Glass.regular.tint($0) } ?? Glass.regular
        return interactive ? base.interactive() : base
    }
}

extension View {
    func menuSurface<S: Shape>(_ shape: S, tint: Color? = nil, interactive: Bool = true) -> some View {
        modifier(MenuSurface(shape: shape, tint: tint, interactive: interactive))
    }
}

extension Color {
    /// The solid button color: light gray in light mode, dark gray in dark mode.
    static let menuFill = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 58 / 255, green: 58 / 255, blue: 60 / 255, alpha: 1)
            : UIColor(red: 229 / 255, green: 229 / 255, blue: 234 / 255, alpha: 1)
    })

    /// The read part of the Contents button, a shade apart from `menuFill`.
    static let menuProgressFill = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 84 / 255, green: 84 / 255, blue: 88 / 255, alpha: 1)
            : UIColor(red: 209 / 255, green: 209 / 255, blue: 214 / 255, alpha: 1)
    })
}
