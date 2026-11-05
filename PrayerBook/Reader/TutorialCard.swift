import SwiftUI

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
            "I hope you enjoy this app!"
        }
    }

    var systemImage: String {
        switch self {
        case .welcome: "book.closed"
        case .menu: "list.bullet"
        case .bookmarks: "bookmark"
        case .highlights: "highlighter"
        case .prayerList: "checklist"
        case .done: "heart"
        }
    }

    /// The steps about the menu sit at the top, out of the way of the open menu.
    var sitsAtTop: Bool { self == .menu || self == .bookmarks }

    var next: TutorialStep? { TutorialStep(rawValue: rawValue + 1) }
}

/// One step of the tutorial, on the same surface as the menu's buttons.
struct TutorialCard: View {
    let step: TutorialStep
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: step.systemImage)
                .font(.title2)
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            if let title = step.title {
                Text(title)
                    .font(.headline)
            }
            Text(step.message)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Text("\(step.rawValue + 1) of \(TutorialStep.allCases.count)")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if step != .done {
                    Button("Skip", action: onSkip)
                        .buttonStyle(.bordered)
                }
                if step == .welcome {
                    // The menu button itself is the way on: tapping it opens the next step.
                    Image(systemName: "arrow.down.right")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.tint)
                        .symbolEffect(.bounce, options: .repeating)
                        .accessibilityHidden(true)
                } else {
                    Button(step == .done ? "Done" : "Next", action: onNext)
                        .buttonStyle(.borderedProminent)
                }
            }
            .buttonBorderShape(.capsule)
            .padding(.top, 6)
        }
        .padding(20)
        .frame(maxWidth: 380, alignment: .leading)
        .menuSurface(RoundedRectangle(cornerRadius: 28, style: .continuous), interactive: false)
        .padding(.horizontal, 20)
    }
}
