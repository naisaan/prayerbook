import SwiftUI

/// The little card peeking in from the top corner of the page, shaped like an app icon.
/// Tapping it zooms the prayer list out of it.
struct PrayerListCard: View {
    static let size: CGFloat = 80

    var body: some View {
        Image("PrayerListCard")
            .resizable()
            .scaledToFill()
            .frame(width: Self.size, height: Self.size)
            .clipShape(Self.shape)
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
    }

    /// The rounded square of an app icon.
    static let shape = RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
}

/// The people and things the reader wants to pray for. Swipe down to toss it back into
/// its corner.
struct PrayerListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var newIntention = ""
    @FocusState private var isAdding: Bool

    private var list: PrayerList { .shared }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Add a person or intention", text: $newIntention)
                        .focused($isAdding)
                        .submitLabel(.done)
                        .onSubmit {
                            list.add(newIntention)
                            newIntention = ""
                            // Stay ready for the next one.
                            isAdding = true
                        }
                }

                if !list.intentions.isEmpty {
                    Section {
                        ForEach(list.intentions) { intention in
                            Text(intention.text)
                        }
                        .onDelete { list.remove(atOffsets: $0) }
                        .onMove { list.move(fromOffsets: $0, toOffset: $1) }
                    }
                }
            }
            .overlay {
                if list.intentions.isEmpty {
                    ContentUnavailableView(
                        "Your Prayer List Is Empty",
                        systemImage: "heart.text.square",
                        description: Text("Add the people and things in your life you’d like to pray for.")
                    )
                    .allowsHitTesting(false)
                }
            }
            .navigationTitle("Prayer List")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !list.intentions.isEmpty { EditButton() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton { dismiss() }
                }
            }
        }
    }
}
