import SwiftUI

/// Themes & Settings: text size, light or dark, the font, the drop cap, the menu style, and
/// the ways to General Settings (the prayer list and the menu button) and About.
struct SettingsSheet: View {
    @Environment(ReaderSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var showsAbout = false
    /// General Settings, shown in place of the main page.
    @State private var showsGeneral = false
    /// The sheet is exactly as tall as what's in it.
    @State private var contentHeight: CGFloat = 520

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            if showsGeneral {
                generalSettings
                    .transition(.push(from: .trailing))
            } else {
                mainSettings
                    .transition(.push(from: .leading))
            }
        }
        .foregroundStyle(.primary)
        .padding(24)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        .presentationDetents([.height(contentHeight)])
        .animation(.smooth(duration: 0.3), value: showsGeneral)
        .sheet(isPresented: $showsAbout) {
            AboutView()
        }
        .sensoryFeedback(.selection, trigger: settings.font)
        .sensoryFeedback(.selection, trigger: settings.appearance)
        .sensoryFeedback(.selection, trigger: settings.textSizeIndex)
    }

    /// Close, or back from General Settings, then the title.
    private var header: some View {
        HStack(spacing: 14) {
            Button {
                if showsGeneral { showsGeneral = false } else { dismiss() }
            } label: {
                Image(systemName: showsGeneral ? "chevron.left" : "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(.circle)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(PressableButtonStyle())
            .menuSurface(.circle)
            .accessibilityLabel(showsGeneral ? "Back" : "Close")

            Text(showsGeneral ? "General Settings" : "Themes & Settings")
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

            toggleRow("Drop Cap", systemImage: "textformat.size.larger", isOn: $settings.dropCap)
            toggleRow("Liquid Glass", systemImage: "drop", isOn: $settings.liquidGlassMenus)
            linkRow("General", systemImage: "gearshape") { showsGeneral = true }
            linkRow("About", systemImage: "info.circle") { showsAbout = true }
        }
    }

    private var generalSettings: some View {
        @Bindable var settings = settings
        return VStack(alignment: .leading, spacing: 20) {
            toggleRow("Prayer List", systemImage: "checklist", isOn: $settings.showsPrayerList)
            toggleRow("Always Show Menu", systemImage: "line.3.horizontal.circle", isOn: $settings.alwaysShowsMenu)
        }
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
