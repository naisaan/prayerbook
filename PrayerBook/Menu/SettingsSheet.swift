import SwiftUI

/// Themes & Settings: text size, light or dark, the font, the drop cap, and the menu style.
struct SettingsSheet: View {
    @Environment(ReaderSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings

        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(.circle)
                }
                .buttonStyle(PressableButtonStyle())
                .menuSurface(.circle)
                .accessibilityLabel("Close")

                Text("Themes & Settings")
                    .font(.title3.weight(.semibold))
            }

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
                Label("Drop Cap", systemImage: "textformat.size.larger")
            }
            .padding(.horizontal, 20)
            .frame(height: 52)
            .menuSurface(.capsule, interactive: false)

            Toggle(isOn: $settings.liquidGlassMenus) {
                Label("Liquid Glass", systemImage: "drop")
            }
            .padding(.horizontal, 20)
            .frame(height: 52)
            .menuSurface(.capsule, interactive: false)
        }
        .foregroundStyle(.primary)
        .padding(24)
        .presentationDetents([.medium])
        .sensoryFeedback(.selection, trigger: settings.font)
        .sensoryFeedback(.selection, trigger: settings.appearance)
        .sensoryFeedback(.selection, trigger: settings.textSizeIndex)
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
