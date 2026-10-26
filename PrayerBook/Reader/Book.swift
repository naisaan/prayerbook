import UIKit

/// Where things go on a page: the running header, the text and the page number.
struct PageMetrics: Equatable {
    var size: CGSize
    var safeArea: UIEdgeInsets

    static let sideMargin: CGFloat = 30

    var textRect: CGRect {
        let top = safeArea.top + 44
        let bottom = safeArea.bottom + 44
        return CGRect(
            x: Self.sideMargin,
            y: top,
            width: max(size.width - Self.sideMargin * 2, 1),
            height: max(size.height - top - bottom, 1)
        )
    }

    var headerRect: CGRect {
        CGRect(x: Self.sideMargin, y: safeArea.top + 8, width: max(size.width - Self.sideMargin * 2, 1), height: 20)
    }

    var footerRect: CGRect {
        CGRect(x: Self.sideMargin, y: size.height - safeArea.bottom - 30, width: max(size.width - Self.sideMargin * 2, 1), height: 20)
    }
}

/// One page of a prayer.
struct PrayerPage {
    let layout: PrayerLayout
    let pageInPrayer: Int
    let prayer: Prayer
    let characterRange: NSRange

    var isLastPage: Bool { pageInPrayer == layout.pageCount - 1 }
}

struct BookPage {
    enum Content {
        /// A page with just the section's name, before its first prayer.
        case sectionTitle
        case prayer(PrayerPage)
    }

    let sectionName: String
    /// The first prayer of this page's section, used to find the section title page again.
    let sectionFirstPrayerID: Int?
    let content: Content

    var prayerPage: PrayerPage? {
        if case .prayer(let page) = content { return page }
        return nil
    }

    var prayer: Prayer? { prayerPage?.prayer }
}

/// A spot in the book that survives paginating again: a prayer and how far into it.
/// A character index of -1 means the title page of that prayer's section.
struct BookAnchor {
    let prayerID: Int
    let characterIndex: Int
}

/// The whole prayer book, split into pages. Each section starts with a title page and each
/// prayer starts on a new page.
final class Book: Identifiable {
    let id = UUID()
    let pages: [BookPage]
    let metrics: PageMetrics
    let typography: Typography
    /// Every prayer in the book, in order.
    let prayerIDs: [Int]
    private let firstPages: [Int: Int]

    init(pages: [BookPage], metrics: PageMetrics, typography: Typography) {
        self.pages = pages
        self.metrics = metrics
        self.typography = typography
        var firstPages: [Int: Int] = [:]
        var prayerIDs: [Int] = []
        for (index, page) in pages.enumerated() {
            if let prayer = page.prayer, firstPages[prayer.id] == nil {
                firstPages[prayer.id] = index
                prayerIDs.append(prayer.id)
            }
        }
        self.firstPages = firstPages
        self.prayerIDs = prayerIDs
    }

    func firstPage(of prayerID: Int) -> Int? {
        firstPages[prayerID]
    }

    func anchor(forPage index: Int) -> BookAnchor? {
        guard pages.indices.contains(index) else { return nil }
        let page = pages[index]
        if let prayerPage = page.prayerPage {
            return BookAnchor(prayerID: prayerPage.prayer.id, characterIndex: prayerPage.characterRange.location)
        }
        return page.sectionFirstPrayerID.map { BookAnchor(prayerID: $0, characterIndex: -1) }
    }

    func page(for anchor: BookAnchor) -> Int? {
        guard var index = firstPages[anchor.prayerID] else { return nil }
        if anchor.characterIndex < 0 {
            if index > 0, case .sectionTitle = pages[index - 1].content { return index - 1 }
            return index
        }
        while index + 1 < pages.count,
              let next = pages[index + 1].prayerPage,
              next.prayer.id == anchor.prayerID,
              next.characterRange.location <= anchor.characterIndex {
            index += 1
        }
        return index
    }

    /// The page of a prayer where a search query first appears.
    func page(of prayerID: Int, matching query: String) -> Int? {
        guard let first = firstPages[prayerID], let prayerPage = pages[first].prayerPage else { return nil }
        let word = query.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? query
        let text = prayerPage.layout.storage.string as NSString
        let match = text.range(of: word, options: [.caseInsensitive, .diacriticInsensitive])
        guard match.location != NSNotFound else { return first }
        return page(for: BookAnchor(prayerID: prayerID, characterIndex: match.location))
    }
}

enum Paginator {
    /// Lays out every prayer of every section. Pauses now and then so the app stays responsive,
    /// and gives up (returns nil) if the settings change while it's working.
    static func makeBook(sections: [BookSection], typography: Typography, metrics: PageMetrics) async -> Book? {
        // The book opens with its own title page, like the title page of a printed book.
        var pages: [BookPage] = [BookPage(sectionName: "Bahá’í Prayers", sectionFirstPrayerID: nil, content: .sectionTitle)]
        var count = 0
        for section in sections {
            let firstPrayerID = section.prayers.first?.id
            pages.append(BookPage(sectionName: section.name, sectionFirstPrayerID: firstPrayerID, content: .sectionTitle))

            for prayer in section.prayers {
                let layout = PrayerLayout(
                    prayer: prayer,
                    isRightToLeft: section.language.isRightToLeft,
                    typography: typography,
                    pageSize: metrics.textRect.size
                )
                for index in 0..<layout.pageCount {
                    let prayerPage = PrayerPage(
                        layout: layout,
                        pageInPrayer: index,
                        prayer: prayer,
                        characterRange: layout.characterRange(forPage: index)
                    )
                    pages.append(BookPage(sectionName: section.name, sectionFirstPrayerID: firstPrayerID, content: .prayer(prayerPage)))
                }
                count += 1
                if count.isMultiple(of: 10) {
                    await Task.yield()
                    if Task.isCancelled { return nil }
                }
            }
        }
        return Book(pages: pages, metrics: metrics, typography: typography)
    }
}
