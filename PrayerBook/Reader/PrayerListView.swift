import SwiftUI

/// The prayer list: a card shaped like the app icon, tilted and peeking in from the top
/// corner of the page. Tapping it grows it into a square note hovering over the prayer,
/// where the reader writes whatever they like. Tapping beside the note puts it back in its
/// corner; flicking it, like Tweetbot's image viewer, throws it off the screen.
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
    @State private var cardOpacity = 1.0
    @FocusState private var isTyping: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var list: PrayerList { .shared }

    /// The size of the card in the corner.
    private static let cardSize: CGFloat = 64
    private static let cardTilt = Angle.degrees(-30)

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width - 40, 440)
            let closedCenter = CGPoint(x: proxy.size.width - Self.cardSize * 0.02, y: Self.cardSize * 0.95)
            let openCenter = CGPoint(x: proxy.size.width / 2, y: safeAreaTop + 24 + side / 2)

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
                    .opacity(isOpen ? 1 : (isHidden ? 0 : cardOpacity))
                    .allowsHitTesting(!isHidden)
                    .onTapGesture { if !isOpen { open() } }
                    .gesture(flick(side: side, screen: proxy.size), isEnabled: isOpen)
            }
        }
        .ignoresSafeArea()
        .sensoryFeedback(.impact(weight: .light), trigger: isOpen)
    }

    private func note(side: CGFloat) -> some View {
        ZStack {
            VStack(alignment: .leading, spacing: 10) {
                Text("Prayer List")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                TextEditor(text: Bindable(list).text)
                    .focused($isTyping)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, -5)
                    .overlay(alignment: .topLeading) {
                        if list.text.isEmpty {
                            Text("The people and things in your life you’d like to pray for…")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .allowsHitTesting(false)
                        }
                    }
            }
            .padding(20)
            .opacity(isOpen ? 1 : 0)
            // While it's a card, a tap opens it instead of starting to type.
            .allowsHitTesting(isOpen)

            // The app icon, while it's a card in the corner.
            Image("PrayerListCard")
                .resizable()
                .scaledToFill()
                .opacity(isOpen ? 0 : 1)
                .allowsHitTesting(false)
        }
        .frame(width: side, height: side)
        .background(Color(uiColor: colorScheme == .dark ? .secondarySystemBackground : .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: isOpen ? 28 : side * 0.225, style: .continuous))
        .shadow(color: .black.opacity(isOpen ? 0.25 : 0.35), radius: isOpen ? 24 : 6 * side / Self.cardSize, y: isOpen ? 8 : 3 * side / Self.cardSize)
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
    /// quickly and it flies off the screen in that direction; let go slowly and it springs back.
    private func flick(side: CGFloat, screen: CGSize) -> some Gesture {
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
                // Off the screen in the direction it was thrown.
                let direction = speed > 700
                    ? CGSize(width: velocity.width / speed, height: velocity.height / speed)
                    : CGSize(width: value.translation.width / distance, height: value.translation.height / distance)
                let away = hypot(screen.width, screen.height)
                withAnimation(.easeOut(duration: 0.3)) {
                    drag = CGSize(width: drag.width + direction.width * away, height: drag.height + direction.height * away)
                    tilt = .degrees(tilt.degrees + direction.width * 25)
                } completion: {
                    // Back in its corner, out of sight, then fade the card in.
                    var reset = Transaction()
                    reset.disablesAnimations = true
                    withTransaction(reset) {
                        isOpen = false
                        drag = .zero
                        tilt = .zero
                        cardOpacity = 0
                    }
                    withAnimation(.easeIn(duration: 0.3).delay(0.1)) {
                        cardOpacity = 1
                    }
                }
            }
    }
}
