import SwiftUI

/// Themes & Settings: text size, light or dark, the font, the drop cap, the menu style, and
/// the ways to General Settings (the prayer list and the menu button) and About.
struct SettingsSheet: View {
    /// How much of the book has been read, in percent, for Super Secret Settings.
    let progress: Int

    @Environment(ReaderSettings.self) private var settings
    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var showsAbout = false
    @State private var confirmingReset = false

    /// The pages of the sheet. Each one after the first opens from a row on the one before.
    private enum Page: Int {
        case main, general, secret
    }

    /// The page showing; the others slide in and out in its place.
    @State private var page = Page.main
    /// Which way the pages slide, set when moving between them.
    @State private var goingDeeper = true
    /// The sheet is exactly as tall as what's in it.
    @State private var contentHeight: CGFloat = 520
    /// How tall the main page is, so General Settings can be just as tall.
    @State private var mainHeight: CGFloat = 400

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            switch page {
            case .main:
                mainSettings
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { mainHeight = $0 }
                    .transition(pageTransition)
            case .general:
                generalSettings
                    .transition(pageTransition)
            case .secret:
                secretSettings
                    .transition(pageTransition)
            }
        }
        .foregroundStyle(.primary)
        .padding(24)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        .presentationDetents([.height(contentHeight)])
        .animation(.smooth(duration: 0.3), value: page)
        .confirmationDialog("Start reading progress over?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Start Over", role: .destructive) { library.resetProgress() }
        } message: {
            Text("Your bookmarks and recent prayers are kept.")
        }
        .sheet(isPresented: $showsAbout) {
            AboutView()
        }
        .sensoryFeedback(.selection, trigger: settings.font)
        .sensoryFeedback(.selection, trigger: settings.appearance)
        .sensoryFeedback(.selection, trigger: settings.textSize)
    }

    /// Slides in from the side when going deeper, and back the other way.
    private var pageTransition: AnyTransition {
        .asymmetric(
            insertion: .push(from: goingDeeper ? .trailing : .leading),
            removal: .push(from: goingDeeper ? .trailing : .leading)
        )
    }

    private func go(to newPage: Page) {
        // The direction is set first, so the page leaving slides the right way too.
        goingDeeper = newPage.rawValue > page.rawValue
        Task { @MainActor in page = newPage }
    }

    private var title: LocalizedStringKey {
        switch page {
        case .main: "Themes & Settings"
        case .general: "General Settings"
        case .secret: "Super Secret Settings"
        }
    }

    /// Close, or back a page, then the title.
    private var header: some View {
        HStack(spacing: 14) {
            Button {
                switch page {
                case .main: dismiss()
                case .general: go(to: .main)
                case .secret: go(to: .general)
                }
            } label: {
                Image(systemName: page == .main ? "xmark" : "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(.circle)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(PressableButtonStyle())
            .menuSurface(.circle)
            .accessibilityLabel(page == .main ? "Close" : "Back")

            Text(title)
                .font(.title3.weight(.semibold))
                .contentTransition(.opacity)
        }
    }

    private var mainSettings: some View {
        @Bindable var settings = settings
        return VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                textSizeControl
                appearanceControl
            }

            HStack(spacing: 12) {
                ForEach(ReaderFont.allCases) { font in
                    FontTile(font: font, isSelected: settings.font == font) {
                        settings.font = font
                    }
                }
            }

            Toggle(isOn: $settings.dropCap) {
                Label { Text("Drop Cap") } icon: { DropCapIcon() }
            }
            .padding(.horizontal, 20)
            .frame(height: 52)
            .menuSurface(.capsule, interactive: false)
            toggleRow("Liquid Glass", systemImage: "drop", isOn: $settings.liquidGlassMenus)
            linkRow("General", systemImage: "gearshape") { go(to: .general) }
            linkRow("About", systemImage: "info.circle") { showsAbout = true }
        }
    }

    private var generalSettings: some View {
        @Bindable var settings = settings
        // As tall as the main page, so the sheet doesn't change height, and scrolls if more
        // settings are added than fit.
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                toggleRow("Prayer List", systemImage: "checklist", isOn: $settings.showsPrayerList)
                toggleRow("Always Show Menu", systemImage: "line.3.horizontal.circle", isOn: $settings.alwaysShowsMenu)
                toggleRow("Natural Alignment", systemImage: "text.alignleft", isOn: $settings.naturalAlignment)
                linkRow("Super Secret Settings", systemImage: "lock") { go(to: .secret) }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollClipDisabled()
        .frame(height: mainHeight, alignment: .top)
    }

    /// Reading progress, moved here from Contents, with a way to start over.
    private var secretSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("\(progress)% read")
                        Spacer()
                        if progress > 0 {
                            Button("Start Over") { confirmingReset = true }
                                .buttonStyle(.borderless)
                        }
                    }
                    ProgressView(value: Double(progress), total: 100)
                }
                .padding(20)
                .menuSurface(.rect(cornerRadius: 26), interactive: false)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollClipDisabled()
        .frame(height: mainHeight, alignment: .top)
    }

    private func toggleRow(_ title: LocalizedStringKey, systemImage: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label(title, systemImage: systemImage)
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
        .menuSurface(.capsule, interactive: false)
    }

    /// A row that opens another page, with a chevron.
    private func linkRow(_ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .frame(height: 52)
            .contentShape(.capsule)
        }
        .buttonStyle(PressableButtonStyle())
        .menuSurface(.capsule)
    }

    private var textSizeControl: some View {
        HStack(spacing: 0) {
            Button { settings.decreaseTextSize() } label: {
                Text("A")
                    .font(.system(size: 15, weight: .medium))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .contentShape(.rect)
            }
            .disabled(!settings.canDecreaseTextSize)
            .accessibilityLabel("Smaller text")

            Divider()
                .frame(height: 26)

            Button { settings.increaseTextSize() } label: {
                Text("A")
                    .font(.system(size: 23, weight: .medium))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .contentShape(.rect)
            }
            .disabled(!settings.canIncreaseTextSize)
            .accessibilityLabel("Larger text")
        }
        // Holding a button keeps changing the size, a point at a time.
        .buttonRepeatBehavior(.enabled)
        .buttonStyle(PressableButtonStyle())
        .menuSurface(.capsule)
    }

    private var appearanceControl: some View {
        HStack(spacing: 0) {
            ForEach(Appearance.allCases) { appearance in
                Button { settings.appearance = appearance } label: {
                    Image(systemName: appearance.systemImage)
                        .font(.system(size: 17, weight: settings.appearance == appearance ? .semibold : .regular))
                        .foregroundStyle(settings.appearance == appearance ? Color.primary : Color.secondary)
                        .frame(width: 44, height: 50)
                        .contentShape(.rect)
                }
                .accessibilityLabel(appearance.title)
                .accessibilityAddTraits(settings.appearance == appearance ? .isSelected : [])
            }
        }
        .padding(.horizontal, 6)
        .buttonStyle(PressableButtonStyle())
        .menuSurface(.capsule)
    }
}

/// A large "Aa" tile showing what a font looks like, like the theme tiles in Apple Books.
private struct FontTile: View {
    let font: ReaderFont
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("Aa")
                    .font(font.font(size: 32))
                Text(font.displayName)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .background(Color(uiColor: .tertiarySystemFill), in: .rect(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(isSelected ? Color.primary : Color.clear, lineWidth: 2.5)
            }
            .contentShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(PressableButtonStyle())
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .accessibilityLabel(font.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A big letter A with lines of text beside and below it, like the first letter of a prayer.
private struct DropCapIcon: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 2.5) {
            HStack(alignment: .top, spacing: 2.5) {
                Text(verbatim: "A")
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .fixedSize()
                    .frame(width: 10, height: 11)
                VStack(spacing: 2.5) {
                    line
                    line
                    line
                }
                .padding(.top, 0.5)
            }
            line
            line
        }
        .frame(width: 20)
        // The letter A inside would otherwise line up with the words beside it and push the
        // icon up. Line up the middle of the icon with the middle of the words instead, like
        // the other icons.
        .alignmentGuide(.firstTextBaseline) { $0.height / 2 + Self.halfCapHeight }
        .alignmentGuide(.lastTextBaseline) { $0.height / 2 + Self.halfCapHeight }
        .accessibilityHidden(true)
    }

    private static var halfCapHeight: CGFloat {
        UIFont.preferredFont(forTextStyle: .body).capHeight / 2
    }

    private var line: some View {
        Capsule()
            .frame(height: 1.6)
    }
}
