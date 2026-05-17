import SwiftUI

/// Toolbar controls for the reader.
struct ReaderToolbar: View {
    @EnvironmentObject var appState: AppState

    @State private var showAppearanceSheet = false

    var body: some View {
        // Back to Library
        Button {
            appState.lastReadBook = appState.currentBookMeta
            appState.currentBook = nil
            appState.currentBookMeta = nil
            appState.chapters = []
            appState.selectedChapter = nil
        } label: {
            Label("Library", systemImage: "books.vertical")
        }
        .help("返回书库")

        Divider()

        // Font size decrease
        Button {
            appState.settingsStore.decreaseFontSize()
        } label: {
            Label("Decrease Font", systemImage: "textformat.size.smaller")
        }
        .help("减小字号 (⌘-)")

        // Font size increase
        Button {
            appState.settingsStore.increaseFontSize()
        } label: {
            Label("Increase Font", systemImage: "textformat.size.larger")
        }
        .help("增大字号 (⌘+)")

        Divider()

        // Theme cycle
        Button {
            appState.settingsStore.nextTheme()
        } label: {
            Label("Theme", systemImage: themeIcon)
        }
        .help("切换主题")

        // Appearance settings
        Button {
            showAppearanceSheet = true
        } label: {
            Label("Appearance", systemImage: "slider.horizontal.3")
        }
        .help("外观设置")
        .popover(isPresented: $showAppearanceSheet) {
            AppearanceSheet()
                .frame(width: 320, height: 400)
        }

        Divider()

        // Open file
        Button {
            appState.showFileImporter = true
        } label: {
            Label("Open", systemImage: "doc.badge.plus")
        }
        .help("打开文件 (⌘O)")
    }

    private var themeIcon: String {
        switch appState.settingsStore.settings.theme {
        case .light: return "sun.max"
        case .sepia: return "cup.and.saucer"
        case .dark: return "moon"
        case .eyeProtection: return "eye"
        }
    }
}
