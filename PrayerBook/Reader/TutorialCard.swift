import SwiftUI
import UIKit

/// The steps of the tutorial shown the first time someone opens the book.
enum TutorialStep: Int, CaseIterable {
    case welcome, menu, bookmarks, highlights, prayerList, done

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
        case .done:
            "If you want to make the text bigger or smaller, just pinch and zoom.\nI hope you enjoy this app!"
        }
    }

    /// The steps about the menu sit at the top, out of the way of the open menu.
    var sitsAtTop: Bool { self == .menu || self == .bookmarks }

    /// The steps that point at something on screen (the open menu, the prayer list) have no
    /// picture, so the card stays small and out of the way.
    var hasPicture: Bool { !sitsAtTop && self != .prayerList }

    var next: TutorialStep? { TutorialStep(rawValue: rawValue + 1) }
}

/// One step of the tutorial, on the same surface as the menu's buttons.
struct TutorialCard: View {
    let step: TutorialStep
    let onNext: () -> Void
    let onSkip: () -> Void

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
            // Without a picture the text starts at the top, so it keeps clear of the close button.
            .padding(.trailing, step.hasPicture ? 0 : 36)

            ZStack {
                // One dot per step, like a page control, centered; the current one is solid.
                HStack(spacing: 8) {
                    ForEach(TutorialStep.allCases, id: \.self) { dot in
                        Circle()
                            .fill(Color.primary.opacity(dot == step ? 1 : 0.25))
                            .frame(width: 7, height: 7)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel(Text("\(step.rawValue + 1) of \(TutorialStep.allCases.count)"))

                HStack {
                    Spacer(minLength: 0)
                    if step == .welcome {
                        // The menu button itself is the way on: tapping it opens the next step.
                        Image(systemName: "arrow.down.right")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.tint)
                            .symbolEffect(.bounce, options: .repeating)
                            .accessibilityHidden(true)
                    } else {
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
        .overlay(alignment: .topTrailing) {
            // Apple's round close button, like on its sheets. Closing ends the tutorial.
            Button(action: onSkip) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .padding(24)
            .accessibilityLabel("Close")
        }
        // Floats above the page.
        .shadow(color: .black.opacity(0.3), radius: 30, y: 12)
        .padding(.horizontal, 20)
    }

    /// The step's screenshot, from the asset catalog as "Tutorial1" to "Tutorial6". Until one is
    /// added there, a placeholder of the same size shows where it will go.
    @ViewBuilder
    private var screenshot: some View {
        let name = "Tutorial\(step.rawValue + 1)"
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
