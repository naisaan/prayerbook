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
    @State private var count = 0
    @State private var showsSettings = false

    static let goal = 95

    var body: some View {
        Group {
            if classicView {
                ClassicCounter(count: $count)
            } else {
                BeadCounter(count: $count)
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
        .sheet(isPresented: $showsSettings) {
            CounterSettings(classicView: $classicView)
                .presentationDetents([.height(170)])
        }
    }
}

/// The quotation at the top of the counter.
private struct AllahuAbhaInstruction: View {
    @Environment(ReaderSettings.self) private var settings

    private static let instruction = "“It hath been ordained that every believer in God, the Lord of Judgment, shall, each day, having washed his hands and then his face, seat himself and, turning unto God, repeat ‘Alláh-u-Abhá’ ninety-five times.”"

    var body: some View {
        let size = min(settings.typography.size, 19)
        VStack(spacing: 6) {
            Text(Self.instruction)
                .font(settings.font.font(size: size))
            Text("Bahá’u’lláh")
                .font(settings.font.font(size: size * 0.9))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .foregroundStyle(Color(uiColor: Typography.textColor))
        .multilineTextAlignment(.leading)
    }
}

/// The card opened with a three-finger tap.
private struct CounterSettings: View {
    @Binding var classicView: Bool
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
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .top)
        .sensoryFeedback(.selection, trigger: classicView)
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
    @State private var haptics = CompletionHaptics()

    var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width * 0.7, proxy.size.height * 0.45)
            // The circle sits in the middle of the screen, with the instruction above it.
            ZStack {
                AllahuAbhaInstruction()
                    .frame(maxHeight: .infinity, alignment: .top)
                Button(action: tap) {
                    Circle()
                        .fill(Color(uiColor: Typography.textColor))
                        .frame(width: diameter, height: diameter)
                        .overlay {
                            Text("\(count)")
                                .font(settings.font.font(size: diameter * 0.36))
                                .monospacedDigit()
                                .foregroundStyle(Color(uiColor: Typography.pageColor))
                                .contentTransition(.numericText(value: Double(count)))
                        }
                }
                .buttonStyle(PressableCircleStyle())
                .accessibilityLabel("Alláh-u-Abhá counter")
                .accessibilityValue("\(count) of \(AllahuAbhaView.goal)")
                .accessibilityHint(count < AllahuAbhaView.goal ? Text("Double-tap to count one more") : Text(verbatim: ""))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sensoryFeedback(trigger: count) { old, new in
            new > old && new < AllahuAbhaView.goal ? .impact(weight: .medium, intensity: 0.8) : nil
        }
        .onAppear { haptics.prepare() }
    }

    private func tap() {
        // Past ninety-five a tap does nothing, so no haptic plays either.
        guard count < AllahuAbhaView.goal else { return }
        withAnimation(.snappy(duration: 0.2)) { count += 1 }
        if count == AllahuAbhaView.goal { haptics.play() }
    }
}

// MARK: Prayer beads

/// A strand of small beads running down the middle of the screen. Beads above the middle are
/// still to say; pulling draws the next one down across the middle, and the ones below are
/// said.
private struct BeadCounter: View {
    @Environment(ReaderSettings.self) private var settings
    @Binding var count: Int
    @State private var haptics = BeadHaptics()
    /// How far the bead being pulled has come, from 0 (not yet) to 1 (it drops into place).
    @State private var progress: CGFloat = 0
    /// The drag under way has already counted a bead, so it waits for the finger to lift.
    @State private var countedThisPull = false
    @State private var isPulling = false

    /// How far a finger travels, in any direction, to draw one bead.
    private static let pullDistance: CGFloat = 90
    private static let beadSize: CGFloat = 16
    private static let spacing: CGFloat = 34

    private var isFinished: Bool { count >= AllahuAbhaView.goal }

    var body: some View {
        GeometryReader { proxy in
            let middle = proxy.size.height * 0.56
            ZStack(alignment: .top) {
                AllahuAbhaInstruction()
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                strand(middle: middle, height: proxy.size.height)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    // Once all ninety-five are said, the beads fade away.
                    .opacity(isFinished ? 0 : 1)
                    .animation(.easeOut(duration: 1.6), value: isFinished)

                Text("\(count)")
                    .font(settings.font.font(size: 17))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: Double(count)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 24)
            }
        }
        .contentShape(Rectangle())
        .gesture(pull)
        .onAppear { haptics.prepare() }
        .onDisappear { haptics.stopPulling() }
        .onChange(of: count) { _, new in
            // Start Over.
            if new == 0 { progress = 0 }
        }
        .accessibilityElement()
        .accessibilityLabel("Alláh-u-Abhá counter")
        .accessibilityValue("\(count) of \(AllahuAbhaView.goal)")
        .accessibilityAddTraits(.allowsDirectInteraction)
        .accessibilityAction(named: Text("Count one more")) { countOne() }
    }

    /// The beads near the middle of the screen; the rest are off screen.
    private func strand(middle: CGFloat, height: CGFloat) -> some View {
        let visible = Int(height / Self.spacing / 2) + 2
        let first = max(0, count - visible)
        let last = min(AllahuAbhaView.goal - 1, count + visible)
        return ZStack {
            // The string the beads are on, fading out above and below like the beads.
            Rectangle()
                .fill(Color(uiColor: Typography.textColor).opacity(0.12))
                .frame(width: 1.5)
                .mask {
                    LinearGradient(stops: [
                        .init(color: .clear, location: max(0, (middle - height * 0.42) / height)),
                        .init(color: .black, location: middle / height),
                        .init(color: .clear, location: min(1, (middle + height * 0.42) / height)),
                    ], startPoint: .top, endPoint: .bottom)
                }
            ForEach(first...last, id: \.self) { bead in
                // Said beads sit below the middle, the rest above. The bead being pulled
                // slides from just above the middle to just below it.
                let y = middle + (CGFloat(count - bead) - 0.5 + progress) * Self.spacing
                let said = y > middle
                let fade = max(0, 1 - abs(y - middle) / (height * 0.42))
                Circle()
                    .fill(Color(uiColor: Typography.textColor))
                    .frame(width: Self.beadSize, height: Self.beadSize)
                    .opacity((said ? 1 : 0.35) * fade)
                    .position(x: 0, y: y)
            }
            .frame(width: 0)
        }
    }

    private var pull: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !isFinished, !countedThisPull else { return }
                if !isPulling {
                    // A small touch to say the bead is in hand.
                    isPulling = true
                    haptics.startPulling()
                }
                let distance = hypot(value.translation.width, value.translation.height)
                let amount = min(distance / Self.pullDistance, 1)
                progress = amount
                haptics.pull(amount)
                if amount >= 1 {
                    countedThisPull = true
                    countOne()
                }
            }
            .onEnded { _ in
                if isPulling && !countedThisPull {
                    // Let go too soon: the bead slides back.
                    haptics.stopPulling()
                    withAnimation(.spring(duration: 0.35, bounce: 0.3)) { progress = 0 }
                }
                isPulling = false
                countedThisPull = false
            }
    }

    private func countOne() {
        guard !isFinished else { return }
        haptics.stopPulling()
        // The bead's place is the same before and after, so this doesn't jump.
        progress = 0
        withAnimation(.snappy(duration: 0.2)) { count += 1 }
        if count == AllahuAbhaView.goal {
            haptics.bigThunk()
        } else {
            haptics.thunk()
        }
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
            try player.sendParameters([.init(parameterID: .hapticIntensityControl, value: 0.08, relativeTime: 0)], atTime: CHHapticTimeImmediate)
            try player.start(atTime: CHHapticTimeImmediate)
            pullPlayer = player
        } catch {
            pullPlayer = nil
        }
    }

    /// The pull grows stronger the further the bead is drawn.
    func pull(_ amount: CGFloat) {
        let intensity = Float(0.08 + 0.42 * amount)
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

    /// The ninety-fifth bead: a big thunk that slowly fades away.
    func bigThunk() {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                .init(parameterID: .hapticIntensity, value: 1),
                .init(parameterID: .hapticSharpness, value: 0.1),
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                .init(parameterID: .hapticIntensity, value: 1),
                .init(parameterID: .hapticSharpness, value: 0.05),
            ], relativeTime: 0, duration: 1.6),
        ]
        let fade = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
            .init(relativeTime: 0, value: 1),
            .init(relativeTime: 0.25, value: 0.6),
            .init(relativeTime: 1.6, value: 0),
        ], relativeTime: 0)
        play(events, curves: [fade], fallback: .heavy)
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
