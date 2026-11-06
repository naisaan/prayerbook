import SwiftUI
import UIKit

/// The steps of the tutorial shown the first time someone opens the book.
enum TutorialStep: Int, CaseIterable {
    case welcome, menu, bookmarks, highlights, prayerList, prayerListOpen, done

    var title: LocalizedStringKey? {
        self == .welcome ? "Welcome to Bahá’í Prayer Book." : nil
    }

    var message: LocalizedStringKey {
        switch self {
        case .welcome:
            "Just like a physical Prayer Book you can bookmark pages, highlight and make notes, and more. To start tap on the menu button on the bottom right corner."
        case .menu:
            "Here you can see the Contents of your Prayer Book, Search for Prayers, choose other languages, and settings."
        case .bookmarks:
            "To Bookmark a Prayer Press the Bookmark button. To create a Bookmark List, press the plus and name your new bookmarks list."
        case .highlights:
            "To Highlight and create Notes select text and then press Highlight or Add Note"
        case .prayerList:
            "At the top right corner there is Prayer List. You can write things you want to remember and create checklists to quickly reference at any time."
        case .prayerListOpen:
            "Feel free to throw this back when you’re done"
        case .done:
            "Feel free to pinch to make the text bigger or smaller and swipe to turn the page.\nI hope you enjoy this app!"
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
        .frame(maxWidth: 360, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 32))
        // Floats above the page.
        .shadow(color: .black.opacity(0.3), radius: 30, y: 12)
        .padding(.horizontal, 20)
    }

    /// The step's screenshot, from the asset catalog as "Tutorial1" to "Tutorial6". Until one is
    /// added there, a placeholder of the same size shows where it will go.
    @ViewBuilder
    private var screenshot: some View {
        let name = "Tutorial\(step.dot + 1)"
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(uiColor: .tertiarySystemFill))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if UIImage(named: name) != nil {
                    Image(name)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                }
            }
            .clipShape(.rect(cornerRadius: 20, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Dims the screen except for a soft circle around what the tutorial is pointing at. Touches
/// pass straight through, so the spotlit button works as usual.
///
/// In dark mode the screen dims the same way, and `TutorialSpotlightBacking` puts a white circle
/// under the spotlit button, so it sits in a bright circle just as it does on a white page.
/// A round spot the tutorial lights up, in full-screen points.
struct SpotlightHole: Equatable {
    let center: CGPoint
    let radius: CGFloat
    /// How much smaller the bright circle under it is in dark mode: snug around a button, but
    /// the full size around the prayer list's card.
    var backingInset: CGFloat = 10

    /// A circle around a button, with a little room to spare.
    init(around frame: CGRect) {
        center = CGPoint(x: frame.midX, y: frame.midY)
        radius = max(frame.width, frame.height) / 2 + 14
    }

    init(center: CGPoint, radius: CGFloat, backingInset: CGFloat = 10) {
        self.center = center
        self.radius = radius
        self.backingInset = backingInset
    }
}

/// Things in the menu the tutorial can light up, measured where they're drawn.
nonisolated enum TutorialTarget: Hashable, Sendable {
    case bookmark, newList
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
                            let hole = holes[index]
                            Circle()
                                .frame(width: hole.radius * 2, height: hole.radius * 2)
                                .blur(radius: 3)
                                .position(hole.center)
                                .blendMode(.destinationOut)
                        }
                    }
                    .compositingGroup()
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// In dark mode, the bright circle each spotlit button sits in, drawn under the buttons and the
/// prayer list card (and over the page), the same white as a light mode page.
struct TutorialSpotlightBacking: View {
    let holes: [SpotlightHole]

    var body: some View {
        ZStack {
            ForEach(holes.indices, id: \.self) { index in
                let hole = holes[index]
                // Snug around the button, so circles side by side don't run together, and a
                // little softer than pure white.
                Circle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: (hole.radius - hole.backingInset) * 2, height: (hole.radius - hole.backingInset) * 2)
                    .blur(radius: 2)
                    .position(hole.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
