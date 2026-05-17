import SwiftUI
import Combine

/// Global application state.
final class AppState: ObservableObject {
    @Published var currentBook: ParsedBook?
    @Published var currentBookMeta: Book?
    @Published var chapters: [Chapter] = []
    @Published var selectedChapter: Chapter?
    @Published var showFileImporter: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var currentPageIndex: Int = 0
    @Published var totalPageCount: Int = 1
    @Published var chapterPageMap: [String: Int] = [:]  // chapterAnchor → page number

    let settingsStore = SettingsStore()
    let progressStore = ProgressStore()
    let bookLibrary = BookLibrary()

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Forward settingsStore changes to trigger view updates
        settingsStore.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.objectWillChange.send()
            }
        }.store(in: &cancellables)
    }

    /// Open and parse a book file (MOBI, EPUB, or PDF)
    func openBook(url: URL) {
        isLoading = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let parsed = try BookParser.parse(fileURL: url)

                DispatchQueue.main.async {
                    self?.currentBook = parsed
                    self?.chapters = parsed.chapters

                    // Create or update book metadata
                    let bookMeta = Book(
                        fileURL: url,
                        title: parsed.title,
                        author: parsed.author,
                        publisher: parsed.publisher,
                        coverImageData: parsed.coverImage,
                        format: BookFormat(fromExtension: url.pathExtension),
                        addedDate: Date(),
                        lastOpenedDate: Date()
                    )
                    self?.currentBookMeta = bookMeta
                    self?.bookLibrary.addOrUpdate(bookMeta)
                    self?.isLoading = false

                    // Select first chapter if available
                    if let first = parsed.chapters.first {
                        self?.selectedChapter = first
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.errorMessage = error.localizedDescription
                    self?.isLoading = false
                }
            }
        }
    }

    /// Save current reading progress
    func saveProgress(scrollPercentage: Double, chapterAnchor: String?, currentPage: Int? = nil) {
        guard let bookMeta = currentBookMeta else { return }

        let progress = ReadingProgress(
            bookID: bookMeta.id,
            scrollPercentage: scrollPercentage,
            currentChapterAnchor: chapterAnchor,
            currentPage: currentPage,
            lastReadDate: Date()
        )
        progressStore.save(progress)
    }

    /// Load reading progress for a book
    func loadProgress(for bookID: UUID) -> ReadingProgress? {
        return progressStore.load(for: bookID)
    }
}
