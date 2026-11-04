import SwiftUI

/// The five steps to prayer, from a letter written on behalf of Shoghi Effendi, with the
/// Universal House of Justice's note about them. Shown exactly as written, in English.
struct FiveStepsView: View {
    @Environment(ReaderSettings.self) private var settings

    static let title = "Five Steps to Prayer"

    private static let steps = [
        "Use these five steps if we have a problem of any kind for which we desire a solution, or wish help.",
        "Pray and meditate about it. Use the prayers of the Manifestations, as they have the greatest power. Learn to remain in the silence of contemplation for a few moments. During this deepest communion take the next step.",
        "Arrive at a decision and hold to this. This decision is usually born in a flash at the close or during the contemplation. It may seem almost impossible of accomplishment, but if it seems to be an answer to prayer or a way of solving the problem, then immediately take the next step.",
        "Have determination to carry the decision through. Many fail here. The decision, budding into determination, is blighted and instead becomes a wish or a vague longing. When determination is born, immediately take the next step.",
        "Have faith and confidence, that the Power of the Holy Spirit will flow through you, the right way will appear, the door will open, the right message, the right principle or the right book will be given to you. Have confidence, and the right thing will come to meet your need. Then as you rise from prayer take immediately the fifth step.",
        "Act as though it had all been answered. Then act with tireless, ceaseless energy. And, as you act, you yourself will become a magnet which will attract more power to your being, until you become an unobstructed channel for the Divine Power to flow through you.",
    ]
    private static let stepsSource = "-Letter written on behalf of Shoghi Effendi"

    private static let note = "When asked about these notes, Shoghi Effendi replied, in letters written by his secretary on his behalf, that the notes should be regarded as “personal suggestions,” that he considered them to be “quite sound,” but that the friends need not adopt them “strictly and universally.” The House of Justice feels that they may be helpful to you."
    private static let noteSource = "-Letter written on behalf of the Universal House of Justice"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(Self.steps, id: \.self) { paragraph in
                    Text(verbatim: paragraph)
                }
                source(Self.stepsSource)

                Divider()
                    .padding(.vertical, 8)

                Text(verbatim: Self.note)
                source(Self.noteSource)
            }
            .font(settings.font.font(size: 18))
            .lineSpacing(4)
            .padding(24)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(Text(verbatim: Self.title))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func source(_ text: String) -> some View {
        Text(verbatim: text)
            .italic()
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
