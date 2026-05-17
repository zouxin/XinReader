import SwiftUI
import AppKit

/// AppDelegate to ensure the app activates and shows its window
/// when launched via `swift run` (no .app bundle).
class AppDelegate: NSObject, NSApplicationDelegate {
    weak var appState: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.setActivationPolicy(.regular)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

/// Intercepts window close: if reading a book, return to library instead of quitting.
class WindowCloseInterceptor: NSObject, NSWindowDelegate {
    weak var appState: AppState?

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if let appState = appState, appState.currentBook != nil {
            // Reading a book — go back to library
            DispatchQueue.main.async {
                appState.lastReadBook = appState.currentBookMeta
                appState.currentBook = nil
                appState.currentBookMeta = nil
                appState.chapters = []
                appState.selectedChapter = nil
            }
            return false // Don't close the window
        }
        return true // In library — close normally
    }
}

@main
struct XinReaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    private let windowInterceptor = WindowCloseInterceptor()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 600)
                .background(WindowAccessor(appState: appState, interceptor: windowInterceptor))
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open File...") {
                    appState.showFileImporter = true
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandGroup(after: .textFormatting) {
                Divider()
                Button("Increase Font Size") {
                    appState.settingsStore.increaseFontSize()
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Decrease Font Size") {
                    appState.settingsStore.decreaseFontSize()
                }
                .keyboardShortcut("-", modifiers: .command)

                Divider()

                Menu("Theme") {
                    ForEach(ReaderSettings.ReaderTheme.allCases) { theme in
                        Button(theme.displayName) {
                            appState.settingsStore.settings.theme = theme
                        }
                    }
                }
            }
        }
    }
}

/// Helper view to access the NSWindow and install our close interceptor.
struct WindowAccessor: NSViewRepresentable {
    let appState: AppState
    let interceptor: WindowCloseInterceptor

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                interceptor.appState = appState
                window.delegate = interceptor
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Ensure delegate stays set (SwiftUI may recreate the window)
        DispatchQueue.main.async {
            if let window = nsView.window, !(window.delegate is WindowCloseInterceptor) {
                interceptor.appState = appState
                window.delegate = interceptor
            }
        }
    }
}
