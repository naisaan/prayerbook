import SwiftUI
import CoreHaptics

/// How the prayer beads feel under the finger, chosen in the three-finger settings. Each one
/// is built from Apple's two kinds of haptic, the way Apple's Core Haptics guide describes:
/// short taps ("transients") and steady hums ("continuous"), each with a strength (intensity)
/// and a feel from round and dull to crisp and sharp (sharpness). Rows of taps make a texture,
/// a hum that changes as the finger moves makes tension, and the bead holding back behind the
/// finger makes resistance.
enum BeadFeel: String, CaseIterable, Identifiable {
    case classic, wood, glass, stone, rubberBand, sand, heartbeat, magnet, clockwork, raindrop

    var id: Self { self }

    var name: LocalizedStringKey {
        switch self {
        case .classic: "Classic"
        case .wood: "Wooden Beads"
        case .glass: "Glass"
        case .stone: "Stone"
        case .rubberBand: "Rubber Band"
        case .sand: "Sand"
        case .heartbeat: "Heartbeat"
        case .magnet: "Magnet"
        case .clockwork: "Clockwork"
        case .raindrop: "Raindrop"
        }
    }

    /// How much the bead holds back. Above 1 it lags behind the finger and catches up at the
    /// end, like pulling against something; below 1 it rushes ahead, drawn in.
    var resistance: CGFloat {
        switch self {
        case .classic, .glass, .raindrop: 1
        case .wood: 1.15
        case .heartbeat: 1.1
        case .clockwork: 1.2
        case .sand: 1.3
        case .rubberBand: 1.45
        case .stone: 1.6
        case .magnet: 0.75
        }
    }

    /// Where the bead is along the string for how far the finger has pulled, both 0 to 1.
    func progress(for pull: CGFloat) -> CGFloat {
        pow(min(max(pull, 0), 1), resistance)
    }

    /// The steady hum while pulling: its sharpness at the start and end of the pull, and its
    /// strength from the start to the end, rising along a curve (power 1 is even).
    fileprivate var hum: PullHum? {
        switch self {
        case .classic: PullHum(0.15, 0.15, 0.18, 0.58, 1)
        case .wood: PullHum(0.3, 0.3, 0.06, 0.2, 1)
        case .glass: PullHum(0.9, 0.95, 0.06, 0.18, 1)
        case .stone: PullHum(0, 0.05, 0.3, 0.95, 1.5)
        case .rubberBand: PullHum(0.1, 0.8, 0.04, 1, 2.2)
        case .sand: PullHum(0.6, 0.6, 0.04, 0.1, 1)
        case .magnet: PullHum(0.5, 0.7, 0.03, 1, 4)
        case .raindrop: PullHum(0.05, 0.2, 0.08, 0.3, 1)
        case .heartbeat, .clockwork: nil
        }
    }

    /// How far apart the taps of the pull's texture are, as a share of the pull. None for a
    /// smooth pull.
    fileprivate var tickSpacing: CGFloat? {
        switch self {
        case .wood: 0.1
        case .stone: 0.22
        case .sand: 0.02
        case .heartbeat: 0.22
        case .clockwork: 0.04
        default: nil
        }
    }
}

/// The steady hum under the finger while a bead is pulled.
fileprivate struct PullHum {
    let sharpness: Float, endSharpness: Float, low: Float, high: Float, power: Float
    init(_ sharpness: Float, _ endSharpness: Float, _ low: Float, _ high: Float, _ power: Float) {
        self.sharpness = sharpness
        self.endSharpness = endSharpness
        self.low = low
        self.high = high
        self.power = power
    }
}

/// The feel of the beads, with Core Haptics: a light touch when a bead is taken, a pull with
/// its own texture and tension, a knock when it drops into place, and something big when the
/// last bead lands, all in the chosen feel.
@MainActor
final class BeadHaptics {
    var feel: BeadFeel = .classic
    private var engine: CHHapticEngine?
    private var pullPlayer: CHHapticAdvancedPatternPlayer?
    /// Where the next tap of the pull's texture comes.
    private var nextTick: CGFloat = 0
    /// Counts the clockwork's ticks, so every fifth is stronger.
    private var tickCount = 0

    func prepare() {
        guard engine == nil, CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        engine?.isAutoShutdownEnabled = true
        engine?.resetHandler = { [weak self] in
            Task { @MainActor in self?.pullPlayer = nil }
        }
    }

    // MARK: Pulling

    /// The bead is in hand: a small tap, then the pulling begins, very faint.
    func startPulling() {
        nextTick = feel.tickSpacing ?? 0
        tickCount = 0
        switch feel {
        case .glass, .clockwork, .magnet: play([tap(0, 0.4, 0.8)])
        case .stone: play([tap(0, 0.6, 0.05)])
        case .sand: play([tap(0, 0.25, 0.7), tap(0.03, 0.2, 0.8)])
        case .raindrop: play([tap(0, 0.3, 0.3)])
        default: play([tap(0, 0.35, 0.4)])
        }
        guard let engine, let hum = feel.hum else { return }
        do {
            try engine.start()
            let pattern = try CHHapticPattern(events: [
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    .init(parameterID: .hapticIntensity, value: 1),
                    .init(parameterID: .hapticSharpness, value: hum.sharpness),
                ], relativeTime: 0, duration: 30),
            ], parameters: [])
            let player = try engine.makeAdvancedPlayer(with: pattern)
            try player.sendParameters([.init(parameterID: .hapticIntensityControl, value: hum.low, relativeTime: 0)], atTime: CHHapticTimeImmediate)
            try player.start(atTime: CHHapticTimeImmediate)
            pullPlayer = player
        } catch {
            pullPlayer = nil
        }
    }

    /// The pull changes as the bead is drawn along: the hum grows, and the texture's taps
    /// pass under the finger.
    func pull(_ amount: CGFloat) {
        if let hum = feel.hum {
            let strength = hum.low + (hum.high - hum.low) * pow(Float(amount), hum.power)
            var parameters = [CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: strength, relativeTime: 0)]
            if hum.endSharpness != hum.sharpness {
                // The sharpness control shifts the hum's sharpness up or down from where it began.
                let shift = (hum.endSharpness - hum.sharpness) * Float(amount)
                parameters.append(.init(parameterID: .hapticSharpnessControl, value: shift, relativeTime: 0))
            }
            try? pullPlayer?.sendParameters(parameters, atTime: CHHapticTimeImmediate)
        }
        guard let spacing = feel.tickSpacing, amount >= nextTick, amount < 1 else { return }
        tick(at: amount)
        // Sand's grains are uneven; everything else is regular.
        nextTick = amount + (feel == .sand ? spacing * CGFloat.random(in: 0.5...1.6) : spacing)
    }

    func stopPulling() {
        try? pullPlayer?.stop(atTime: CHHapticTimeImmediate)
        pullPlayer = nil
    }

    /// One tap of the pull's texture, a little stronger the further along it is.
    private func tick(at amount: CGFloat) {
        let a = Float(amount)
        tickCount += 1
        switch feel {
        case .wood:
            // Knots on a cord.
            play([tap(0, 0.4 + 0.4 * a, 0.45)])
        case .stone:
            // Grinding over rough ground.
            play([tap(0, 0.5 + 0.3 * a, 0.05), tap(0.04, 0.3, 0.1)])
        case .sand:
            play([tap(0, Float.random(in: 0.15...0.4), Float.random(in: 0.5...0.9))])
        case .heartbeat:
            // Lub-dub, quickening in strength.
            play([tap(0, 0.45 + 0.4 * a, 0.2), tap(0.13, 0.3 + 0.3 * a, 0.15)])
        case .clockwork:
            play([tap(0, tickCount % 5 == 0 ? 0.85 : 0.45, 0.95)])
        default:
            break
        }
    }

    // MARK: Landing

    /// The bead drops into place.
    func thunk() {
        switch feel {
        case .classic:
            play([tap(0, 1, 0.25), hum(0, 0.08, 0.5, 0.05)], fallback: .heavy)
        case .wood:
            // Wood on wood: clack-clack.
            play([tap(0, 1, 0.5), tap(0.06, 0.55, 0.45)], fallback: .medium)
        case .glass:
            // A clink that rings for a moment.
            play([tap(0, 0.9, 1), tap(0.07, 0.35, 1), tap(0.14, 0.15, 1)], fallback: .rigid)
        case .stone:
            // A deep thud that rumbles away.
            play([tap(0, 1, 0), hum(0, 0.3, 0.8, 0)],
                 curves: [fade(from: 1, at: 0, to: 0, at: 0.3)], fallback: .heavy)
        case .rubberBand:
            // Snap, then a wobble.
            play([tap(0, 1, 1), tap(0.06, 0.6, 0.5), tap(0.12, 0.4, 0.4), tap(0.18, 0.25, 0.3)], fallback: .rigid)
        case .sand:
            // A soft crunch.
            play((0..<6).map { tap(Double($0) * 0.018, Float.random(in: 0.4...0.8), Float.random(in: 0.4...0.8)) }, fallback: .soft)
        case .heartbeat:
            play([tap(0, 1, 0.2), tap(0.14, 0.7, 0.1)], fallback: .heavy)
        case .magnet:
            // Snaps together, with a short buzz.
            play([tap(0, 1, 0.85), hum(0, 0.12, 0.6, 0.7)], fallback: .rigid)
        case .clockwork:
            // Tick, then a clunk as it locks.
            play([tap(0, 0.7, 0.95), tap(0.08, 1, 0.3)], fallback: .medium)
        case .raindrop:
            // A plop: round and full, falling away.
            play([tap(0, 0.6, 0.6), hum(0, 0.14, 1, 0.8)],
                 curves: [CHHapticParameterCurve(parameterID: .hapticSharpnessControl, controlPoints: [
                    .init(relativeTime: 0, value: 0), .init(relativeTime: 0.14, value: -0.8),
                 ], relativeTime: 0), fade(from: 1, at: 0.04, to: 0, at: 0.14)],
                 fallback: .soft)
        }
    }

    // MARK: The last bead

    /// The last bead: unmistakably the end, in the chosen feel.
    func bigThunk() {
        switch feel {
        case .classic:
            // Three heavy knocks, then a deep rumble that holds and slowly fades.
            var events = [(0.0, Float(0.35)), (0.14, 0.2), (0.3, 0.1)].map { tap($0.0, 1, $0.1) }
            events.append(hum(0, 2.6, 1, 0.08))
            play(events, curves: [curve([(0, 1), (0.9, 1), (1.6, 0.5), (2.6, 0)])], fallback: .heavy)
        case .wood:
            // The whole string of beads rattles, then one last knock.
            var events: [CHHapticEvent] = []
            var time = 0.0
            for i in 0..<14 {
                events.append(tap(time, 1 - Float(i) * 0.05, 0.45))
                time += 0.05 + Double(i) * 0.01
            }
            events.append(tap(time + 0.25, 1, 0.3))
            play(events, fallback: .heavy)
        case .glass:
            // Three clinks, then a bright shimmer that fades.
            play([tap(0, 1, 1), tap(0.25, 0.9, 1), tap(0.5, 1, 1), hum(0.5, 1.6, 0.45, 1)],
                 curves: [curve([(0, 1), (0.6, 1), (2.1, 0)])], fallback: .rigid)
        case .stone:
            // A rumble that builds like a landslide, with boulders, then settles.
            var events = [hum(0, 2.6, 1, 0)]
            for time in [0.5, 0.75, 0.95, 1.3] { events.append(tap(time, 1, 0.05)) }
            play(events, curves: [curve([(0, 0.3), (0.8, 1), (1.4, 1), (2.6, 0)])], fallback: .heavy)
        case .rubberBand:
            // A twang that wobbles back and forth, smaller each time.
            play([tap(0, 1, 1), hum(0, 1.8, 1, 0.3)],
                 curves: [curve([(0, 1), (0.15, 0.2), (0.3, 0.85), (0.45, 0.15), (0.6, 0.65), (0.75, 0.1), (0.95, 0.4), (1.15, 0.05), (1.4, 0.2), (1.8, 0)])],
                 fallback: .rigid)
        case .sand:
            // Sand pouring out, slowly running dry.
            var events = [hum(0, 2.2, 0.25, 0.5)]
            for i in 0..<70 {
                let time = Double(i) * 0.03 + Double.random(in: 0...0.02)
                events.append(tap(time, Float.random(in: 0.3...0.9) * (1 - Float(i) / 80), Float.random(in: 0.4...0.9)))
            }
            play(events, curves: [curve([(0, 1), (1.2, 0.8), (2.2, 0)])], fallback: .soft)
        case .heartbeat:
            // A heartbeat that slows and softens, at peace.
            var events: [CHHapticEvent] = []
            var time = 0.0
            for (i, gap) in [0.55, 0.7, 0.9, 1.2].enumerated() {
                let strength = 1 - Float(i) * 0.2
                events.append(tap(time, strength, 0.2))
                events.append(tap(time + 0.14, strength * 0.7, 0.1))
                time += gap
            }
            play(events, fallback: .heavy)
        case .magnet:
            // Snap, snap, then a hum that fades.
            play([tap(0, 1, 0.9), tap(0.12, 1, 0.8), hum(0.12, 2, 0.8, 0.6)],
                 curves: [curve([(0, 1), (0.5, 1), (2.1, 0)])], fallback: .rigid)
        case .clockwork:
            // Winding down, slower and slower, then a chime.
            var events: [CHHapticEvent] = []
            var time = 0.0, gap = 0.08
            for _ in 0..<10 {
                events.append(tap(time, 0.7, 0.95))
                time += gap
                gap *= 1.2
            }
            events.append(tap(time + 0.2, 1, 1))
            events.append(hum(time + 0.2, 0.6, 0.5, 0.9))
            play(events, curves: [curve([(0, 1), (time + 0.25, 1), (time + 0.8, 0)])], fallback: .medium)
        case .raindrop:
            // One drop, then ripples spreading out and fading.
            var events = [tap(0, 1, 0.6)]
            for (i, strength) in [Float(0.8), 0.55, 0.35, 0.2, 0.1].enumerated() {
                events.append(hum(Double(i) * 0.4 + 0.1, 0.22, strength, 0.1))
            }
            play(events, fallback: .soft)
        }
        if engine == nil {
            // Without Core Haptics, at least a strong success buzz.
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    // MARK: Building blocks

    private func tap(_ time: TimeInterval, _ intensity: Float, _ sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticTransient, parameters: [
            .init(parameterID: .hapticIntensity, value: min(max(intensity, 0), 1)),
            .init(parameterID: .hapticSharpness, value: min(max(sharpness, 0), 1)),
        ], relativeTime: time)
    }

    private func hum(_ time: TimeInterval, _ duration: TimeInterval, _ intensity: Float, _ sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticContinuous, parameters: [
            .init(parameterID: .hapticIntensity, value: intensity),
            .init(parameterID: .hapticSharpness, value: sharpness),
        ], relativeTime: time, duration: duration)
    }

    /// A strength curve through (time, strength) points, for the whole pattern.
    private func curve(_ points: [(TimeInterval, Float)]) -> CHHapticParameterCurve {
        CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: points.map {
            .init(relativeTime: $0.0, value: $0.1)
        }, relativeTime: 0)
    }

    private func fade(from start: Float, at startTime: TimeInterval, to end: Float, at endTime: TimeInterval) -> CHHapticParameterCurve {
        curve([(startTime, start), (endTime, end)])
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
