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
    @State private var openings = 0
    /// Picked up by pressing and holding, ready to drag.
    @State private var isLifted = false
    /// The list is longer than the note, so dragging on it scrolls it instead.
    @State private var listOverflows = false
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
            // When the keyboard comes up, it rises with it, just enough to clear it.
            let middle = proxy.size.height / 2
            let aboveKeyboard = max(safeAreaTop + 16 + side / 2, min(middle, proxy.size.height - keyboardSpace - 14 - side / 2))
            let openCenter = CGPoint(x: proxy.size.width / 2, y: keyboardSpace > 0 ? aboveKeyboard : middle)

            ZStack {
                // Tapping beside the note puts it back.
                Color.black
                    .opacity(isOpen ? 0.3 : 0)
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .allowsHitTesting(isOpen)

                note(side: side)
                    .scaleEffect(isOpen ? (isLifted ? 1.03 : 1) : Self.cardSize / side)
                    .rotationEffect(isOpen ? tilt : Self.cardTilt)
                    .position(isOpen ? openCenter : closedCenter)
                    .offset(drag)
                    // For the first keyboard after launch, before iOS says how tall it is.
                    .animation(.smooth(duration: 0.3), value: isTyping)
                    .opacity(isOpen ? 1 : (isHidden ? 0 : 1))
                    .allowsHitTesting(!isHidden)
                    .onTapGesture { if !isOpen { open() } }
                    // Drag anywhere on it, even on the text, to throw it around. It works
                    // alongside the text's own taps, so a tap on the text still starts typing.
                    // While typing, the note stays still.
                    .simultaneousGesture(flick(side: side), isEnabled: isOpen && !isTyping && !listOverflows)
                    // A list longer than the note scrolls when dragged, so then press and
                    // hold first to pick the note up.
                    .simultaneousGesture(holdAndFlick(side: side), isEnabled: isOpen && listOverflows && (!isTyping || isLifted))
            }
        }
        .ignoresSafeArea()
        // Follow the keyboard with its own timing, so the note moves with it smoothly.
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notice in
            let frame = notice.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            followKeyboard(height: frame?.height ?? Self.usualKeyboardHeight, notice: notice)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notice in
            guard let frame = notice.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                  let window = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first
            else { return }
            followKeyboard(height: max(0, window.bounds.height - frame.minY), notice: notice)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { notice in
            followKeyboard(height: 0, notice: notice)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: isOpen)
        .sensoryFeedback(.impact(weight: .medium), trigger: isLifted) { _, lifted in lifted }
    }

    // MARK: The keyboard

    /// Roughly how tall the keyboard is with its suggestions, for when iOS hasn't said yet,
    /// like the first time it comes up after launch.
    private static let usualKeyboardHeight: CGFloat = 340

    /// The room the note leaves for the keyboard.
    private var keyboardSpace: CGFloat {
        if keyboardHeight > 0 { return keyboardHeight }
        return isTyping ? Self.usualKeyboardHeight : 0
    }

    private func followKeyboard(height: CGFloat, notice: Notification) {
        let duration = notice.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        guard height != keyboardHeight else { return }
        withAnimation(.smooth(duration: max(duration, 0.2))) { keyboardHeight = height }
    }

    // MARK: The list bar

    private static let noteCornerRadius: CGFloat = 28
    /// The list bar sits in the note's bottom corner, this far in.
    private static let barInset: CGFloat = 10

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
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private func note(side: CGFloat) -> some View {
        // While it's a card, everything is scaled down, so the corners and shadow are scaled up.
        let cardScale: CGFloat = side / Self.cardSize
        let cornerRadius: CGFloat = isOpen ? Self.noteCornerRadius : side * 0.225
        let shadowRadius: CGFloat = isOpen ? 24 : 6 * cardScale
        let shadowY: CGFloat = isOpen ? 8 : 3 * cardScale
        let shadowOpacity: Double = isOpen ? 0.25 : 0.35

        return noteContent
            .padding(20)
            // While typing, the list buttons sit in the note's bottom corner.
            .overlay(alignment: .bottomLeading) {
                if isTyping {
                    listBar
                        .padding(Self.barInset)
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottomLeading)))
                }
            }
            .animation(.smooth(duration: 0.25), value: isTyping)
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
            HStack(alignment: .center) {
                Text("Prayer List")
                    .font(settings.font.font(size: 28).weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    // Tapping the heading puts the keyboard away.
                    .onTapGesture { isTyping = false }
                if isTyping {
                    // Done: puts the keyboard away, to read the list.
                    // Apple's round glass button, like the close buttons on its sheets.
                    Button { isTyping = false } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
                    .accessibilityLabel("Done")
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .frame(height: 44)
            PrayerListEditor(
                text: Bindable(list).text,
                isTyping: $isTyping,
                command: $listCommand,
                currentStyle: $currentListStyle,
                overflows: $listOverflows,
                font: settings.font.font(size: 18)
            )
            // A fresh editor each time the list opens, so it opens for reading, never
            // picking up the typing where it was left.
            .id(openings)
            // Once the note is picked up, the text lets go of the touch.
            .allowsHitTesting(!isLifted)
        }
    }

    // MARK: Opening and closing

    private func open() {
        isTyping = false
        openings += 1
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
            .onChanged { dragChanged($0, side: side) }
            .onEnded { dragEnded($0, side: side) }
    }

    /// Press and hold anywhere on the note, even on the text, to pick it up; then drag it
    /// around and flick it home. A quick tap on the text still starts typing.
    private func holdAndFlick(side: CGFloat) -> some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard case .second(true, let drag) = value else { return }
                if !isLifted {
                    withAnimation(.spring(duration: 0.25, bounce: 0.3)) { isLifted = true }
                }
                if let drag { dragChanged(drag, side: side) }
            }
            .onEnded { value in
                withAnimation(.spring(duration: 0.25)) { isLifted = false }
                if case .second(true, let drag?) = value {
                    dragEnded(drag, side: side)
                }
            }
    }

    private func dragChanged(_ value: DragGesture.Value, side: CGFloat) {
        isTyping = false
        drag = value.translation
        // Held above the middle, it turns with the drag; held below, against it.
        let grabbedAbove = value.startLocation.y < side / 2
        tilt = .degrees(value.translation.width / 14 * (grabbedAbove ? 1 : -1))
    }

    private func dragEnded(_ value: DragGesture.Value, side: CGFloat) {
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
