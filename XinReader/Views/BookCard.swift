import SwiftUI

/// A book card in the library grid.
struct BookCard: View {
    let book: Book
    let onTap: () -> Void
    var onRemove: (() -> Void)?

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Cover image or placeholder
                Group {
                    if let coverData = book.coverImageData,
                       let nsImage = NSImage(data: coverData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        ZStack {
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            VStack(spacing: 4) {
                                Image(systemName: "book.fill")
                                    .font(.title)
                                    .foregroundColor(.white.opacity(0.8))
                                Text(book.title.prefix(20))
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.9))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .padding(.horizontal, 8)
                            }
                        }
                    }
                }
                .frame(width: 140, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

                // Title and author
                VStack(spacing: 2) {
                    Text(book.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    Text(book.author)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(width: 140)
            }
        }
        .buttonStyle(.plain)
    }
}

/// A card with a "+" icon to add new books, same size as BookCard covers.
struct AddBookCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.gray.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [6]))
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.05))
                        )
                    Image(systemName: "plus")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(.gray.opacity(0.6))
                }
                .frame(width: 140, height: 200)

                Text("Add Book")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 140)
            }
        }
        .buttonStyle(.plain)
    }
}
