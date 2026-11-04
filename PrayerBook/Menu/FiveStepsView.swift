import SwiftUI
import UIKit

/// The five steps for prayer, from a letter written on behalf of Shoghi Effendi, with the
/// Universal House of Justice's note about them. Shown exactly as written, in English, and
/// laid out like a prayer in the book: the reader's font and size, a title with a rule under
/// it, and justified lines (or not, with Natural Alignment). No drop cap, and it scrolls
/// rather than turning pages. It's only opened from Contents, never part of the book.
struct FiveStepsView: View {
    @Environment(ReaderSettings.self) private var settings
    @State private var cache = LayoutCache()
    /// The text size while two fingers are pinching, before it's saved. Nil otherwise.
    @State private var pinchSize: CGFloat?
    @State private var pinchStartSize: CGFloat = 0

    static let title = "5 Steps for Prayer from Shoghi Effendi"

    /// The text as a prayer, so the book's own typesetting lays it out.
    static let prayer = Prayer(
        id: -2,
        category: "",
        html: [
            "<p class=\"opening\"><span class=\"versal\">U</span>se these five steps if we have a problem of any kind for which we desire a solution, or wish help.</p>",
            "<p>Pray and meditate about it. Use the prayers of the Manifestations, as they have the greatest power. Learn to remain in the silence of contemplation for a few moments. During this deepest communion take the next step.</p>",
            "<p>Arrive at a decision and hold to this. This decision is usually born in a flash at the close or during the contemplation. It may seem almost impossible of accomplishment, but if it seems to be an answer to prayer or a way of solving the problem, then immediately take the next step.</p>",
            "<p>Have determination to carry the decision through. Many fail here. The decision, budding into determination, is blighted and instead becomes a wish or a vague longing. When determination is born, immediately take the next step.</p>",
            "<p>Have faith and confidence, that the Power of the Holy Spirit will flow through you, the right way will appear, the door will open, the right message, the right principle or the right book will be given to you. Have confidence, and the right thing will come to meet your need. Then as you rise from prayer take immediately the fifth step.</p>",
            "<p>Act as though it had all been answered. Then act with tireless, ceaseless energy. And, as you act, you yourself will become a magnet which will attract more power to your being, until you become an unobstructed channel for the Divine Power to flow through you.</p>",
            "<p class=\"comment\">-Letter written on behalf of Shoghi Effendi</p>",
            "<p>When asked about these notes, Shoghi Effendi replied, in letters written by his secretary on his behalf, that the notes should be regarded as “personal suggestions,” that he considered them to be “quite sound,” but that the friends need not adopt them “strictly and universally.” The House of Justice feels that they may be helpful to you.</p>",
            "<p class=\"comment\">-Letter written on behalf of the Universal House of Justice</p>",
        ].joined(),
        title: title,
        citation: "",
        author: "",
        languageCode: "en",
        wordCount: 300,
        searchText: ""
    )

    private var typography: Typography {
        var typography = settings.typography
        typography.dropCap = false
        if let pinchSize {
            // Half point steps, the same as the book's pinch.
            typography.size = (pinchSize * 2).rounded() / 2
        }
        return typography
    }

    var body: some View {
        GeometryReader { proxy in
            let margin = PageMetrics.sideMargin
            let width = max(proxy.size.width - margin * 2, 1)
            // Everything as the reader set it, except the drop cap, which this page never has.
            let layout = cache.layout(width: width, typography: typography)
            ScrollView {
                PrayerTextCanvas(layout: layout)
                    .frame(width: width, height: layout.height)
                    .padding(.horizontal, margin)
                    .padding(.top, 24)
                    .padding(.bottom, 48)
            }
            // Two fingers pinch the text bigger or smaller, like in the book; one finger scrolls.
            .simultaneousGesture(pinch)
        }
        // Pure white in light mode, pure black in dark mode, edge to edge, like the book.
        .background(Color(uiColor: Typography.pageColor).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension FiveStepsView {
    private var pinch: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.02)
            .onChanged { value in
                if pinchSize == nil { pinchStartSize = settings.textSize }
                let range = ReaderSettings.textSizeRange
                pinchSize = min(max(pinchStartSize * value.magnification, range.lowerBound), range.upperBound)
            }
            .onEnded { _ in
                if let pinchSize { settings.setTextSize(pinchSize) }
                pinchSize = nil
            }
    }
}

/// The text laid out in one long column, kept until the width or type changes.
private final class LayoutCache {
    struct Laid {
        let layout: PrayerLayout
        let height: CGFloat
    }

    private var key: (CGFloat, Typography)?
    private var laid: Laid?

    func layout(width: CGFloat, typography: Typography) -> Laid {
        if let key, let laid, key.0 == width, key.1 == typography { return laid }
        // One page as tall as the text could ever need, so it never splits.
        let layout = PrayerLayout(
            prayer: FiveStepsView.prayer,
            isRightToLeft: false,
            typography: typography,
            pageSize: CGSize(width: width, height: 100_000)
        )
        var height: CGFloat = 0
        if let container = layout.containers.first {
            height = ceil(layout.layoutManager.usedRect(for: container).maxY)
        }
        let result = Laid(layout: layout, height: height)
        key = (width, typography)
        laid = result
        return result
    }
}

/// Draws the laid-out text and its drop cap, the same way the book draws a page.
private struct PrayerTextCanvas: UIViewRepresentable {
    let layout: LayoutCache.Laid

    func makeUIView(context: Context) -> CanvasView {
        CanvasView()
    }

    func updateUIView(_ view: CanvasView, context: Context) {
        if view.layout !== layout.layout {
            view.layout = layout.layout
            view.setNeedsDisplay()
        }
    }

    final class CanvasView: UIView {
        var layout: PrayerLayout?

        init() {
            super.init(frame: .zero)
            backgroundColor = .clear
            isOpaque = false
            contentMode = .redraw
            // Black text in light mode, white in dark mode.
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _: UITraitCollection) in
                self.setNeedsDisplay()
            }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not used")
        }

        override func draw(_ rect: CGRect) {
            guard let layout, let container = layout.containers.first else { return }
            let glyphs = layout.layoutManager.glyphRange(for: container)
            layout.layoutManager.drawBackground(forGlyphRange: glyphs, at: .zero)
            layout.layoutManager.drawGlyphs(forGlyphRange: glyphs, at: .zero)
            if let dropCap = layout.dropCap, dropCap.containerIndex == 0 {
                dropCap.letter.draw(at: dropCap.origin)
            }
        }
    }
}
