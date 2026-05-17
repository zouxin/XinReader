import SwiftUI
import AppKit

/// AppDelegate to ensure the app activates and shows its window
/// when launched via `swift run` (no .app bundle).
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Activate the app and bring window to front
        NSApplication.shared.activate(ignoringOtherApps: true)
        // Set activation policy to regular (shows in Dock)
        NSApplication.shared.setActivationPolicy(.regular)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

@main
struct XinReaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 600)
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
