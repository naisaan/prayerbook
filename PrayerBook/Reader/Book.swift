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

struct BookPage {
    let layout: PrayerLayout
    let pageInPrayer: Int
    let prayer: Prayer
    let sectionName: String
    let characterRange: NSRange
}

/// The whole prayer book, split into pages. Each prayer starts on a new page.
final class Book: Identifiable {
    let id = UUID()
    let pages: [BookPage]
    let metrics: PageMetrics
    private let firstPages: [Int: Int]

    init(pages: [BookPage], metrics: PageMetrics) {
        self.pages = pages
        self.metrics = metrics
        var firstPages: [Int: Int] = [:]
        for (index, page) in pages.enumerated() where firstPages[page.prayer.id] == nil {
            firstPages[page.prayer.id] = index
        }
        self.firstPages = firstPages
    }

    func firstPage(of prayerID: Int) -> Int? {
        firstPages[prayerID]
    }

    /// The page of a prayer that contains the given character.
    func page(of prayerID: Int, characterIndex: Int) -> Int? {
        guard var index = firstPages[prayerID] else { return nil }
        while index + 1 < pages.count,
              pages[index + 1].prayer.id == prayerID,
              pages[index + 1].characterRange.location <= characterIndex {
            index += 1
        }
        return index
    }

    /// The page of a prayer where a search query first appears.
    func page(of prayerID: Int, matching query: String) -> Int? {
        guard let first = firstPages[prayerID] else { return nil }
        let word = query.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? query
        let text = pages[first].layout.storage.string as NSString
        let match = text.range(of: word, options: [.caseInsensitive, .diacriticInsensitive])
        guard match.location != NSNotFound else { return first }
        return page(of: prayerID, characterIndex: match.location)
    }
}

enum Paginator {
    /// Lays out every prayer of every section. Pauses now and then so the app stays responsive,
    /// and gives up (returns nil) if the settings change while it's working.
    static func makeBook(sections: [BookSection], typography: Typography, metrics: PageMetrics) async -> Book? {
        var pages: [BookPage] = []
        var count = 0
        for section in sections {
            for prayer in section.prayers {
                let layout = PrayerLayout(
                    prayer: prayer,
                    isRightToLeft: section.language.isRightToLeft,
                    typography: typography,
                    pageSize: metrics.textRect.size
                )
                for index in 0..<layout.pageCount {
                    pages.append(BookPage(
                        layout: layout,
                        pageInPrayer: index,
                        prayer: prayer,
                        sectionName: section.name,
                        characterRange: layout.characterRange(forPage: index)
                    ))
                }
                count += 1
                if count.isMultiple(of: 10) {
                    await Task.yield()
                    if Task.isCancelled { return nil }
                }
            }
        }
        return Book(pages: pages, metrics: metrics)
    }
}
