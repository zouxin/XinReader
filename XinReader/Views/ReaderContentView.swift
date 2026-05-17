import SwiftUI

/// The main reader layout with sidebar (TOC) and content pane.
struct ReaderContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar: Table of Contents
            SidebarView(
                chapters: appState.chapters,
                selectedChapter: $appState.selectedChapter
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 350)
        } detail: {
            // Detail: Book content (WKWebView for HTML, PDFView for PDF)
            if let book = appState.currentBook {
                ReaderView(book: book)
            } else {
                Text("No book loaded")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ReaderToolbar()
            }
        }
    }
}
