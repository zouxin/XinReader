import SwiftUI
import WebKit
import PDFKit

/// The main reader view that switches between rendering engines based on content type.
struct ReaderView: View {
    let book: ParsedBook
    @EnvironmentObject var appState: AppState

    var body: some View {
        switch book.content {
        case .html(let htmlContent):
            WebContentView(
                htmlContent: htmlContent.htmlString,
                images: htmlContent.images,
                settings: appState.settingsStore.settings,
                selectedChapter: $appState.selectedChapter,
                onScrollChange: { percent, anchor in
                    appState.saveProgress(scrollPercentage: percent, chapterAnchor: anchor)
                },
                initialScrollPercent: loadInitialScroll()
            )

        case .pdf(let pdfContent):
            PDFContentView(
                document: pdfContent.document,
                settings: appState.settingsStore.settings,
                selectedChapter: $appState.selectedChapter,
                onPageChange: { page, total in
                    let percent = total > 0 ? Double(page) / Double(total) : 0
                    appState.saveProgress(
                        scrollPercentage: percent,
                        chapterAnchor: nil,
                        currentPage: page
                    )
                },
                initialPage: loadInitialPage()
            )
        }
    }

    private func loadInitialScroll() -> Double {
        guard let bookMeta = appState.currentBookMeta,
              let progress = appState.loadProgress(for: bookMeta.id) else {
            return 0.0
        }
        return progress.scrollPercentage
    }

    private func loadInitialPage() -> Int {
        guard let bookMeta = appState.currentBookMeta,
              let progress = appState.loadProgress(for: bookMeta.id) else {
            return 0
        }
        return progress.currentPage ?? 0
    }
}
