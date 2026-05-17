import SwiftUI
import AppKit

/// AppDelegate to ensure the app activates and shows its window
/// when launched via `swift run` (no .app bundle).
class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowDelegateHelper = WindowDelegateHelper()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.setActivationPolicy(.regular)

        // Watch for new windows and install our delegate on them
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow,
                  !(window.delegate is WindowDelegateHelper) else { return }
            self?.windowDelegateHelper.originalDelegates[window] = window.delegate
            window.delegate = self?.windowDelegateHelper
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
}

/// Intercepts window close and miniaturizes to Dock instead.
class WindowDelegateHelper: NSObject, NSWindowDelegate {
    var originalDelegates: [NSWindow: NSWindowDelegate?] = [:]

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.miniaturize(nil)
        return false   // prevent actual close
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
