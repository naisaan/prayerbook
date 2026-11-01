import SwiftUI
import UIKit

/// The page on screen, laid out again at a new text size right away, while the whole book
/// is laid out again behind it. This is what makes the words grow and re-flow under the
/// fingers during a pinch, and the moment a size button is tapped.
struct LivePagePreview {
    let book: Book
    let index: Int

    /// Lays out just the prayer on `page` at `typography`, and finds the page that starts
    /// where `page` starts. Nil for the cover, which doesn't change with the text size.
    init?(of page: BookPage, typography: Typography, metrics: PageMetrics) {
        switch page.content {
        case .cover:
            return nil
        case .sectionTitle:
            book = Book(pages: [page], metrics: metrics, typography: typography)
            index = 0
        case .prayer(let prayerPage):
            let layout = PrayerLayout(
                prayer: prayerPage.prayer,
                isRightToLeft: prayerPage.layout.isRightToLeft,
                typography: typography,
                pageSize: metrics.textRect.size
            )
            let pages = (0..<layout.pageCount).map { number in
                BookPage(
                    sectionName: page.sectionName,
                    sectionFirstPrayerID: page.sectionFirstPrayerID,
                    content: .prayer(PrayerPage(
                        layout: layout,
                        pageInPrayer: number,
                        prayer: prayerPage.prayer,
                        characterRange: layout.characterRange(forPage: number)
                    ))
                )
            }
            guard !pages.isEmpty else { return nil }
            book = Book(pages: pages, metrics: metrics, typography: typography)
            let anchor = BookAnchor(prayerID: prayerPage.prayer.id, characterIndex: prayerPage.characterRange.location)
            index = book.page(for: anchor) ?? 0
        }
    }
}

/// Keeps the last preview, so it's only laid out again when the size actually changes.
final class LivePagePreviewCache {
    private var key: Key?
    private var preview: LivePagePreview?

    private struct Key: Equatable {
        let bookID: UUID
        let page: Int
        let typography: Typography
    }

    func preview(of book: Book, page: Int, typography: Typography) -> LivePagePreview? {
        guard book.pages.indices.contains(page) else { return nil }
        let key = Key(bookID: book.id, page: page, typography: typography)
        if key != self.key {
            self.key = key
            preview = LivePagePreview(of: book.pages[page], typography: typography, metrics: book.metrics)
        }
        return preview
    }
}

/// Shows a preview page, drawn exactly like the pages of the book.
struct LivePageView: UIViewRepresentable {
    let preview: LivePagePreview

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.isUserInteractionEnabled = false
        container.backgroundColor = Typography.pageColor
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        if let shown = container.subviews.first as? BookPageView, shown.shows(preview.book, at: preview.index) { return }
        container.subviews.forEach { $0.removeFromSuperview() }
        let page = BookPageView(book: preview.book, index: preview.index, showsTotal: false, showsNumber: false)
        page.frame = container.bounds
        page.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(page)
    }
}
