import SwiftUI

/// Library view showing all books that have been opened.
struct LibraryView: View {
    @EnvironmentObject var appState: AppState

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("XinReader")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Your book library")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    appState.showFileImporter = true
                } label: {
                    Label("Open Book", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)

            Divider()

            if appState.bookLibrary.books.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)

                    Text("No books yet")
                        .font(.title2)
                        .foregroundColor(.secondary)

                    Text("Click \"Open Book\" or press ⌘O to open a book file")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button {
                        appState.showFileImporter = true
                    } label: {
                        Label("Open Book", systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Book grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(appState.bookLibrary.recentBooks) { book in
                            BookCard(book: book) {
                                appState.openBook(url: book.fileURL)
                            }
                        }
                    }
                    .padding(24)
                }
            }
        }
    }
}
