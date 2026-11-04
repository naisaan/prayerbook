import SwiftUI
import CoreHaptics

/// Counts the ninety-five repetitions of "Alláh-u-Abhá".
///
/// By default it's a string of prayer beads: touch anywhere and pull in any direction to draw
/// the next bead along, feeling it pull under the finger, until it drops into place with a
/// thunk. Let go and pull the next one. The ninety-fifth lands with a big thunk and the beads
/// fade away.
///
/// Classic View is the big circle that counts a tap at a time. Tapping the screen with three
/// fingers opens a small settings card to switch between the two.
struct AllahuAbhaView: View {
    @Environment(ReaderSettings.self) private var settings
    @AppStorage("allahuAbhaClassicView") private var classicView = false
    @AppStorage("prayerBeadColor") private var beadColor = BeadColor.blue
    @State private var count = 0
    @State private var showsSettings = false

    /// How many to count to, chosen in the three-finger settings. Ninety-five unless changed.
    @AppStorage("allahuAbhaGoal") private var goal = 95

    /// The counts to choose from.
    static let goals = [5, 9, 18, 19, 95, 500, 12_000]

    var body: some View {
        Group {
            if classicView {
                ClassicCounter(count: $count, goal: goal)
            } else {
                BeadCounter(count: $count, goal: goal, color: beadColor)
            }
        }
        .contentShape(Rectangle())
        // Three fingers, one tap: this screen's own settings.
        .gesture(ThreeFingerTap { showsSettings = true })
        // Pure white in light mode, pure black in dark mode, edge to edge.
        .background(Color(uiColor: Typography.pageColor).ignoresSafeArea())
        .navigationTitle("Alláh-u-Abhá")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if count > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Start Over", systemImage: "arrow.counterclockwise") {
                        withAnimation { count = 0 }
                    }
                }
            }
        }
        // A new goal starts the count again.
        .onChange(of: goal) { count = 0 }
        .sheet(isPresented: $showsSettings) {
            CounterSettings(classicView: $classicView, beadColor: $beadColor, goal: $goal)
                .presentationDetents([.height(classicView ? 240 : 360)])
        }
    }
}

/// The quotation at the top of the counter, with how to use it beneath.
private struct AllahuAbhaInstruction: View {
    @Environment(ReaderSettings.self) private var settings
    /// How to count, in small gray text under the quotation.
    var hint: LocalizedStringKey?

    private static let instruction = "“It hath been ordained that every believer in God, the Lord of Judgment, shall, each day, having washed his hands and then his face, seat himself and, turning unto God, repeat ‘Alláh-u-Abhá’ ninety-five times.”"

    var body: some View {
        let size = min(settings.typography.size, 19)
        VStack(spacing: 6) {
            Text(Self.instruction)
                .font(settings.font.font(size: size))
            Text("Bahá’u’lláh")
                .font(settings.font.font(size: size * 0.9))
                .frame(maxWidth: .infinity, alignment: .trailing)
            if let hint {
                Text(hint)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 14)
            }
        }
        .foregroundStyle(Color(uiColor: Typography.textColor))
        .multilineTextAlignment(.leading)
    }
}

/// The card opened with a three-finger tap.
private struct CounterSettings: View {
    @Binding var classicView: Bool
    @Binding var beadColor: BeadColor
    @Binding var goal: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
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
                Text("Alláh-u-Abhá")
                    .font(.title3.weight(.semibold))
            }
            Toggle(isOn: $classicView) {
                Label("Classic View", systemImage: "circle.fill")
            }
            .padding(.horizontal, 20)
            .frame(height: 52)
            .menuSurface(.capsule, interactive: false)

            // How many to count to, picked from Apple's pop-up menu.
            HStack {
                Label("Count To", systemImage: "number")
                Spacer()
                Picker(selection: $goal) {
                    ForEach(AllahuAbhaView.goals, id: \.self) { option in
                        Text(option, format: .number).tag(option)
                    }
                } label: {
                    Text("Count To")
                }
                .pickerStyle(.menu)
                .tint(.primary)
            }
            .padding(.leading, 20)
            .padding(.trailing, 8)
            .frame(height: 52)
            .menuSurface(.capsule, interactive: false)

            if !classicView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose the main color of your prayer bead")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    // Round swatches with a ring on the chosen one, like the note colors.
                    HStack(spacing: 18) {
                        ForEach(BeadColor.allCases, id: \.self) { option in
                            Button { beadColor = option } label: {
                                Circle()
                                    .fill(option.deep)
                                    .overlay {
                                        if option == .white {
                                            Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                                        }
                                    }
                                    .frame(width: 28, height: 28)
                                    .padding(4)
                                    .overlay {
                                        if option == beadColor {
                                            Circle().strokeBorder(Color.primary, lineWidth: 2)
                                        }
                                    }
                            }
                            .buttonStyle(PressableButtonStyle())
                            .accessibilityLabel(option.name)
                            .accessibilityAddTraits(option == beadColor ? .isSelected : [])
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(20)
                .menuSurface(.rect(cornerRadius: 26), interactive: false)
                .transition(.opacity)
            }
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .top)
        .animation(.smooth(duration: 0.25), value: classicView)
        .sensoryFeedback(.selection, trigger: classicView)
        .sensoryFeedback(.selection, trigger: beadColor)
        .sensoryFeedback(.selection, trigger: goal)
    }
}

/// A tap with three fingers at once. SwiftUI's own taps count taps, not fingers, so this
/// borrows UIKit's tap recognizer, which can ask for three touches.
private struct ThreeFingerTap: UIGestureRecognizerRepresentable {
    let action: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UITapGestureRecognizer {
        let recognizer = UITapGestureRecognizer()
        recognizer.numberOfTouchesRequired = 3
        // Works alongside pulling the beads and tapping the circle.
        recognizer.delegate = context.coordinator
        return recognizer
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }

    func handleUIGestureRecognizerAction(_ recognizer: UITapGestureRecognizer, context: Context) {
        if recognizer.state == .ended { action() }
    }
}

// MARK: Classic View

/// The big circle: each tap counts one, with a light tap of haptic feedback, and reaching
/// ninety-five plays a slow, gentle swell instead.
private struct ClassicCounter: View {
    @Environment(ReaderSettings.self) private var settings
    @Binding var count: Int
    let goal: Int
    @State private var haptics = CompletionHaptics()

    var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width * 0.7, proxy.size.height * 0.45)
            // The circle sits in the middle of the screen, with the instruction above it.
            ZStack {
                AllahuAbhaInstruction(hint: "Tap the circle each time you say “Alláh-u-Abhá”. Tap with three fingers for settings.")
                    .frame(maxHeight: .infinity, alignment: .top)
                Button(action: tap) {
                    Circle()
                        .fill(Color(uiColor: Typography.textColor))
                        .frame(width: diameter, height: diameter)
                        .overlay {
                            Text(count, format: .number)
                                .font(settings.font.font(size: diameter * 0.36))
                                .monospacedDigit()
                                // Big numbers shrink to fit on one line inside the circle.
                                .lineLimit(1)
                                .minimumScaleFactor(0.2)
                                .padding(.horizontal, diameter * 0.12)
                                .foregroundStyle(Color(uiColor: Typography.pageColor))
                                .contentTransition(.numericText(value: Double(count)))
                        }
                }
                .buttonStyle(PressableCircleStyle())
                .accessibilityLabel("Alláh-u-Abhá counter")
                .accessibilityValue("\(count) of \(goal)")
                .accessibilityHint(count < goal ? Text("Double-tap to count one more") : Text(verbatim: ""))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sensoryFeedback(trigger: count) { old, new in
            new > old && new < goal ? .impact(weight: .medium, intensity: 0.8) : nil
        }
        .onAppear { haptics.prepare() }
    }

    private func tap() {
        // Past ninety-five a tap does nothing, so no haptic plays either.
        guard count < goal else { return }
        withAnimation(.snappy(duration: 0.2)) { count += 1 }
        if count == goal { haptics.play() }
    }
}

// MARK: Prayer beads

/// Two prayer beads on a string. Touch anywhere and a bead appears under the finger. Start
/// pulling, in any direction, and the next bead appears ahead, joined by the string; the bead
/// in hand follows the finger along the string until it knocks against the other one with a
/// thunk, and the count shows on it. Let go and touch again for the next.
private struct BeadCounter: View {
    @Binding var count: Int
    let goal: Int
    let color: BeadColor
    @State private var haptics = BeadHaptics()

    /// Where the finger came down, which is where the bead in hand starts.
    @State private var start: CGPoint?
    /// The bead being pulled toward, set once the pull's direction is known.
    @State private var target: CGPoint?
    /// How far the bead in hand has come along the string, from 0 to 1 (touching).
    @State private var progress: CGFloat = 0
    /// This pull has counted, so it waits for the finger to lift.
    @State private var countedThisPull = false
    /// After a count, the bead stays where it landed, showing the count, until the next touch.
    @State private var restingBead: CGPoint?
    /// The pull's direction is settled. Until then the string and the next bead follow the
    /// finger round as they fade in.
    @State private var committed = false
    /// How far along the bead in hand was when the direction settled. The string and the
    /// next bead start fading in from there.
    @State private var commitProgress: CGFloat = 0
    /// A fresh identity for each pull, so the old beads fade out as new ones appear.
    @State private var pullID = UUID()

    /// How far the bead travels along the string before it touches the other.
    private static let travel: CGFloat = 260
    /// How far the finger moves before the direction is settled.
    private static let commitDistance: CGFloat = 110

    private var isFinished: Bool { count >= goal }

    var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width * 0.27, 120)
            ZStack(alignment: .topLeading) {
                AllahuAbhaInstruction(hint: "Slowly drag your finger from anywhere to begin.\nTap with 3 fingers for Settings")
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .frame(width: proxy.size.width)

                beads(diameter: diameter)
                    .id(pullID)
                    .transition(.opacity.animation(.easeOut(duration: 0.35)))
                    // Once all ninety-five are said, the beads fade away.
                    .opacity(isFinished && start == nil ? 0 : 1)
                    .animation(.easeOut(duration: 1.6), value: isFinished)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .contentShape(Rectangle())
            .gesture(pull(diameter: diameter, bounds: proxy.size))
        }
        .onAppear { haptics.prepare() }
        .onDisappear { haptics.stopPulling() }
        .onChange(of: count) { _, new in
            // Start Over clears the beads.
            if new == 0 { restingBead = nil }
        }
        .accessibilityElement()
        .accessibilityLabel("Alláh-u-Abhá counter")
        .accessibilityValue("\(count) of \(goal)")
        .accessibilityAddTraits(.allowsDirectInteraction)
        .accessibilityAction(named: Text("Count one more")) {
            guard !isFinished else { return }
            count += 1
            count == goal ? haptics.bigThunk() : haptics.thunk()
        }
    }

    /// The string and the next bead fade in together, only once the direction has settled,
    /// over the next stretch of the pull.
    private var fadeIn: CGFloat {
        guard committed else { return 0 }
        let t = min(max((progress - commitProgress) / 0.3, 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// Where the bead in hand is now.
    private func beadInHand(diameter: CGFloat) -> CGPoint? {
        guard let start else { return restingBead }
        guard let target else { return start }
        let dx = target.x - start.x, dy = target.y - start.y
        let length = hypot(dx, dy)
        guard length > 0 else { return start }
        let along = progress * max(length - diameter, 0)
        return CGPoint(x: start.x + dx / length * along, y: start.y + dy / length * along)
    }

    @ViewBuilder
    private func beads(diameter: CGFloat) -> some View {
        if let bead = beadInHand(diameter: diameter) {
            ZStack(alignment: .topLeading) {
                if let target {
                    // The string between the two beads, with flat ends so it meets each bead's edge.
                    // From the edge of one bead to the edge of the other, never through them.
                    Path { path in
                        let dx = target.x - bead.x, dy = target.y - bead.y
                        let length = hypot(dx, dy)
                        let radius = diameter / 2
                        if length > diameter {
                            let ux = dx / length, uy = dy / length
                            path.move(to: CGPoint(x: bead.x + ux * radius, y: bead.y + uy * radius))
                            path.addLine(to: CGPoint(x: target.x - ux * radius, y: target.y - uy * radius))
                        }
                    }
                    .stroke(
                        LinearGradient(colors: [color.light, color.deep], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 6, lineCap: .butt)
                    )
                    .opacity(fadeIn)
                    .transition(.opacity)
                    Bead(diameter: diameter, color: color)
                        .position(target)
                        .opacity(fadeIn)
                        .transition(.opacity)
                }
                Bead(diameter: diameter, color: color, number: countedThisPull || start == nil ? count : nil)
                    .position(bead)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
    }

    private func pull(diameter: CGFloat, bounds: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !isFinished else { return }
                if start == nil {
                    // A new bead under the finger; the last one fades away.
                    pullID = UUID()
                    restingBead = nil
                    progress = 0
                    target = nil
                    committed = false
                    commitProgress = 0
                    withAnimation(.spring(duration: 0.3, bounce: 0.25)) { start = value.startLocation }
                    haptics.startPulling()
                }
                guard let start, !countedThisPull else { return }
                let t = value.translation
                let distance = hypot(t.width, t.height)

                if !committed {
                    guard distance > 8 else { return }
                    // Until the finger has moved far enough to settle the direction, the
                    // (still invisible) next bead swings round to follow it.
                    let length = diameter + Self.travel
                    // It may run off the edge of the screen, as long as at least 15% of it
                    // still shows, so the whole width of the screen can be used for the pull.
                    let overhang = diameter * 0.35
                    var point = CGPoint(x: start.x + t.width / distance * length, y: start.y + t.height / distance * length)
                    point.x = min(max(point.x, -overhang), bounds.width + overhang)
                    point.y = min(max(point.y, -overhang), bounds.height + overhang)
                    target = point
                }
                guard let target else { return }
                let dx = target.x - start.x, dy = target.y - start.y
                let length = hypot(dx, dy)
                let room = length - diameter
                guard room > 1 else { return }
                // Only the part of the drag along the string moves the bead.
                let along = (t.width * dx + t.height * dy) / length
                let amount = min(max(along / room, 0), 1)
                progress = amount
                if !committed && distance >= Self.commitDistance {
                    committed = true
                    commitProgress = amount
                }
                haptics.pull(amount)
                if amount >= 1 { landBead() }
            }
            .onEnded { _ in
                guard start != nil else { return }
                if countedThisPull {
                    // The bead stays where it landed with the count; the other one fades.
                    restingBead = beadInHand(diameter: diameter)
                    withAnimation(.easeOut(duration: 0.4)) {
                        target = nil
                        start = nil
                    }
                } else {
                    // Let go too soon: nothing counts, and the beads and string simply fade
                    // away where they are, without sliding.
                    haptics.stopPulling()
                    withAnimation(.easeOut(duration: 0.3)) {
                        target = nil
                        start = nil
                    }
                }
                countedThisPull = false
            }
    }

    private func landBead() {
        guard !isFinished else { return }
        countedThisPull = true
        haptics.stopPulling()
        withAnimation(.snappy(duration: 0.2)) { count += 1 }
        if count == goal {
            haptics.bigThunk()
        } else {
            haptics.thunk()
        }
    }
}

/// The main color of the prayer beads, chosen in the three-finger settings. Each is that
/// color above, with the same soft white cloud below.
enum BeadColor: String, CaseIterable {
    case blue, green, purple, red, white

    /// The bead's top, and its swatch in the settings.
    var deep: Color {
        switch self {
        case .blue: Color(red: 0.31, green: 0.45, blue: 0.90)
        case .green: Color(red: 0.20, green: 0.60, blue: 0.40)
        case .purple: Color(red: 0.50, green: 0.36, blue: 0.86)
        case .red: Color(red: 0.84, green: 0.26, blue: 0.31)
        // Black on the white page in light mode, white on the black page in dark mode.
        case .white: Color(uiColor: Typography.textColor)
        }
    }

    /// The soft cloud in the bead's lower half.
    var cloud: Color {
        switch self {
        // Solid, with no cloud.
        case .white: deep
        default: Color(red: 0.92, green: 0.93, blue: 0.99)
        }
    }

    /// The brighter wisp along the cloud's top.
    var wisp: Color {
        switch self {
        case .white: .clear
        default: .white.opacity(0.55)
        }
    }

    /// The lighter end of the string.
    var light: Color {
        switch self {
        case .blue: Color(red: 0.42, green: 0.62, blue: 0.98)
        case .green: Color(red: 0.36, green: 0.76, blue: 0.54)
        case .purple: Color(red: 0.66, green: 0.52, blue: 0.96)
        case .red: Color(red: 0.95, green: 0.45, blue: 0.48)
        case .white: deep
        }
    }

    /// Behind the count, so the white number stands out. None on the solid bead.
    var shadow: Color {
        self == .white ? .clear : deep
    }

    /// The count: white, or the page's color on the solid white or black bead.
    var number: Color {
        self == .white ? Color(uiColor: Typography.pageColor) : .white
    }

    var name: String {
        switch self {
        case .blue: String(localized: "Blue")
        case .green: String(localized: "Green")
        case .purple: String(localized: "Purple")
        case .red: String(localized: "Red")
        case .white: UITraitCollection.current.userInterfaceStyle == .dark ? String(localized: "White") : String(localized: "Black")
        }
    }
}

/// One bead: blue above, with soft white cloud rising from below, like a glass sphere of sky.
private struct Bead: View {
    let diameter: CGFloat
    let color: BeadColor
    /// The count, shown on the bead once it has landed.
    var number: Int?

    var body: some View {
        Circle()
            .fill(color.deep)
            .overlay {
                // Cloud, soft-edged, filling the lower half.
                Ellipse()
                    .fill(color.cloud)
                    .frame(width: diameter * 1.25, height: diameter * 0.7)
                    .offset(y: diameter * 0.36)
                    .blur(radius: diameter * 0.07)
            }
            .overlay {
                // A brighter wisp along the cloud's top.
                Ellipse()
                    .fill(color.wisp)
                    .frame(width: diameter * 0.7, height: diameter * 0.3)
                    .offset(x: -diameter * 0.08, y: diameter * 0.08)
                    .blur(radius: diameter * 0.06)
            }
            .clipShape(Circle())
            .frame(width: diameter, height: diameter)
            .overlay {
                if let number {
                    Text(number, format: .number)
                        .font(.system(size: diameter * 0.34, weight: .bold))
                        .monospacedDigit()
                        // Big numbers shrink to fit on one line inside the bead.
                        .lineLimit(1)
                        .minimumScaleFactor(0.2)
                        .padding(.horizontal, diameter * 0.12)
                        .foregroundStyle(color.number)
                        .shadow(color: color.shadow.opacity(0.8), radius: 4)
                        .contentTransition(.numericText(value: Double(number)))
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .animation(.snappy(duration: 0.25), value: number)
    }
}

/// The feel of the beads, with Core Haptics: a light touch when a bead is taken, a pull that
/// grows as it's drawn along, a thunk when it drops into place, and a big thunk that fades
/// away at ninety-five.
@MainActor
private final class BeadHaptics {
    private var engine: CHHapticEngine?
    private var pullPlayer: CHHapticAdvancedPatternPlayer?

    func prepare() {
        guard engine == nil, CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        engine?.isAutoShutdownEnabled = true
        engine?.resetHandler = { [weak self] in
            Task { @MainActor in self?.pullPlayer = nil }
        }
    }

    /// The bead is in hand: a small tap, then the pulling begins, very faint.
    func startPulling() {
        play([
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                .init(parameterID: .hapticIntensity, value: 0.35),
                .init(parameterID: .hapticSharpness, value: 0.4),
            ], relativeTime: 0),
        ])
        guard let engine else { return }
        do {
            try engine.start()
            let pattern = try CHHapticPattern(events: [
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    .init(parameterID: .hapticIntensity, value: 1),
                    .init(parameterID: .hapticSharpness, value: 0.15),
                ], relativeTime: 0, duration: 30),
            ], parameters: [])
            let player = try engine.makeAdvancedPlayer(with: pattern)
            try player.sendParameters([.init(parameterID: .hapticIntensityControl, value: 0.18, relativeTime: 0)], atTime: CHHapticTimeImmediate)
            try player.start(atTime: CHHapticTimeImmediate)
            pullPlayer = player
        } catch {
            pullPlayer = nil
        }
    }

    /// The pull grows stronger the further the bead is drawn.
    func pull(_ amount: CGFloat) {
        let intensity = Float(0.18 + 0.4 * amount)
        try? pullPlayer?.sendParameters([.init(parameterID: .hapticIntensityControl, value: intensity, relativeTime: 0)], atTime: CHHapticTimeImmediate)
    }

    func stopPulling() {
        try? pullPlayer?.stop(atTime: CHHapticTimeImmediate)
        pullPlayer = nil
    }

    /// The bead drops into place: a deep, soft knock.
    func thunk() {
        play([
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                .init(parameterID: .hapticIntensity, value: 1),
                .init(parameterID: .hapticSharpness, value: 0.25),
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                .init(parameterID: .hapticIntensity, value: 0.5),
                .init(parameterID: .hapticSharpness, value: 0.05),
            ], relativeTime: 0, duration: 0.08),
        ], fallback: .heavy)
    }

    /// The ninety-fifth bead: unmistakably the end. Three heavy knocks in quick succession,
    /// then a deep, full-strength rumble that holds for a moment and slowly fades away.
    func bigThunk() {
        var events: [CHHapticEvent] = []
        for (time, sharpness) in [(0.0, 0.35), (0.14, 0.2), (0.3, 0.1)] as [(TimeInterval, Float)] {
            events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [
                .init(parameterID: .hapticIntensity, value: 1),
                .init(parameterID: .hapticSharpness, value: sharpness),
            ], relativeTime: time))
        }
        events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [
            .init(parameterID: .hapticIntensity, value: 1),
            .init(parameterID: .hapticSharpness, value: 0.08),
        ], relativeTime: 0, duration: 2.6))
        let fade = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
            .init(relativeTime: 0, value: 1),
            .init(relativeTime: 0.9, value: 1),
            .init(relativeTime: 1.6, value: 0.5),
            .init(relativeTime: 2.6, value: 0),
        ], relativeTime: 0)
        play(events, curves: [fade], fallback: .heavy)
        if engine == nil {
            // Without Core Haptics, at least a strong success buzz.
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func play(_ events: [CHHapticEvent], curves: [CHHapticParameterCurve] = [], fallback: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard let engine else {
            UIImpactFeedbackGenerator(style: fallback).impactOccurred()
            return
        }
        do {
            try engine.start()
            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
            try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        } catch {
            UIImpactFeedbackGenerator(style: fallback).impactOccurred()
        }
    }
}

/// Shrinks the circle a touch while a finger is on it.
private struct PressableCircleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Three soft, slow swells that fade away, like breaths, played once the count is finished.
@MainActor
private final class CompletionHaptics {
    private var engine: CHHapticEngine?

    func prepare() {
        guard engine == nil, CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        engine?.isAutoShutdownEnabled = true
    }

    func play() {
        guard let engine, let pattern = try? Self.pattern() else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }
        do {
            try engine.start()
            try engine.makePlayer(with: pattern).start(atTime: 0)
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private static func pattern() throws -> CHHapticPattern {
        let swells: [(start: TimeInterval, strength: Float)] = [(0, 0.6), (1.2, 0.42), (2.4, 0.25)]
        var events: [CHHapticEvent] = []
        var curves: [CHHapticParameterCurve] = []
        for swell in swells {
            events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: swell.strength),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.05),
            ], relativeTime: swell.start, duration: 1.1))
            // Rise and fall within each swell, so it starts and ends softly.
            curves.append(CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
                .init(relativeTime: 0, value: 0),
                .init(relativeTime: 0.5, value: 1),
                .init(relativeTime: 1.1, value: 0),
            ], relativeTime: swell.start))
        }
        return try CHHapticPattern(events: events, parameterCurves: curves)
    }
}
