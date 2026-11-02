import SwiftUI

/// On the cover, until the reader turns it for the first time, the bottom corner is pulled
/// in by an invisible hand, about a quarter of the way up the page, showing the next page
/// beneath, and then let go so it falls back flat. It's the right corner, or the left for a
/// right-to-left book.
struct CornerPeel<Underneath: View>: View {
    let isRightToLeft: Bool
    /// The page under the cover, seen where the corner is pulled away.
    @ViewBuilder let underneath: Underneath

    @Environment(\.colorScheme) private var colorScheme

    private enum Phase: CaseIterable {
        case rest, pull, hold, release

        /// How far in the corner is pulled, as a share of the full pull.
        var amount: CGFloat {
            switch self {
            case .rest: 0
            case .pull: 1
            case .hold: 0.97
            case .release: 0
            }
        }

        /// The animation that leads into this phase.
        var animation: Animation {
            switch self {
            // A pause on the flat cover before the next pull.
            case .rest: .linear(duration: 2.2)
            // Slow and even, like a hand drawing the corner across.
            case .pull: .easeInOut(duration: 1.1)
            case .hold: .easeOut(duration: 0.35)
            // Let go: it falls back flat.
            case .release: .spring(duration: 0.7, bounce: 0.15)
            }
        }
    }

    var body: some View {
        GeometryReader { proxy in
            // Pulled until the corner reaches about a quarter of the way up the page.
            let fullPull = min(proxy.size.height * 0.25, proxy.size.width * 0.55)
            Color.clear
                .phaseAnimator(Phase.allCases) { _, phase in
                    Fold(
                        size: phase.amount * fullPull,
                        area: proxy.size,
                        isRightToLeft: isRightToLeft,
                        backColors: backColors,
                        underneath: underneath
                    )
                } animation: { phase in
                    phase.animation
                }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The back of the cover: paper, a little shaded.
    private var backColors: [Color] {
        colorScheme == .dark
            ? [Color(white: 0.2), Color(white: 0.1)]
            : [Color(white: 0.97), Color(white: 0.84)]
    }

    /// The pulled corner: the next page showing where it was, and the flap folded back over it.
    private struct Fold: View, Animatable {
        var size: CGFloat
        let area: CGSize
        let isRightToLeft: Bool
        let backColors: [Color]
        let underneath: Underneath

        /// Lets SwiftUI animate the corner smoothly between sizes.
        var animatableData: CGFloat {
            get { size }
            set { size = newValue }
        }

        /// A point measured from the bottom corner being pulled.
        private func point(_ inward: CGFloat, _ up: CGFloat) -> CGPoint {
            CGPoint(x: isRightToLeft ? inward : area.width - inward, y: area.height - up)
        }

        var body: some View {
            ZStack {
                // The next page, where the corner has come away.
                underneath
                    .frame(width: area.width, height: area.height)
                    .mask {
                        Path { path in
                            path.move(to: point(size, 0))
                            path.addLine(to: point(0, 0))
                            path.addLine(to: point(0, size))
                            path.closeSubpath()
                        }
                    }

                // The back of the corner, folded over.
                Path { path in
                    path.move(to: point(size, 0))
                    path.addLine(to: point(0, size))
                    path.addLine(to: point(size, size))
                    path.closeSubpath()
                }
                .fill(LinearGradient(
                    colors: backColors,
                    startPoint: isRightToLeft ? .topTrailing : .topLeading,
                    endPoint: isRightToLeft ? .bottomLeading : .bottomTrailing
                ))
                .shadow(color: .black.opacity(0.3), radius: 6, x: isRightToLeft ? 3 : -3, y: -3)
            }
            .opacity(size > 0.5 ? 1 : 0)
        }
    }
}
