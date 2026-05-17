import SwiftUI

/// Library view with tag sidebar and book grid.
struct LibraryView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTag: String? = "全部"
    @State private var showNewTagAlert = false
    @State private var newTagName = ""

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)
    ]

    var body: some View {
        NavigationSplitView {
            // Left sidebar: tags
            TagSidebarView(
                tags: appState.bookLibrary.tags,
                selectedTag: $selectedTag,
                onAddTag: { showNewTagAlert = true },
                onDeleteTag: { tag in
                    appState.bookLibrary.removeTag(tag)
                }
            )
            .navigationSplitViewColumnWidth(min: 140, ideal: 180, max: 240)
        } detail: {
            // Right: book grid
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text(selectedTag ?? "全部")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("\(filteredBooks.count) books")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Continue reading last book
                    if let lastBook = appState.lastReadBook {
                        Button {
                            appState.openBook(url: lastBook.fileURL)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "book.fill")
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Continue Reading")
                                        .font(.system(size: 11))
                                    Text(lastBook.title.prefix(20))
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(24)

                Divider()

                // Book grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        AddBookCard {
                            appState.showFileImporter = true
                        }

                        ForEach(filteredBooks) { book in
                            BookCard(book: book, onTap: {
                                appState.openBook(url: book.fileURL)
                            }, onRemove: {
                                appState.bookLibrary.remove(book)
                                appState.progressStore.delete(for: book.id)
                            })
                            .contextMenu {
                                // Tag assignment menu
                                Menu("Set Tag") {
                                    ForEach(appState.bookLibrary.tags, id: \.self) { tag in
                                        Button {
                                            if book.tags.contains(tag) {
                                                appState.bookLibrary.removeTag(tag, from: book.id)
                                            } else {
                                                appState.bookLibrary.addTag(tag, to: book.id)
                                            }
                                        } label: {
                                            HStack {
                                                Text(tag)
                                                if book.tags.contains(tag) {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }

                                    if appState.bookLibrary.tags.isEmpty {
                                        Text("No tags yet")
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Divider()

                                Button {
                                    NSWorkspace.shared.selectFile(book.fileURL.path, inFileViewerRootedAtPath: book.fileURL.deletingLastPathComponent().path)
                                } label: {
                                    Label("Show in Finder", systemImage: "folder")
                                }

                                Divider()

                                Button("Remove from Library", role: .destructive) {
                                    appState.bookLibrary.remove(book)
                                    appState.progressStore.delete(for: book.id)
                                }
                            }
                        }
                    }
                    .padding(24)
                }
            }
        }
        .alert("New Tag", isPresented: $showNewTagAlert) {
            TextField("Tag name", text: $newTagName)
            Button("Add") {
                appState.bookLibrary.addTag(newTagName)
                newTagName = ""
            }
            Button("Cancel", role: .cancel) {
                newTagName = ""
            }
        } message: {
            Text("Enter a name for the new tag")
        }
    }

    /// Books filtered by the currently selected tag.
    private var filteredBooks: [Book] {
        switch selectedTag {
        case "全部", nil:
            return appState.bookLibrary.recentBooks
        case "未分类":
            return appState.bookLibrary.uncategorizedBooks
        default:
            return appState.bookLibrary.books(withTag: selectedTag!)
        }
    }
}

// MARK: - Tag Sidebar

struct TagSidebarView: View {
    let tags: [String]
    @Binding var selectedTag: String?
    var onAddTag: () -> Void
    var onDeleteTag: (String) -> Void

    var body: some View {
        List(selection: $selectedTag) {
            Section {
                Label("全部", systemImage: "books.vertical")
                    .tag("全部")
                Label("未分类", systemImage: "tray")
                    .tag("未分类")
            }

            Section("Tags") {
                ForEach(tags, id: \.self) { tag in
                    Label(tag, systemImage: "tag")
                        .tag(tag)
                        .contextMenu {
                            Button("Delete Tag", role: .destructive) {
                                onDeleteTag(tag)
                            }
                        }
                }

                Button(action: onAddTag) {
                    Label("New Tag...", systemImage: "plus")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.sidebar)
    }
}
