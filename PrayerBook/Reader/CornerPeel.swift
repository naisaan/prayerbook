import SwiftUI

/// On the cover, the page's bottom corner lifts a little now and then, like a book inviting
/// you to turn the page. It's the right corner, or the left for a right-to-left book.
struct CornerPeel: View {
    let isRightToLeft: Bool

    private enum Phase: CaseIterable {
        case rest, lift, settle, wait

        /// How far up the corner lifts, in points.
        var size: CGFloat {
            switch self {
            case .rest: 0
            case .lift: 38
            case .settle: 0.01
            case .wait: 0
            }
        }

        var animation: Animation {
            switch self {
            case .rest: .linear(duration: 1.2)
            case .lift: .spring(duration: 0.45, bounce: 0.35)
            case .settle: .spring(duration: 0.5, bounce: 0.2)
            case .wait: .linear(duration: 1.6)
            }
        }
    }

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .phaseAnimator(Phase.allCases) { _, phase in
                    Fold(size: phase.size, in: proxy.size)
                } animation: { phase in
                    phase.animation
                }
        }
        .scaleEffect(x: isRightToLeft ? -1 : 1, y: 1)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The lifted corner: the page beneath where it was, and the flap folded back over it.
    private struct Fold: View {
        var size: CGFloat
        let area: CGSize

        init(size: CGFloat, in area: CGSize) {
            self.size = size
            self.area = area
        }

        var body: some View {
            let w = area.width, h = area.height
            ZStack {
                // The page underneath, showing where the corner lifted away.
                Path { path in
                    path.move(to: CGPoint(x: w - size, y: h))
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: w, y: h - size))
                    path.closeSubpath()
                }
                .fill(Color(uiColor: Typography.pageColor))

                // The back of the corner, folded over.
                Path { path in
                    path.move(to: CGPoint(x: w - size, y: h))
                    path.addLine(to: CGPoint(x: w, y: h - size))
                    path.addLine(to: CGPoint(x: w - size, y: h - size))
                    path.closeSubpath()
                }
                .fill(LinearGradient(
                    colors: [Color(white: 0.96), Color(white: 0.82)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .shadow(color: .black.opacity(0.35), radius: 4, x: -2, y: -2)
            }
        }
    }
}
