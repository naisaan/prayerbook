import SwiftUI

enum ReaderSheet: String, Identifiable {
    case contents, highlights, search, settings, languages
    var id: String { rawValue }
}

/// The main screen: the book, with a floating menu button in the corner.
struct ReaderView: View {
    @Environment(Library.self) private var library
    @Environment(ReaderSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var book: Book?
    @State private var currentPage = 0
    @State private var showsControls = true
    @State private var menuOpen = false
    @State private var sheet: ReaderSheet?
    @State private var bookmarkFeedback = 0
    @State private var namingList = false
    @State private var newListName = ""
    @State private var showsSplash = true
    @State private var splashOpacity = 1.0
    @State private var showsPrayerList = false
    /// The reader has turned past the cover, or started pulling it, at least once.
    @AppStorage("hasTurnedCover") private var hasTurnedCover = false
    /// The tutorial has been finished or skipped once. Until then, the menu button and the
    /// prayer list wait hidden, and fade in with the tutorial on the first page after the cover.
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false
    @State private var tutorialStep: TutorialStep?
    /// The tutorial's last card tipping over and falling off the screen, like a canceled alert.
    @State private var tutorialFalling = false
    /// Where the menu button and the menu's bookmark buttons are, for the tutorial's spotlight.
    @State private var tutorialTargets: [TutorialTarget: CGRect] = [:]
    /// The text size a pinch would set, while fingers are on the screen.
    @State private var pinchSize: CGFloat?
    /// The text size when the pinch started.
    @State private var pinchStartSize: CGFloat = 0
    @State private var previewCache = LivePagePreviewCache()

    var body: some View {
        GeometryReader { proxy in
            let metrics = PageMetrics(
                size: CGSize(
                    width: proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing,
                    height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
                ),
                safeArea: UIEdgeInsets(
                    top: proxy.safeAreaInsets.top,
                    left: proxy.safeAreaInsets.leading,
                    bottom: proxy.safeAreaInsets.bottom,
                    right: proxy.safeAreaInsets.trailing
                )
            )

            ZStack(alignment: .bottomTrailing) {
                Color(uiColor: Typography.pageColor)
                    .ignoresSafeArea()

                if let book, !book.pages.isEmpty {
                    PageCurlView(
                        book: book,
                        currentPage: $currentPage,
                        isReversed: bookIsRightToLeft,
                        showsTotal: showsControls,
                        reduceMotion: reduceMotion,
                        onCenterTap: toggleControls,
                        onPageTurn: hideControls,
                        onOpenPrayer: { prayerID in
                            hideControls()
                            if let page = book.firstPage(of: prayerID) { currentPage = page }
                        }
                    )
                    .id(reduceMotion)
                    .ignoresSafeArea()
                    .overlay {
                        // Until the book is laid out again at a new text size, the page on
                        // screen is laid out at that size right away, so the words follow the
                        // fingers (or the buttons).
                        if let preview = livePreview(of: book) {
                            LivePageView(preview: preview)
                                .ignoresSafeArea()
                                .allowsHitTesting(false)
                        }
                    }
                    .simultaneousGesture(pinchToResize, isEnabled: !isOnCover && !menuOpen)
                    // Once the reader starts pulling the cover themselves, the curl hint has
                    // done its job and never comes back, even if they let the page fall back.
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 8)
                            .onChanged { _ in if !hasTurnedCover { hasTurnedCover = true } },
                        isEnabled: isOnCover && !hasTurnedCover
                    )
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if menuOpen {
                    // Tapping anywhere outside the menu closes it.
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture { setMenu(open: false) }
                }

                if isOnCover {
                    // The cover is just the cover: no menu or prayer list. Until the reader
                    // turns it the first time, its corner is pulled in now and then to show
                    // there's a page beneath.
                    if !hasTurnedCover, let book, book.pages.count > 1 {
                        CoverCurlHint(book: book, isRightToLeft: bookIsRightToLeft)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                    }
                } else if book != nil {
                    Group {
                        controls
                        if settings.showsPrayerList {
                            PrayerListNote(
                                isOpen: $showsPrayerList,
                                isHidden: menuOpen,
                                safeAreaTop: metrics.safeArea.top,
                                allowsTyping: tutorialStep != .prayerListOpen
                            )
                                .transition(.opacity)
                        }
                    }
                    .opacity(controlsWaitForTutorial ? 0 : 1)
                    .allowsHitTesting(!controlsWaitForTutorial)
                }

                if let holes = tutorialSpotlight(in: metrics), !isOnCover {
                    TutorialSpotlight(holes: holes)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }

                if let tutorialStep, !isOnCover {
                    TutorialCard(step: tutorialStep, onNext: advanceTutorial)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: cardAlignment(for: tutorialStep))
                        .padding(.top, tutorialStep.placement == .top ? 8 : 0)
                        // At the bottom, above the menu button.
                        .padding(.bottom, tutorialStep.placement == .bottom ? 72 : 0)
                        // Done: it tumbles off the bottom, exactly like Cancel on the name alerts.
                        .rotationEffect(.degrees(tutorialFalling ? -270 : 0))
                        .offset(x: tutorialFalling ? -20 : 0, y: tutorialFalling ? metrics.size.height + 300 : 0)
                        .allowsHitTesting(!tutorialFalling)
                        // Each step blurs into the next, the way the system swaps content.
                        .id(tutorialStep)
                        .transition(.blurReplace)
                }

                if showsSplash {
                    // Flattened into one layer first, so the background and the star fade together.
                    SplashView()
                        .compositingGroup()
                        .opacity(splashOpacity)
                        .allowsHitTesting(splashOpacity > 0)
                        .zIndex(1)
                }
            }
            .task(id: shouldStartTutorial) {
                guard shouldStartTutorial, tutorialStep == nil else { return }
                // Let the page finish turning first.
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled, shouldStartTutorial, tutorialStep == nil else { return }
                withAnimation(.easeInOut(duration: 0.8)) {
                    showsControls = true
                    tutorialStep = .welcome
                }
            }
            .onChange(of: showsPrayerList) { _, isOpen in
                // Opening the prayer list moves its step on, like tapping Next.
                // Opening it shows how to put it back; putting it back moves on to the end.
                if isOpen && tutorialStep == .prayerList {
                    withAnimation(.smooth(duration: 0.35)) { tutorialStep = .prayerListOpen }
                } else if !isOpen && tutorialStep == .prayerListOpen {
                    withAnimation(.smooth(duration: 0.35)) { tutorialStep = .done }
                }
            }
            .onPreferenceChange(TutorialTargetKey.self) { targets in
                tutorialTargets = targets
            }
            .onChange(of: menuOpen) { _, isOpen in
                // Tapping the menu button is how the first step moves on.
                if isOpen && tutorialStep == .welcome {
                    withAnimation(.smooth(duration: 0.35)) { tutorialStep = .menu }
                }
            }
            .task(id: BookKey(metrics: metrics, typography: settings.typography, languages: library.enabledLanguageCodes)) {
                await rebuildBook(metrics: metrics)
            }
        }
        .ignoresSafeArea(.keyboard)
        .sheet(item: $sheet) { sheet in
            sheetContent(sheet)
                .environment(library)
                .environment(settings)
        }
        .onChange(of: currentPage) { _, page in
            pageDidChange(page)
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .task {
            // Fade the splash screen out as soon as the book is ready.
            while book == nil {
                try? await Task.sleep(for: .milliseconds(50))
            }
            withAnimation(.easeOut(duration: 0.25)) {
                splashOpacity = 0
            } completion: {
                showsSplash = false
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: bookmarkFeedback)
        .fallingTextFieldAlert(
            "New Bookmark List",
            isPresented: $namingList,
            text: $newListName,
            message: "What would you like to call this list?",
            confirm: "Add"
        ) {
            library.addBookmarkList(named: newListName)
        }
    }

    // MARK: Text size

    /// Two fingers pinch the text bigger or smaller. One finger is left alone, so turning pages,
    /// selecting, highlighting, and notes work as before.
    private var pinchToResize: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.02)
            .onChanged { value in
                if pinchSize == nil {
                    pinchStartSize = settings.textSize
                    hideControls()
                }
                let range = ReaderSettings.textSizeRange
                let size = min(max(pinchStartSize * value.magnification, range.lowerBound), range.upperBound)
                pinchSize = size
            }
            .onEnded { _ in
                if let pinchSize { settings.setTextSize(pinchSize) }
                pinchSize = nil
            }
    }

    /// The page on screen at the size being pinched (or just chosen with the buttons), while
    /// the book itself is still laid out at the old size. Nil once they match.
    private func livePreview(of book: Book) -> LivePagePreview? {
        var typography = settings.typography
        if let pinchSize {
            // Half point steps: smooth to the eye, and not a new layout for every tiny move.
            typography.size = (pinchSize * 2).rounded() / 2
        }
        guard typography.size != book.typography.size else { return nil }
        typography.font = book.typography.font
        typography.dropCap = book.typography.dropCap
        typography.justified = book.typography.justified
        return previewCache.preview(of: book, page: currentPage, typography: typography)
    }

    // MARK: Controls


    private var controls: some View {
        VStack(alignment: .trailing, spacing: 12) {
            if menuOpen {
                ReaderMenu(
                    progress: progress,
                    highlightCount: visibleHighlightCount,
                    isBookmarked: isCurrentBookmarked,
                    shareText: currentPrayer?.shareText,
                    onSelect: { choice in
                        setMenu(open: false)
                        sheet = choice
                    },
                    onToggleBookmark: toggleBookmarkAction,
                    currentPrayerID: toggleBookmarkAction == nil ? nil : currentPrayer?.id,
                    onToggleList: { listID in
                        guard let prayer = currentPrayer else { return }
                        library.toggleBookmark(prayer.id, in: listID)
                        bookmarkFeedback += 1
                    },
                    onAddList: {
                        newListName = ""
                        namingList = true
                    },
                    // During the tutorial the menu is only to look at: its pages don't open.
                    optionsDisabled: tutorialStep != nil
                )
                .transition(menuTransition)
            }

            // The menu button only shows with the other controls. On a bookmarked page a large
            // red bookmark takes its place while the controls are hidden, and turns back into
            // the menu button (with a small badge) when tapped.
            ZStack {
                // While the menu is open the button steps aside; tapping anywhere closes the menu.
                MenuButton {
                    setMenu(open: true)
                }
                .tutorialTarget(.menuButton)
                .opacity(menuButtonShows && !menuOpen ? 1 : 0)
                .allowsHitTesting(menuButtonShows && !menuOpen)
                .overlay(alignment: .topTrailing) {
                    if let currentBookmarkColor, menuButtonShows && !menuOpen {
                        BookmarkBadge(color: currentBookmarkColor)
                            .offset(x: 6, y: -6)
                            .allowsHitTesting(false)
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                    }
                }
                if let currentBookmarkColor, !menuButtonShows {
                    BookmarkBadge(size: 52, color: currentBookmarkColor)
                        .onTapGesture(perform: toggleControls)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.3, bounce: 0), value: currentBookmarkColor)
            .animation(.spring(duration: 0.3, bounce: 0), value: menuButtonShows)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 4)
    }

    /// The menu button shows with the other controls, or all the time if the reader chose
    /// Always Show Menu in General Settings.
    private var menuButtonShows: Bool {
        showsControls || settings.alwaysShowsMenu || tutorialStep == .welcome
    }

    // MARK: Tutorial

    /// On the first page after the cover, the first time, with nothing else in the way.
    private var shouldStartTutorial: Bool {
        !hasSeenTutorial && book != nil && !isOnCover && sheet == nil && !showsSplash
    }

    /// Before the tutorial starts, the menu button and prayer list stay hidden, so they can
    /// fade in with it.
    private var controlsWaitForTutorial: Bool {
        !hasSeenTutorial && tutorialStep == nil
    }

    private func advanceTutorial() {
        guard let step = tutorialStep else { return }
        guard let next = step.next else {
            withAnimation(.easeIn(duration: 0.55)) {
                tutorialFalling = true
            } completion: {
                // Already off the screen, so it goes without another animation.
                hasSeenTutorial = true
                tutorialStep = nil
                tutorialFalling = false
            }
            return
        }
        // The menu's steps are done: close it to show the page again.
        if !next.usesMenu && menuOpen { setMenu(open: false) }
        withAnimation(.smooth(duration: 0.35)) { tutorialStep = next }
    }

    private func cardAlignment(for step: TutorialStep) -> Alignment {
        switch step.placement {
        case .top: .top
        case .center: .center
        case .bottom: .bottom
        }
    }

    /// What the tutorial lights up, in full-screen points: the menu button on the first step,
    /// the bookmark and + buttons on the bookmarks step, and the prayer list's card on its step.
    private func tutorialSpotlight(in metrics: PageMetrics) -> [CGRect]? {
        let size = metrics.size
        let safe = metrics.safeArea
        switch tutorialStep {
        case .welcome:
            // Measured, or else where the 52-point button sits: 20 in from the side, 4 up.
            let fallback = CGRect(x: size.width - safe.right - 72, y: size.height - safe.bottom - 56, width: 52, height: 52)
            return [tutorialTargets[.menuButton] ?? fallback]
        case .bookmarks:
            let holes = [tutorialTargets[.bookmark], tutorialTargets[.newList]].compactMap { $0 }
            return holes.isEmpty ? nil : holes
        case .prayerList where settings.showsPrayerList:
            // The part of the tilted card that peeks in from the top right corner.
            return [CGRect(x: size.width - 56, y: safe.top - 18, width: 76, height: 76)]
        default:
            return nil
        }
    }

    private func finishTutorial() {
        if menuOpen { setMenu(open: false) }
        hasSeenTutorial = true
        withAnimation(.easeOut(duration: 0.3)) { tutorialStep = nil }
    }

    /// Nil on a section title page, where there's no prayer to bookmark.
    private var toggleBookmarkAction: (() -> Void)? {
        guard let prayer = currentPrayer else { return nil }
        return {
            library.toggleBookmark(prayer.id)
            bookmarkFeedback += 1
        }
    }

    /// The color of the badge on this page, if the prayer is in any bookmark list.
    private var currentBookmarkColor: BookmarkColor? {
        currentPrayer.flatMap { library.bookmarkColor(for: $0.id) }
    }

    /// Highlights in the languages that are turned on.
    private var visibleHighlightCount: Int {
        Highlights.shared.all.filter { library.prayersByID[$0.prayerID] != nil }.count
    }

    private var isCurrentBookmarked: Bool {
        currentPrayer.map { library.isBookmarked($0.id) } ?? false
    }

    private var menuTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .scale(scale: 0.8, anchor: .bottomTrailing).combined(with: .opacity)
    }

    private var menuAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0)
    }

    private func setMenu(open: Bool) {
        withAnimation(menuAnimation) {
            menuOpen = open
        }
    }

    private func toggleControls() {
        withAnimation(.easeOut(duration: 0.2)) {
            showsControls.toggle()
            if !showsControls { menuOpen = false }
        }
    }

    private func hideControls() {
        guard showsControls else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            showsControls = false
            menuOpen = false
        }
    }

    // MARK: Sheets

    @ViewBuilder
    private func sheetContent(_ sheet: ReaderSheet) -> some View {
        switch sheet {
        case .contents:
            ContentsView(currentPrayerID: currentPrayer?.id, onOpen: openPrayer)
        case .highlights:
            HighlightsView(
                onOpen: { highlight in
                    closeSheetAndTurn(to: book?.page(of: highlight))
                },
                onOpenPrayer: openPrayer
            )
        case .search:
            SearchView(
                onOpen: { prayerID, query in
                    closeSheetAndTurn(to: book?.page(of: prayerID, matching: query))
                },
                onOpenPrayer: openPrayer
            )
        case .settings:
            SettingsSheet(progress: progress)
        case .languages:
            LanguagesView()
        }
    }

    private func openPrayer(_ prayerID: Int) {
        closeSheetAndTurn(to: book?.firstPage(of: prayerID))
    }

    /// Closes the sheet, then turns to the page once the sheet is out of the way.
    private func closeSheetAndTurn(to page: Int?) {
        sheet = nil
        menuOpen = false
        showsControls = false
        guard let page else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            currentPage = page
        }
    }

    // MARK: Book

    /// The book turns like a Persian book (pages in reverse order) only when Persian is the only
    /// language turned on. With any other language on too, it opens the Western way.
    private var bookIsRightToLeft: Bool {
        library.enabledLanguageCodes == ["fa"]
    }

    private var isOnCover: Bool {
        guard let book, book.pages.indices.contains(currentPage) else { return false }
        if case .cover = book.pages[currentPage].content { return true }
        return false
    }

    private var currentPrayer: Prayer? {
        guard let book, book.pages.indices.contains(currentPage) else { return nil }
        return book.pages[currentPage].prayer
    }

    /// The share of the book's prayers that have been read to the end.
    private var progress: Int {
        guard let book else { return 0 }
        return library.percentRead(of: book.prayerIDs)
    }

    private func pageDidChange(_ page: Int) {
        if page > 0 && !hasTurnedCover { hasTurnedCover = true }
        guard let book, let anchor = book.anchor(forPage: page) else { return }
        settings.lastPrayerID = anchor.prayerID
        settings.lastCharacterIndex = anchor.characterIndex
        if let prayerPage = book.pages[page].prayerPage {
            library.noteOpened(prayerPage.prayer.id)
            if prayerPage.isLastPage {
                library.markRead(prayerPage.prayer.id)
            }
        }
    }

    /// Paginates the book again, keeping the reader on the same spot in the same prayer.
    private func rebuildBook(metrics: PageMetrics) async {
        guard metrics.size.width > 0, metrics.size.height > 0 else { return }

        let anchor = book?.anchor(forPage: currentPage)
            ?? settings.lastPrayerID.map { BookAnchor(prayerID: $0, characterIndex: settings.lastCharacterIndex) }

        if book != nil {
            // Wait a moment, so quick taps on the size buttons lay the book out once, not
            // once per tap. Another change in the meantime cancels this one.
            try? await Task.sleep(for: .milliseconds(180))
            if Task.isCancelled { return }
        }

        // Show the reader's page as soon as it's laid out, and finish the rest of the book
        // behind it.
        guard let newBook = await Paginator.makeBook(
            sections: library.sections,
            typography: settings.typography,
            metrics: metrics,
            earlyPrayerID: anchor?.prayerID,
            onEarlyBook: { early in show(early, at: anchor) }
        ) else { return }

        show(newBook, at: book?.anchor(forPage: currentPage) ?? anchor)
    }

    private func show(_ newBook: Book, at anchor: BookAnchor?) {
        let page = anchor.flatMap { newBook.page(for: $0) } ?? 0
        book = newBook
        currentPage = min(page, max(newBook.pages.count - 1, 0))
    }
}

/// Holds the launch screen in place until the book is ready: the same star on the same color,
/// so it looks like one splash screen rather than two. Like the launch screen, which iOS
/// draws before the app starts, it follows the phone's light or dark mode, not the app's.
private struct SplashView: View {
    private let colorScheme: ColorScheme = {
        let screen = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.screen }.first
        return screen?.traitCollection.userInterfaceStyle == .dark ? .dark : .light
    }()

    var body: some View {
        ZStack {
            colorScheme == .dark ? Color.black : Color.white
            // At its own size, exactly like the launch screen.
            Image("Splash")
                .accessibilityLabel("Bahá’í Prayer Book")
        }
        .environment(\.colorScheme, colorScheme)
        .ignoresSafeArea()
    }
}

/// Everything that requires the book to be paginated again when it changes.
private struct BookKey: Equatable {
    let metrics: PageMetrics
    let typography: Typography
    let languages: [String]
}
