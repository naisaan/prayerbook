import SwiftUI

/// The prayer list: a blue card shaped like an app icon, tilted and peeking in from the top
/// corner of the page. Tapping it grows it into a square note hovering in the middle of the screen,
/// where the reader writes whatever they like. Tapping beside the note, or flicking it like
/// Tweetbot's image viewer, sends it back into its corner. It's separate from the notes on
/// highlights.
///
/// The card and the note are one view: it's scaled, turned and moved between the two with
/// Apple's springs, so the text inside never has to be laid out again mid-animation.
struct PrayerListNote: View {
    @Binding var isOpen: Bool
    /// Hidden while the reader menu is open.
    let isHidden: Bool
    let safeAreaTop: CGFloat

    @State private var drag: CGSize = .zero
    @State private var tilt: Angle = .zero
    @State private var isTyping = false
    @State private var listCommand: PrayerListStyle?
    @State private var currentListStyle: PrayerListStyle?
    /// How much of the screen the keyboard covers, from the system's keyboard notices.
    @State private var keyboardHeight: CGFloat = 0
    @Environment(ReaderSettings.self) private var settings

    private var list: PrayerList { .shared }

    /// The size of the card in the corner.
    private static let cardSize: CGFloat = 64
    private static let cardTilt = Angle.degrees(-30)

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width - 40, 440)
            let closedCenter = CGPoint(x: proxy.size.width - Self.cardSize * 0.02, y: safeAreaTop + Self.cardSize * 0.3)
            // It opens in the exact middle of the screen, for a glance, without the keyboard.
            // When the keyboard comes up, it rises with it, just enough to clear the keyboard
            // and the list bar.
            let middle = proxy.size.height / 2
            let barTop = proxy.size.height - keyboardHeight - Self.barGap - Self.barHeight
            let aboveKeyboard = max(safeAreaTop + 16 + side / 2, min(middle, barTop - 12 - side / 2))
            let openCenter = CGPoint(x: proxy.size.width / 2, y: keyboardHeight > 0 ? aboveKeyboard : middle)

            ZStack {
                // Tapping beside the note puts it back.
                Color.black
                    .opacity(isOpen ? 0.3 : 0)
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .allowsHitTesting(isOpen)

                note(side: side)
                    .scaleEffect(isOpen ? 1 : Self.cardSize / side)
                    .rotationEffect(isOpen ? tilt : Self.cardTilt)
                    .position(isOpen ? openCenter : closedCenter)
                    .offset(drag)
                    .opacity(isOpen ? 1 : (isHidden ? 0 : 1))
                    .allowsHitTesting(!isHidden)
                    .onTapGesture { if !isOpen { open() } }
                    .gesture(flick(side: side), isEnabled: isOpen)

                if isOpen && isTyping && keyboardHeight > 0 {
                    listBar
                        .position(x: 16 + Self.barWidth / 2, y: barTop + Self.barHeight / 2)
                        .transition(.opacity)
                }
            }
        }
        .ignoresSafeArea()
        // Follow the keyboard with its own timing, so the note and bar move with it smoothly.
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notice in
            guard let info = notice.userInfo,
                  let frame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                  let screen = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen
            else { return }
            let height = max(0, screen.bounds.height - frame.minY)
            let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
            withAnimation(.smooth(duration: max(duration, 0.2))) { keyboardHeight = height }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: isOpen)
    }

    // MARK: The list bar

    private static let barHeight: CGFloat = 52
    private static let barWidth: CGFloat = 3 * 52 + 12
    /// The room between the list bar and the keyboard.
    private static let barGap: CGFloat = 14

    /// The list buttons, floating on glass just above the keyboard.
    private var listBar: some View {
        HStack(spacing: 0) {
            ForEach(PrayerListStyle.allCases, id: \.self) { style in
                Button {
                    listCommand = style
                } label: {
                    Image(systemName: style.systemImage)
                        .font(.system(size: 19, weight: .medium))
                        .frame(width: 52, height: 40)
                        .background {
                            if currentListStyle == style {
                                Capsule().fill(.primary.opacity(0.12))
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(style.name)
                .accessibilityAddTraits(currentListStyle == style ? .isSelected : [])
            }
        }
        .padding(6)
        .frame(width: Self.barWidth, height: Self.barHeight)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private func note(side: CGFloat) -> some View {
        // While it's a card, everything is scaled down, so the corners and shadow are scaled up.
        let cardScale: CGFloat = side / Self.cardSize
        let cornerRadius: CGFloat = isOpen ? 28 : side * 0.225
        let shadowRadius: CGFloat = isOpen ? 24 : 6 * cardScale
        let shadowY: CGFloat = isOpen ? 8 : 3 * cardScale
        let shadowOpacity: Double = isOpen ? 0.25 : 0.35

        return noteContent
            .padding(20)
            .opacity(isOpen ? 1 : 0)
            // While it's a card, a tap opens it instead of starting to type.
            .allowsHitTesting(isOpen)
            .frame(width: side, height: side)
            // Blue like the highlighter, card and note alike, with dark text in light and dark mode.
            .background(Color(uiColor: HighlightColor.blue.swatch))
            // Dark text on the blue in light and dark mode. The colors are set here rather
            // than by forcing light mode, so the keyboard still matches the phone.
            .foregroundStyle(.black)
            .tint(.black)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, y: shadowY)
    }

    private var noteContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // In the book's font, chosen in Themes & Settings.
            Text("Prayer List")
                .font(settings.font.font(size: 28).weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                // Tapping the heading puts the keyboard away.
                .onTapGesture { isTyping = false }
            PrayerListEditor(
                text: Bindable(list).text,
                isTyping: $isTyping,
                command: $listCommand,
                currentStyle: $currentListStyle,
                font: settings.font.font(size: 18)
            )
        }
    }

    // MARK: Opening and closing

    private func open() {
        withAnimation(.spring(duration: 0.5, bounce: 0.25)) {
            isOpen = true
        }
    }

    private func close() {
        isTyping = false
        withAnimation(.spring(duration: 0.45, bounce: 0.15)) {
            isOpen = false
            drag = .zero
            tilt = .zero
        }
    }

    /// Drag the note around, tilting it the way a card held at that spot would turn. Let go
    /// quickly and it flies back to its corner; let go slowly and it springs back into place.
    private func flick(side: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                isTyping = false
                drag = value.translation
                // Held above the middle, it turns with the drag; held below, against it.
                let grabbedAbove = value.startLocation.y < side / 2
                tilt = .degrees(value.translation.width / 14 * (grabbedAbove ? 1 : -1))
            }
            .onEnded { value in
                let velocity = value.velocity
                let speed = hypot(velocity.width, velocity.height)
                let distance = hypot(value.translation.width, value.translation.height)
                guard speed > 700 || distance > side * 0.6 else {
                    withAnimation(.spring(duration: 0.4, bounce: 0.3)) {
                        drag = .zero
                        tilt = .zero
                    }
                    return
                }
                // However it's thrown, it flies home to its corner and shrinks back into the card.
                isTyping = false
                withAnimation(.spring(duration: 0.5, bounce: 0.2)) {
                    isOpen = false
                    drag = .zero
                    tilt = .zero
                }
            }
    }
}
