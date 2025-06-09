import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppStateManager
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var contextManager: ContextManager
    
    @State private var selectedSidebarItem: SidebarItem = .chat
    @State private var showingSidebar = true
    @State private var showingDiagnostics = false
    @State private var showingOnboarding = false
    
    var body: some View {
        NavigationSplitView(
            sidebar: {
                if showingSidebar {
                    SidebarView(selectedItem: $selectedSidebarItem)
                        .frame(minWidth: 250)
                }
            },
            detail: {
                mainContent
            }
        )
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            if !appState.isOnboardingComplete {
                showingOnboarding = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newChatRequested)) { _ in
            selectedSidebarItem = .chat
            createNewChat()
        }
        .onReceive(NotificationCenter.default.publisher(for: .addFileContextRequested)) { _ in
            addFileContext()
        }
        .onReceive(NotificationCenter.default.publisher(for: .addFolderContextRequested)) { _ in
            addFolderContext()
        }
        .onReceive(NotificationCenter.default.publisher(for: .clearContextRequested)) { _ in
            contextManager.clearContext()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showDiagnosticsRequested)) { _ in
            selectedSidebarItem = .diagnostics
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebarRequested)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                showingSidebar.toggle()
            }
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView()
                .environmentObject(appState)
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        switch selectedSidebarItem {
        case .chat:
            ChatView()
                .environmentObject(sessionManager)
                .environmentObject(contextManager)
                
        case .sessions:
            SessionsView()
                .environmentObject(sessionManager)
                
        case .diagnostics:
            DiagnosticsView()
                .environmentObject(appState)
                
        case .settings:
            SettingsView()
                .environmentObject(appState)
        }
    }
    
    private func createNewChat() {
        // Create a new session if we have a configured provider
        guard let provider = (sessionManager as? DefaultLLMProviderService)?.currentProvider else {
            // Show configuration needed alert
            return
        }
        
        let session = sessionManager.createSession(
            title: nil,
            provider: provider.id,
            model: provider.supportedModels.first?.id ?? "default"
        )
        sessionManager.setCurrentSession(session)
    }
    
    private func addFileContext() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.text, .sourceCode, .json, .data]
        
        if panel.runModal() == .OK {
            Task {
                for url in panel.urls {
                    appState.addRecentFile(url)
                    try? await contextManager.addFileContext(at: url)
                }
            }
        }
    }
    
    private func addFolderContext() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        
        if panel.runModal() == .OK, let url = panel.url {
            appState.addRecentFile(url)
            Task {
                try? await contextManager.addDirectoryContext(at: url)
            }
        }
    }
}

// MARK: - Sidebar

enum SidebarItem: String, CaseIterable, Identifiable {
    case chat = "chat"
    case sessions = "sessions"
    case diagnostics = "diagnostics"
    case settings = "settings"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .chat: return "Chat"
        case .sessions: return "Sessions"
        case .diagnostics: return "Diagnostics"
        case .settings: return "Settings"
        }
    }
    
    var icon: String {
        switch self {
        case .chat: return "message"
        case .sessions: return "folder"
        case .diagnostics: return "chart.bar"
        case .settings: return "gear"
        }
    }
}

struct SidebarView: View {
    @Binding var selectedItem: SidebarItem
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var appState: AppStateManager
    
    var body: some View {
        List(selection: $selectedItem) {
            Section("Main") {
                ForEach(SidebarItem.allCases) { item in
                    NavigationLink(value: item) {
                        Label(item.title, systemImage: item.icon)
                    }
                    .tag(item)
                }
            }
            
            if selectedItem == .sessions {
                Section("Recent Sessions") {
                    ForEach(sessionManager.recentSessions.prefix(5)) { session in
                        SessionRowView(session: session)
                            .onTapGesture {
                                Task {
                                    if let fullSession = try? sessionManager.getSession(id: session.id) {
                                        sessionManager.setCurrentSession(fullSession)
                                        selectedItem = .chat
                                    }
                                }
                            }
                    }
                }
            }
            
            if !appState.recentFiles.isEmpty {
                Section("Recent Files") {
                    ForEach(appState.recentFiles.prefix(5), id: \.self) { url in
                        Label(url.lastPathComponent, systemImage: "doc.text")
                            .onTapGesture {
                                Task {
                                    try? await (contextManager as? DefaultContextManager)?.addFileContext(at: url)
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("OneShot")
    }
}

struct SessionRowView: View {
    let session: SessionSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(session.title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
            
            HStack {
                Text(session.provider)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(session.lastModified, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Preview

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppStateManager(container: DefaultServiceContainer().setupTestContainer()))
            .environmentObject(MockLLMProviderService())
            .environmentObject(MockContextManager())
            .environmentObject(MockSessionManager())
            .environmentObject(MockDiagnosticsService())
    }
}
#endif