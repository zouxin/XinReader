import SwiftUI
import PDFKit

/// NSViewRepresentable wrapping PDFKit's PDFView for PDF rendering.
struct PDFContentView: NSViewRepresentable {
    let document: PDFDocument
    let settings: ReaderSettings
    @Binding var selectedChapter: Chapter?
    var onPageChange: ((Int, Int) -> Void)?
    var initialPage: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = settings.theme.nsBackgroundColor

        // Restore initial page
        if initialPage > 0, let page = document.page(at: initialPage) {
            pdfView.go(to: page)
        }

        // Observe page changes
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        context.coordinator.pdfView = pdfView
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        // Update background when theme changes
        pdfView.backgroundColor = settings.theme.nsBackgroundColor

        // Navigate to selected chapter's page
        if let chapter = selectedChapter,
           let pageIdx = chapter.pageIndex,
           chapter != context.coordinator.lastSelectedChapter,
           let page = document.page(at: pageIdx) {
            context.coordinator.lastSelectedChapter = chapter
            pdfView.go(to: page)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject {
        var parent: PDFContentView
        weak var pdfView: PDFView?
        var lastSelectedChapter: Chapter?

        init(_ parent: PDFContentView) {
            self.parent = parent
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = pdfView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document else { return }

            let pageIndex = document.index(for: currentPage)
            let total = document.pageCount
            parent.onPageChange?(pageIndex, total)
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}
