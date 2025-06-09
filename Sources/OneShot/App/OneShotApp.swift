import SwiftUI
import KeyboardShortcuts

@main
struct OneShotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    let container = DefaultServiceContainer()
    
    init() {
        setupAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(container.resolve(AppStateManager.self))
                .environmentObject(container.resolve(LLMProviderService.self))
                .environmentObject(container.resolve(ContextManager.self))
                .environmentObject(container.resolve(SessionManager.self))
                .environmentObject(container.resolve(DiagnosticsService.self))
                .onReceive(NotificationCenter.default.publisher(for: .showOneShotWindow)) { _ in
                    showMainWindow()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified)
        .commands {
            GlobalCommands()
        }
        
        Settings {
            SettingsView()
                .environmentObject(container.resolve(AppStateManager.self))
                .environmentObject(container.resolve(LLMProviderService.self))
                .environmentObject(container.resolve(DiagnosticsService.self))
        }
    }
    
    private func setupAppearance() {
        // Configure global app appearance
        NSWindow.allowsAutomaticWindowTabbing = false
    }
    
    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        
        // Bring the main window to front
        if let window = NSApp.windows.first(where: { $0.title == "OneShot" || $0.contentView?.subviews.first is NSHostingView<ContentView> }) {
            window.makeKeyAndOrderFront(nil)
            window.center()
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupGlobalHotkey()
        setupMenuBar()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup before termination
        NotificationCenter.default.post(name: .appWillTerminate, object: nil)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false // Keep app running when all windows are closed
    }
    
    private func setupGlobalHotkey() {
        KeyboardShortcuts.onKeyUp(for: .showOneShot) {
            NotificationCenter.default.post(name: .showOneShotWindow, object: nil)
        }
    }
    
    private func setupMenuBar() {
        // Configure application menu
        if let mainMenu = NSApp.mainMenu {
            // Add custom menu items if needed
        }
    }
}

// MARK: - Global Commands

struct GlobalCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Chat") {
                NotificationCenter.default.post(name: .newChatRequested, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)
        }
        
        CommandGroup(after: .importExport) {
            Button("Show OneShot") {
                NotificationCenter.default.post(name: .showOneShotWindow, object: nil)
            }
            .keyboardShortcut(.space, modifiers: [.command, .shift])
        }
        
        CommandMenu("Context") {
            Button("Add File...") {
                NotificationCenter.default.post(name: .addFileContextRequested, object: nil)
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            
            Button("Add Folder...") {
                NotificationCenter.default.post(name: .addFolderContextRequested, object: nil)
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
            
            Divider()
            
            Button("Clear Context") {
                NotificationCenter.default.post(name: .clearContextRequested, object: nil)
            }
            .keyboardShortcut("k", modifiers: [.command, .option])
        }
        
        CommandMenu("View") {
            Button("Show Diagnostics") {
                NotificationCenter.default.post(name: .showDiagnosticsRequested, object: nil)
            }
            .keyboardShortcut("d", modifiers: [.command, .option])
            
            Button("Toggle Sidebar") {
                NotificationCenter.default.post(name: .toggleSidebarRequested, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .control])
        }
    }
}

// MARK: - Keyboard Shortcuts Extension

extension KeyboardShortcuts.Name {
    static let showOneShot = Self("showOneShot", default: .init(.space, modifiers: [.command, .shift]))
}

// MARK: - Notification Names

extension Notification.Name {
    static let showOneShotWindow = Notification.Name("showOneShotWindow")
    static let newChatRequested = Notification.Name("newChatRequested")
    static let addFileContextRequested = Notification.Name("addFileContextRequested")
    static let addFolderContextRequested = Notification.Name("addFolderContextRequested")
    static let clearContextRequested = Notification.Name("clearContextRequested")
    static let showDiagnosticsRequested = Notification.Name("showDiagnosticsRequested")
    static let toggleSidebarRequested = Notification.Name("toggleSidebarRequested")
    static let appWillTerminate = Notification.Name("appWillTerminate")
}