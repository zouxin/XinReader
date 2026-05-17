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

            // Book grid (always show, with add card first)
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    // Add book card
                    AddBookCard {
                        appState.showFileImporter = true
                    }

                    ForEach(appState.bookLibrary.recentBooks) { book in
                        BookCard(book: book, onTap: {
                            appState.openBook(url: book.fileURL)
                        }, onRemove: {
                            appState.bookLibrary.remove(book)
                            appState.progressStore.delete(for: book.id)
                        })
                    }
                }
                .padding(24)
            }
        }
    }
}
