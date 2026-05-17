import SwiftUI
import UniformTypeIdentifiers

/// Main application view that switches between library and reader.
struct MainView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.currentBook != nil {
                ReaderContentView()
            } else {
                LibraryView()
            }
        }
        .fileImporter(
            isPresented: $appState.showFileImporter,
            allowedContentTypes: Self.supportedTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    // Start accessing security-scoped resource
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    appState.openBook(url: url)
                }
            case .failure(let error):
                appState.errorMessage = error.localizedDescription
            }
        }
        .alert("Error", isPresented: .init(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )) {
            Button("OK") { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "")
        }
        .overlay {
            if appState.isLoading {
                ZStack {
                    Color.black.opacity(0.3)
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading book...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(30)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    /// Supported file types for the file importer.
    private static let supportedTypes: [UTType] = {
        var types: [UTType] = [.pdf]
        if let mobi = UTType(filenameExtension: "mobi") { types.append(mobi) }
        if let prc = UTType(filenameExtension: "prc") { types.append(prc) }
        if let epub = UTType(filenameExtension: "epub") { types.append(epub) }
        return types
    }()
}
