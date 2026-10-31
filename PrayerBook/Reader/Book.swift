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
        /// The book's opening page: its title with a verse beneath, and any page the verse
        /// runs on to.
        case opening(PrayerPage)
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

    /// The text on this page, for a prayer or the opening verse.
    var textPage: PrayerPage? {
        switch content {
        case .prayer(let page), .opening(let page): page
        case .sectionTitle: nil
        }
    }
}

/// The large title of a section's title page or of the book's opening page.
enum TitlePage {
    static let bookTitle = "Bahá’í Prayers"

    /// The verse on the opening page, set like a prayer.
    static let openingVerse = Prayer(
        id: -1,
        category: "",
        html: "<p class=\"opening\"><span class=\"versal\">I</span>ntone, O My servant, the verses of God that have been received by thee, as intoned by them who have drawn nigh unto Him, that the sweetness of thy melody may kindle thine own soul, and attract the hearts of all men. Whoso reciteth, in the privacy of his chamber, the verses revealed by God, the scattering angels of the Almighty shall scatter abroad the fragrance of the words uttered by his mouth, and shall cause the heart of every righteous man to throb. Though he may, at first, remain unaware of its effect, yet the virtue of the grace vouchsafed unto him must needs sooner or later exercise its influence upon his soul. Thus have the mysteries of the Revelation of God been decreed by virtue of the Will of Him Who is the Source of power and wisdom.</p>",
        title: bookTitle,
        citation: "",
        author: "Bahá’u’lláh",
        languageCode: "en",
        wordCount: 150,
        searchText: ""
    )

    static func title(_ name: String, typography: Typography) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineHeightMultiple = 1.05
        return NSAttributedString(string: name, attributes: [
            .font: typography.font.uiFont(size: typography.size * 1.9),
            .foregroundColor: Typography.textColor,
            .paragraphStyle: style,
            .kern: -0.4,
        ])
    }

    static func height(of title: NSAttributedString, width: CGFloat) -> CGFloat {
        ceil(title.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).height)
    }

    /// The space between a title and the thin line beneath it.
    static func lineGap(_ typography: Typography) -> CGFloat { typography.size * 1.1 }

    /// Where the opening page's title starts, measured from the top of the text area.
    static func openingTitleOffset(textHeight: CGFloat) -> CGFloat { (textHeight * 0.03).rounded() }

    /// How much of the opening page's text area the title and line take up, above the verse.
    static func openingHeaderHeight(typography: Typography, metrics: PageMetrics) -> CGFloat {
        let textRect = metrics.textRect
        let titleHeight = height(of: title(bookTitle, typography: typography), width: textRect.width)
        return openingTitleOffset(textHeight: textRect.height) + titleHeight + lineGap(typography) + 1 + typography.size * 2
    }
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

    /// The page where a highlight starts.
    func page(of highlight: Highlight) -> Int? {
        guard let first = firstPages[highlight.prayerID], let prayerPage = pages[first].prayerPage else { return nil }
        let start = prayerPage.layout.storageRange(highlight.range).location
        return page(for: BookAnchor(prayerID: highlight.prayerID, characterIndex: start))
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
    ///
    /// `onEarlyBook`, if given, gets a book cut short as soon as it reaches a few prayers past
    /// `earlyPrayerID` (or past the first few prayers), so the reader can start before the
    /// whole book is laid out.
    static func makeBook(
        sections: [BookSection],
        typography: Typography,
        metrics: PageMetrics,
        earlyPrayerID: Int? = nil,
        onEarlyBook: ((Book) -> Void)? = nil
    ) async -> Book? {
        var onEarlyBook = onEarlyBook
        /// Prayers left to lay out before the early book goes out. Counting starts at the
        /// early prayer, or right away if there isn't one.
        var earlyCountdown: Int? = earlyPrayerID == nil ? 4 : nil
        // The book opens with its own title page, like a printed book, with a verse beneath the title.
        var pages: [BookPage] = []
        let opening = PrayerLayout(
            prayer: TitlePage.openingVerse,
            isRightToLeft: false,
            typography: typography,
            pageSize: metrics.textRect.size,
            firstPageTop: TitlePage.openingHeaderHeight(typography: typography, metrics: metrics)
        )
        for index in 0..<opening.pageCount {
            let page = PrayerPage(layout: opening, pageInPrayer: index, prayer: TitlePage.openingVerse, characterRange: opening.characterRange(forPage: index))
            pages.append(BookPage(sectionName: TitlePage.bookTitle, sectionFirstPrayerID: nil, content: .opening(page)))
        }
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
                if prayer.id == earlyPrayerID { earlyCountdown = 3 }
                if let countdown = earlyCountdown, let send = onEarlyBook {
                    if countdown <= 0 {
                        send(Book(pages: pages, metrics: metrics, typography: typography))
                        onEarlyBook = nil
                        // Let the reader's page appear before laying out the rest.
                        await Task.yield()
                    } else {
                        earlyCountdown = countdown - 1
                    }
                }
                if count.isMultiple(of: 4) {
                    await Task.yield()
                    if Task.isCancelled { return nil }
                }
            }
        }
        return Book(pages: pages, metrics: metrics, typography: typography)
    }
}
