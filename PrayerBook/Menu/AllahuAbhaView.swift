import SwiftUI
import CoreHaptics

/// Counts the ninety-five repetitions of "Alláh-u-Abhá". Each tap on the circle adds one, with a
/// light tap of haptic feedback, and reaching ninety-five plays a slow, gentle swell instead.
struct AllahuAbhaView: View {
    @Environment(ReaderSettings.self) private var settings
    @State private var count = 0
    @State private var haptics = CompletionHaptics()

    static let goal = 95

    private static let instruction = "“It hath been ordained that every believer in God, the Lord of Judgment, shall, each day, having washed his hands and then his face, seat himself and, turning unto God, repeat ‘Alláh-u-Abhá’ ninety-five times.”"

    var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width * 0.7, proxy.size.height * 0.45)
            // The circle sits in the middle of the screen, with the instruction above it.
            ZStack {
                instructionText
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
                .accessibilityValue("\(count) of \(Self.goal)")
                .accessibilityHint(count < Self.goal ? Text("Double-tap to count one more") : Text(verbatim: ""))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(uiColor: Typography.pageColor))
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
        .sensoryFeedback(trigger: count) { old, new in
            new > old && new < Self.goal ? .impact(weight: .medium, intensity: 0.8) : nil
        }
        .onAppear { haptics.prepare() }
    }

    private var instructionText: some View {
        let size = min(settings.typography.size, 19)
        return VStack(spacing: 6) {
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

    private func tap() {
        // Past ninety-five a tap does nothing, so no haptic plays either.
        guard count < Self.goal else { return }
        withAnimation(.snappy(duration: 0.2)) { count += 1 }
        if count == Self.goal { haptics.play() }
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
