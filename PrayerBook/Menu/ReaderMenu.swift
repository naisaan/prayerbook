import SwiftUI

/// The round glass button in the bottom corner. Shows a red bookmark when the prayer is saved.
struct MenuButton: View {
    let isOpen: Bool
    let isBookmarked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isOpen ? "xmark" : "line.3.horizontal")
                .font(.system(size: 19, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 52, height: 52)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .glassEffect(.regular.interactive(), in: .circle)
        .overlay(alignment: .topTrailing) {
            if isBookmarked && !isOpen {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(.red, in: .circle)
                    .offset(x: 4, y: -4)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .accessibilityLabel(isOpen ? "Close menu" : "Menu")
    }
}

/// The stack of glass buttons that grows out of the menu button, like Apple Books.
struct ReaderMenu: View {
    let progress: Int
    let bookmarkCount: Int
    let isBookmarked: Bool
    let shareText: String
    let onSelect: (ReaderSheet) -> Void
    let onToggleBookmark: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            VStack(alignment: .trailing, spacing: 8) {
                MenuRow(title: "Contents · \(progress)%", systemImage: "list.bullet") {
                    onSelect(.contents)
                }
                MenuRow(title: "Bookmarks & Recents", systemImage: "bookmark", detail: bookmarkCount > 0 ? "\(bookmarkCount)" : nil) {
                    onSelect(.bookmarks)
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
                    ShareLink(item: shareText) {
                        CircleIcon(systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PressableButtonStyle())
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel("Share prayer")

                    Button { onSelect(.about) } label: {
                        CircleIcon(systemImage: "info")
                    }
                    .buttonStyle(PressableButtonStyle())
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel("About")

                    Button(action: onToggleBookmark) {
                        CircleIcon(systemImage: isBookmarked ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(isBookmarked ? Color.white : Color.primary)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .glassEffect(isBookmarked ? Glass.regular.tint(.red).interactive() : Glass.regular.interactive(), in: .circle)
                    .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Bookmark this prayer")
                }
            }
        }
    }
}

private struct MenuRow: View {
    let title: String
    let systemImage: String
    var detail: String? = nil
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
            .contentShape(.capsule)
        }
        .buttonStyle(PressableButtonStyle())
        .foregroundStyle(.primary)
        .glassEffect(.regular.interactive(), in: .capsule)
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
