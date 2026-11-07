import SwiftUI
import UIKit
import AVFoundation

/// The steps of the tutorial shown the first time someone opens the book.
enum TutorialStep: Int, CaseIterable {
    case welcome, menu, bookmarks, highlights, prayerList, prayerListOpen, done

    var title: LocalizedStringKey? {
        self == .welcome ? "Alláh’u’Abhá and Welcome!" : nil
    }

    var message: LocalizedStringKey {
        switch self {
        case .welcome:
            "This app was inspired by a physical Prayer Book and can do many of the same things like bookmark, take notes, and more.\n\nPlease tap the Menu button at the bottom to get started."
        case .menu:
            "Here you can see the Contents of your Prayer Book, search for prayers, choose other languages, and open Settings."
        case .bookmarks:
            "To bookmark a prayer, press the Bookmark button. To create a bookmark list, press the plus and name your new list."
        case .highlights:
            "To highlight and create notes, select text and then press Highlight or Add Note."
        case .prayerList:
            "In the top right corner is the Prayer List. You can write things you want to remember and create checklists to quickly reference at any time."
        case .prayerListOpen:
            "Feel free to throw this back when you’re done."
        case .done:
            "Feel free to pinch to make the text bigger or smaller, and swipe to turn the page.\nI hope you enjoy this app!"
        }
    }

    enum Placement { case top, center, bottom }

    /// The menu's steps sit at the top, out of the open menu's way. The prayer list's sit at
    /// the bottom, so the card in the corner (and then the open list) can be tapped.
    var placement: Placement {
        switch self {
        case .menu, .bookmarks: .top
        case .prayerList, .prayerListOpen: .bottom
        case .welcome, .highlights, .done: .center
        }
    }

    /// The steps that point at something on screen (the open menu, the prayer list) have no
    /// picture, so the card stays small and out of the way.
    var hasPicture: Bool { placement == .center }

    /// The first step moves on when the menu button is tapped, the prayer list's when the list
    /// is opened, and then when it's thrown back, so those have no Next button.
    var hasNextButton: Bool { ![.welcome, .prayerList, .prayerListOpen].contains(self) }

    /// Whether this step needs the menu open.
    var usesMenu: Bool { placement == .top }

    /// The step after this one.
    var next: TutorialStep? {
        TutorialStep(rawValue: rawValue + 1)
    }

    /// Which progress dot is lit. Opening the prayer list is part of its step.
    var dot: Int { self == .done ? 5 : min(rawValue, 4) }
    static let dotCount = 6
}

/// One step of the tutorial, on the same surface as the menu's buttons.
struct TutorialCard: View {
    let step: TutorialStep
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if step.hasPicture {
                screenshot
            }

            VStack(alignment: .leading, spacing: 8) {
                if let title = step.title {
                    Text(title)
                        .font(.title2.bold())
                }
                Text(step.message)
                    .font(.body)
                    .foregroundStyle(step.title == nil ? .primary : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 4)

            ZStack {
                // One dot per step, like a page control, centered; the current one is solid.
                HStack(spacing: 8) {
                    ForEach(0..<TutorialStep.dotCount, id: \.self) { dot in
                        Circle()
                            .fill(Color.primary.opacity(dot == step.dot ? 1 : 0.25))
                            .frame(width: 7, height: 7)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel(Text("\(step.dot + 1) of \(TutorialStep.dotCount)"))

                HStack {
                    Spacer(minLength: 0)
                    // On these steps the reader's own tap or throw is the way on.
                    if step.hasNextButton {
                        Button(step == .done ? LocalizedStringKey("Done") : LocalizedStringKey("Next"), action: onNext)
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(16)
        .padding(.top, 4)
        // Always the full width, so a short message doesn't make a narrower card.
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxWidth: 360)
        .background {
            // Floats above the page. Only the card casts a shadow, so the picture sits flush.
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.3), radius: 30, y: 12)
        }
        .padding(.horizontal, 20)
    }

    /// The step's moving picture, in light or dark to match the app: TutorialPage, TutorialHighlight
    /// and TutorialZoom (-LM or -DM) videos in Resources/Tutorial. A step without one shows a
    /// placeholder of the same size.
    @ViewBuilder
    private var screenshot: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(uiColor: .tertiarySystemFill))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let url = animationURL {
                    LoopingVideo(url: url)
                } else {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                }
            }
            .clipShape(.rect(cornerRadius: 20, style: .continuous))
            .accessibilityHidden(true)
    }

    @Environment(\.colorScheme) private var colorScheme

    private var animationURL: URL? {
        let name: String
        switch step {
        case .welcome: name = "TutorialPage"
        case .highlights: name = "TutorialHighlight"
        case .done: name = "TutorialZoom"
        default: return nil
        }
        let mode = colorScheme == .dark ? "DM" : "LM"
        return Bundle.main.url(forResource: "\(name)-\(mode)", withExtension: "mp4")
            ?? Bundle.main.url(forResource: "\(name)-\(mode)", withExtension: "mp4", subdirectory: "Tutorial")
    }
}

/// Dims the screen except for a soft circle around what the tutorial is pointing at. Touches
/// pass straight through, so the spotlit button works as usual.
///
/// In dark mode the screen dims the same way, and `TutorialSpotlightBacking` puts a white circle
/// under the spotlit button, so it sits in a bright circle just as it does on a white page.
/// A spot the tutorial lights up, in full-screen points, round at the ends: a circle around a
/// round button, a capsule around one of the menu's rows.
struct SpotlightHole: Equatable {
    /// The part left undimmed. In dark mode, a bright shape of the same size is drawn under it,
    /// so it looks just like light mode's white page showing through.
    let rect: CGRect
    /// The corners' roundness; nil makes the short ends fully round.
    var cornerRadius: CGFloat? = nil

    /// Around a button, with a little room to spare.
    init(around frame: CGRect, margin: CGFloat = 14, cornerRadius: CGFloat? = nil) {
        rect = frame.insetBy(dx: -margin, dy: -margin)
        self.cornerRadius = cornerRadius
    }

    /// A circle.
    init(center: CGPoint, radius: CGFloat) {
        rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }
}

/// A rounded shape filling `rect`, round at its short ends unless given a corner radius.
private func roundedShape(_ rect: CGRect, cornerRadius: CGFloat? = nil) -> some View {
    RoundedRectangle(cornerRadius: cornerRadius ?? min(rect.width, rect.height) / 2, style: .continuous)
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
}

/// Things in the menu the tutorial can light up, measured where they're drawn.
nonisolated enum TutorialTarget: Hashable, Sendable {
    /// The whole menu, to place the cards just above it.
    case menu
    case bookmark, newList
    /// Any other button in the menu: its rows, the other bookmark lists, Share.
    case menuItem(String)
}

struct TutorialTargetKey: PreferenceKey {
    nonisolated static let defaultValue: [TutorialTarget: CGRect] = [:]
    nonisolated static func reduce(value: inout [TutorialTarget: CGRect], nextValue: () -> [TutorialTarget: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// Reports where this view is on screen, so the tutorial can spotlight it.
    func tutorialTarget(_ target: TutorialTarget) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(key: TutorialTargetKey.self, value: [target: proxy.frame(in: .global)])
            }
        }
    }
}

struct TutorialSpotlight: View {
    let holes: [SpotlightHole]

    var body: some View {
        Color.black
            .opacity(0.5)
            .mask {
                Rectangle()
                    .overlay {
                        ForEach(holes.indices, id: \.self) { index in
                            roundedShape(holes[index].rect, cornerRadius: holes[index].cornerRadius)
                                .blur(radius: 3)
                                .blendMode(.destinationOut)
                        }
                    }
                    .compositingGroup()
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// In dark mode, the bright shape each spotlit button sits in, drawn under the buttons and the
/// prayer list card (and over the page), a soft white like a light mode page.
struct TutorialSpotlightBacking: View {
    let holes: [SpotlightHole]

    var body: some View {
        ZStack {
            ForEach(holes.indices, id: \.self) { index in
                // The same shape and soft edge as the hole, so dark mode matches light mode.
                roundedShape(holes[index].rect, cornerRadius: holes[index].cornerRadius)
                    .foregroundStyle(Color.white.opacity(0.8))
                    .blur(radius: 3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Plays a short silent video over and over, with no controls, like a moving picture. Videos
/// are far smaller than GIFs, so the app stays light.
struct LoopingVideo: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.play(url)
        return view
    }

    func updateUIView(_ view: PlayerView, context: Context) {
        view.play(url)
    }

    static func dismantleUIView(_ view: PlayerView, coordinator: ()) {
        view.stop()
    }

    final class PlayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
        private var player: AVQueuePlayer?
        private var looper: AVPlayerLooper?
        private var url: URL?

        func play(_ url: URL) {
            guard url != self.url else { return }
            stop()
            self.url = url
            let player = AVQueuePlayer()
            // Silent, so it never stops music or a podcast that's playing.
            player.isMuted = true
            player.preventsDisplaySleepDuringVideoPlayback = false
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
            playerLayer.videoGravity = .resizeAspectFill
            playerLayer.player = player
            self.player = player
            player.play()
        }

        func stop() {
            player?.pause()
            looper?.disableLooping()
            looper = nil
            player = nil
            playerLayer.player = nil
            url = nil
        }
    }
}
