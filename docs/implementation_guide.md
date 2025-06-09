# OneShot Implementation Guide

## Development Setup

### Prerequisites
- Xcode 15+
- macOS 13.0+ for development
- Swift 5.9+
- Git for version control

### Initial Project Setup

1. **Create Xcode Project**
```bash
# Create new macOS app project in Xcode
# Choose SwiftUI interface, Core Data storage
# Set minimum deployment target to macOS 13.0
```

2. **Core Dependencies**
```swift
// Package.swift dependencies (if using SPM)
dependencies: [
    .package(url: "https://github.com/vapor/multipart-kit.git", from: "4.0.0"),
    .package(url: "https://github.com/apple/swift-crypto.git", from: "2.0.0"),
    .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "1.0.0")
]
```

## Implementation Priority Order

### Phase 1: Core MVP (Weeks 1-4)

#### Week 1: Project Foundation
1. **Set up basic app structure**
```swift
// 1. Create dependency container
// 2. Set up Core Data stack
// 3. Basic SwiftUI views
// 4. Service protocol definitions
```

2. **Core Data Schema Implementation**
```swift
// OneShot.xcdatamodeld entities:
// - ConversationEntity
// - MessageEntity  
// - ContextItemEntity
// Set up relationships and constraints
```

3. **Basic UI Layout**
```swift
// ContentView with:
// - Sidebar for conversations
// - Main chat area
// - Input field
// - Basic styling
```

#### Week 2: LLM Integration
1. **OpenAI Provider Implementation**
```swift
class OpenAIProvider: LLMProvider {
    private let baseURL = "https://api.openai.com/v1"
    private let session = URLSession.shared
    
    func sendMessage(
        _ message: String,
        context: [ContextItem],
        model: LLMModel,
        parameters: LLMParameters
    ) async throws -> AsyncStream<MessageChunk> {
        // Implementation with streaming support
        AsyncStream { continuation in
            Task {
                let request = buildRequest(message, context, model, parameters)
                let (data, response) = try await session.data(for: request)
                
                // Parse streaming response
                for line in data.split(separator: "\n".data(using: .utf8)![0]) {
                    if let chunk = parseSSELine(line) {
                        continuation.yield(chunk)
                    }
                }
                continuation.finish()
            }
        }
    }
}
```

2. **Basic Chat Functionality**
```swift
// ChatViewModel implementation
// Message sending and receiving
// Basic error handling
```

#### Week 3: Context System Foundation
1. **File Context Implementation**
```swift
class DefaultContextManager: ContextManager {
    func resolveReference(_ reference: String) async throws -> ContextItem {
        // Parse @file:/path/to/file references
        // Read file content
        // Calculate token count
        // Return ContextItem
    }
    
    func startMonitoring(path: String) {
        // Set up FSEventStream for file changes
        let stream = FSEventStreamCreate(
            nil, // allocator
            eventCallback, // callback
            &context, // context
            [path] as CFArray, // paths
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0, // latency
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents)
        )
        FSEventStreamStart(stream)
    }
}
```

2. **Drag & Drop Support**
```swift
struct ChatView: View {
    var body: some View {
        VStack {
            // Chat messages
            messagesList
            
            // Input area with drop support
            inputArea
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    handleFileDrop(providers)
                    return true
                }
        }
    }
    
    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, error in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    Task { @MainActor in
                        await viewModel.addFileContext(url)
                    }
                }
            }
        }
        return true
    }
}
```

#### Week 4: Basic Settings & Polish
1. **Settings Implementation**
```swift
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        TabView {
            ProvidersSettingsView()
                .tabItem { Label("Providers", systemImage: "brain") }
            
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gear") }
        }
        .frame(width: 600, height: 400)
    }
}
```

2. **Keychain Integration**
```swift
class KeychainService {
    func set(_ value: String, for key: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else { return nil }
        
        return String(data: data, encoding: .utf8)
    }
}
```

### Phase 2: Enhanced Features (Weeks 5-8)

#### Week 5: Ollama Integration
```swift
class OllamaProvider: LLMProvider {
    private let baseURL = "http://localhost:11434"
    
    func getModels() async throws -> [LLMModel] {
        let url = URL(string: "\(baseURL)/api/tags")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(OllamaModelsResponse.self, from: data)
        
        return response.models.map { ollamaModel in
            LLMModel(
                id: ollamaModel.name,
                name: ollamaModel.name,
                contextWindow: 4096, // Default, could be model-specific
                inputPricing: nil, // Local model, no pricing
                outputPricing: nil,
                capabilities: [.chat, .codeGeneration]
            )
        }
    }
    
    func sendMessage(
        _ message: String,
        context: [ContextItem],
        model: LLMModel,
        parameters: LLMParameters
    ) async throws -> AsyncStream<MessageChunk> {
        let requestBody = OllamaRequest(
            model: model.id,
            messages: buildMessages(message, context),
            stream: true,
            options: OllamaOptions(
                temperature: parameters.temperature,
                top_p: parameters.topP
            )
        )
        
        return AsyncStream { continuation in
            Task {
                do {
                    let url = URL(string: "\(baseURL)/api/chat")!
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONEncoder().encode(requestBody)
                    
                    let (asyncBytes, _) = try await URLSession.shared.bytes(for: request)
                    
                    for try await line in asyncBytes.lines {
                        if let data = line.data(using: .utf8),
                           let response = try? JSONDecoder().decode(OllamaResponse.self, from: data) {
                            let chunk = MessageChunk(
                                content: response.message.content,
                                isComplete: response.done
                            )
                            continuation.yield(chunk)
                            
                            if response.done {
                                break
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
```

#### Week 6: Global Hotkey & UI Polish
1. **Global Hotkey Implementation**
```swift
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let showOneShot = Self("showOneShot", default: .init(.space, modifiers: [.command, .shift]))
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        KeyboardShortcuts.onKeyUp(for: .showOneShot) {
            NotificationCenter.default.post(name: .showOneShotWindow, object: nil)
        }
    }
}

// In main app
struct OneShotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var isWindowVisible = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: .showOneShotWindow)) { _ in
                    showWindow()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
    
    private func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        // Bring window to front and focus input
    }
}
```

2. **Advanced UI Components**
```swift
struct MessageView: View {
    let message: DisplayMessage
    @State private var isHovering = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            roleAvatar
            
            VStack(alignment: .leading, spacing: 8) {
                // Message header
                messageHeader
                
                // Message content with syntax highlighting
                if message.role == .assistant {
                    MarkdownView(content: message.content)
                        .textSelection(.enabled)
                } else {
                    Text(message.content)
                        .textSelection(.enabled)
                }
                
                // Context indicators
                if !message.contextItems.isEmpty {
                    ContextIndicatorsView(items: message.contextItems)
                }
            }
            
            Spacer()
            
            // Action buttons (copy, export, etc.)
            if isHovering {
                messageActions
            }
        }
        .padding(.vertical, 8)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

struct ContextIndicatorsView: View {
    let items: [ContextItem]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items, id: \.id) { item in
                    ContextChip(item: item)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

struct ContextChip: View {
    let item: ContextItem
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconForContextType(item.type))
                .foregroundColor(.secondary)
                .font(.caption)
            
            Text(item.name)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}
```

#### Week 7: Diagnostics & Performance
1. **Real-time Metrics Dashboard**
```swift
class DiagnosticsViewModel: ObservableObject {
    @Published var currentMetrics = AppMetrics.empty
    @Published var providerMetrics: [String: ProviderMetrics] = [:]
    @Published var recentRequests: [RequestMetric] = []
    
    private let diagnosticsService: DiagnosticsService
    private var timer: Timer?
    
    init(diagnosticsService: DiagnosticsService) {
        self.diagnosticsService = diagnosticsService
        startMetricsUpdates()
    }
    
    private func startMetricsUpdates() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                self.currentMetrics = self.diagnosticsService.metrics
                self.providerMetrics = self.diagnosticsService.getProviderMetrics()
                self.recentRequests = self.diagnosticsService.getRecentRequests(limit: 20)
            }
        }
    }
}

struct DiagnosticsView: View {
    @StateObject private var viewModel = DiagnosticsViewModel()
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Real-time metrics cards
                MetricsCardsView(metrics: viewModel.currentMetrics)
                
                // Provider health status
                ProviderHealthView(providers: viewModel.providerMetrics)
                
                // Recent requests chart
                RequestsChartView(requests: viewModel.recentRequests)
                
                // Token usage breakdown
                TokenUsageView(metrics: viewModel.currentMetrics)
            }
            .padding()
        }
        .navigationTitle("Diagnostics")
    }
}

struct MetricsCardsView: View {
    let metrics: AppMetrics
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
            MetricCard(
                title: "Avg Latency",
                value: "\(Int(metrics.averageLatency * 1000))ms",
                icon: "speedometer",
                color: .blue
            )
            
            MetricCard(
                title: "Tokens/sec",
                value: String(format: "%.1f", metrics.tokensPerSecond),
                icon: "gauge",
                color: .green
            )
            
            MetricCard(
                title: "Requests",
                value: "\(metrics.totalRequests)",
                icon: "arrow.up.arrow.down",
                color: .orange
            )
            
            MetricCard(
                title: "Error Rate",
                value: String(format: "%.1f%%", metrics.errorRate * 100),
                icon: "exclamationmark.triangle",
                color: metrics.errorRate > 0.05 ? .red : .gray
            )
        }
    }
}
```

2. **Token Usage Optimization**
```swift
class ContextOptimizer {
    func optimizeContext(_ items: [ContextItem], maxTokens: Int) -> [ContextItem] {
        let totalTokens = items.reduce(0) { $0 + $1.tokenCount }
        
        guard totalTokens > maxTokens else { return items }
        
        // Strategy 1: Remove least recently modified files first
        let sortedByRecency = items.sorted { $0.lastModified > $1.lastModified }
        
        var optimizedItems: [ContextItem] = []
        var currentTokens = 0
        
        for item in sortedByRecency {
            if currentTokens + item.tokenCount <= maxTokens {
                optimizedItems.append(item)
                currentTokens += item.tokenCount
            } else {
                // Strategy 2: Try to include partial content for large files
                if let partialItem = createPartialContext(item, remainingTokens: maxTokens - currentTokens) {
                    optimizedItems.append(partialItem)
                }
                break
            }
        }
        
        return optimizedItems
    }
    
    private func createPartialContext(_ item: ContextItem, remainingTokens: Int) -> ContextItem? {
        guard remainingTokens > 100 else { return nil } // Minimum viable content
        
        let lines = item.content.components(separatedBy: .newlines)
        let targetLines = Int(Double(lines.count) * (Double(remainingTokens) / Double(item.tokenCount)))
        
        let truncatedContent = lines.prefix(targetLines).joined(separator: "\n")
        let truncatedItem = ContextItem(
            id: item.id + "_truncated",
            type: item.type,
            path: item.path,
            name: item.name + " (truncated)",
            content: truncatedContent + "\n\n[... content truncated for token limit ...]",
            tokenCount: remainingTokens,
            lastModified: item.lastModified,
            metadata: item.metadata
        )
        
        return truncatedItem
    }
}
```

#### Week 8: Session Management & Search
1. **Session Management Implementation**
```swift
class CoreDataSessionManager: SessionManager {
    private let persistentContainer: NSPersistentContainer
    
    init() {
        persistentContainer = NSPersistentContainer(name: "OneShot")
        persistentContainer.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data error: \(error)")
            }
        }
    }
    
    func searchSessions(query: String, filters: SessionFilters?) -> [SessionSummary] {
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<ConversationEntity> = ConversationEntity.fetchRequest()
        
        var predicates: [NSPredicate] = []
        
        // Full-text search in titles and message content
        if !query.isEmpty {
            let titlePredicate = NSPredicate(format: "title CONTAINS[cd] %@", query)
            let contentPredicate = NSPredicate(format: "ANY messages.content CONTAINS[cd] %@", query)
            predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: [titlePredicate, contentPredicate]))
        }
        
        // Apply filters
        if let filters = filters {
            if let provider = filters.provider {
                predicates.append(NSPredicate(format: "provider == %@", provider))
            }
            
            if let dateRange = filters.dateRange {
                predicates.append(NSPredicate(format: "createdAt >= %@ AND createdAt <= %@", 
                                            dateRange.start as NSDate, dateRange.end as NSDate))
            }
            
            if filters.archivedOnly {
                predicates.append(NSPredicate(format: "isArchived == true"))
            }
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ConversationEntity.lastModified, ascending: false)]
        
        do {
            let conversations = try context.fetch(request)
            return conversations.map { SessionSummary(from: $0) }
        } catch {
            print("Search error: \(error)")
            return []
        }
    }
}

struct SessionsListView: View {
    @StateObject private var viewModel = SessionsViewModel()
    @State private var searchText = ""
    @State private var showingFilters = false
    
    var body: some View {
        VStack {
            // Search bar
            HStack {
                TextField("Search conversations...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        viewModel.search(query: searchText)
                    }
                
                Button(action: { showingFilters.toggle() }) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .popover(isPresented: $showingFilters) {
                    SessionFiltersView(filters: $viewModel.filters)
                }
            }
            .padding()
            
            // Sessions list
            List(viewModel.sessions, id: \.id) { session in
                SessionRowView(session: session)
                    .onTapGesture {
                        viewModel.selectSession(session)
                    }
                    .contextMenu {
                        Button("Archive") {
                            viewModel.archiveSession(session)
                        }
                        Button("Delete", role: .destructive) {
                            viewModel.deleteSession(session)
                        }
                    }
            }
        }
        .onAppear {
            viewModel.loadSessions()
        }
    }
}
```

### Phase 3: Advanced Features (Weeks 9-12)

#### Week 9: Prompt Library
```swift
struct PromptLibrary {
    let id: UUID
    let name: String
    let content: String
    let variables: [PromptVariable]
    let category: PromptCategory
    let isBuiltIn: Bool
    let createdAt: Date
    let lastUsed: Date?
}

struct PromptVariable {
    let name: String
    let type: VariableType
    let defaultValue: String?
    let description: String?
    let isRequired: Bool
}

enum VariableType {
    case text
    case file
    case selection
    case clipboard
    case custom(String)
}

class PromptLibraryManager: ObservableObject {
    @Published var prompts: [PromptLibrary] = []
    @Published var categories: [PromptCategory] = []
    
    func applyPrompt(_ prompt: PromptLibrary, variables: [String: String]) -> String {
        var content = prompt.content
        
        for variable in prompt.variables {
            let placeholder = "{{\(variable.name)}}"
            let value = variables[variable.name] ?? variable.defaultValue ?? ""
            content = content.replacingOccurrences(of: placeholder, with: value)
        }
        
        // Handle system variables
        content = content.replacingOccurrences(of: "{{DATE}}", with: Date().formatted())
        content = content.replacingOccurrences(of: "{{TIME}}", with: Date().formatted(date: .omitted, time: .standard))
        
        return content
    }
    
    func loadBuiltInPrompts() {
        let builtIns = [
            PromptLibrary(
                id: UUID(),
                name: "Code Review",
                content: """
                Please review the following code and provide feedback on:
                1. Code quality and best practices
                2. Potential bugs or issues
                3. Performance optimizations
                4. Security considerations
                
                Code to review:
                {{CODE}}
                
                Focus on: {{FOCUS_AREAS}}
                """,
                variables: [
                    PromptVariable(name: "CODE", type: .file, defaultValue: nil, description: "Code file to review", isRequired: true),
                    PromptVariable(name: "FOCUS_AREAS", type: .text, defaultValue: "general code quality", description: "Specific areas to focus on", isRequired: false)
                ],
                category: .codeReview,
                isBuiltIn: true,
                createdAt: Date(),
                lastUsed: nil
            ),
            
            PromptLibrary(
                id: UUID(),
                name: "Debug Helper",
                content: """
                I'm encountering an issue with my code. Please help me debug it:
                
                Error message: {{ERROR_MESSAGE}}
                
                Relevant code:
                {{CODE}}
                
                What I've already tried:
                {{ATTEMPTED_SOLUTIONS}}
                
                Please provide step-by-step debugging suggestions.
                """,
                variables: [
                    PromptVariable(name: "ERROR_MESSAGE", type: .text, defaultValue: nil, description: "Error message you're seeing", isRequired: true),
                    PromptVariable(name: "CODE", type: .file, defaultValue: nil, description: "Code that's causing the issue", isRequired: true),
                    PromptVariable(name: "ATTEMPTED_SOLUTIONS", type: .text, defaultValue: "Nothing yet", description: "What you've tried so far", isRequired: false)
                ],
                category: .debugging,
                isBuiltIn: true,
                createdAt: Date(),
                lastUsed: nil
            )
        ]
        
        prompts.append(contentsOf: builtIns)
    }
}

struct PromptLibraryView: View {
    @StateObject private var manager = PromptLibraryManager()
    @State private var selectedPrompt: PromptLibrary?
    @State private var showingEditor = false
    
    var body: some View {
        HSplitView {
            // Prompt list
            VStack {
                HStack {
                    Text("Prompt Library")
                        .font(.headline)
                    Spacer()
                    Button(action: { showingEditor = true }) {
                        Image(systemName: "plus")
                    }
                }
                .padding()
                
                List(manager.prompts, id: \.id) { prompt in
                    PromptRowView(prompt: prompt)
                        .onTapGesture {
                            selectedPrompt = prompt
                        }
                }
            }
            .frame(minWidth: 300)
            
            // Prompt details/editor
            if let prompt = selectedPrompt {
                PromptDetailView(prompt: prompt, manager: manager)
            } else {
                Text("Select a prompt to view details")
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingEditor) {
            PromptEditorView(manager: manager)
        }
        .onAppear {
            manager.loadBuiltInPrompts()
        }
    }
}
```

#### Week 10: File Monitoring & Context Refresh
```swift
class FileMonitorService: ObservableObject {
    private var eventStream: FSEventStreamRef?
    private var monitoredPaths: Set<String> = []
    private let queue = DispatchQueue(label: "fileMonitor", qos: .background)
    
    @Published var changedFiles: [String] = []
    
    func startMonitoring(paths: [String]) {
        stopMonitoring()
        
        monitoredPaths = Set(paths)
        
        let callback: FSEventStreamCallback = { (streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds) in
            guard let info = clientCallBackInfo else { return }
            let monitor = Unmanaged<FileMonitorService>.fromOpaque(info).takeUnretainedValue()
            monitor.handleFileEvents(numEvents, eventPaths, eventFlags)
        }
        
        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()
        
        let pathsArray = paths as CFArray
        
        eventStream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            pathsArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        )
        
        FSEventStreamSetDispatchQueue(eventStream!, queue)
        FSEventStreamStart(eventStream!)
    }
    
    private func handleFileEvents(_ numEvents: Int, _ eventPaths: UnsafePointer<UnsafeMutableRawPointer?>, _ eventFlags: UnsafePointer<FSEventStreamEventFlags>) {
        for i in 0..<numEvents {
            let path = String(cString: eventPaths[i]!.assumingMemoryBound(to: CChar.self))
            let flags = eventFlags[i]
            
            if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified) != 0 {
                DispatchQueue.main.async {
                    self.changedFiles.append(path)
                    NotificationCenter.default.post(name: .fileChanged, object: path)
                }
            }
        }
    }
    
    func stopMonitoring() {
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
        }
    }
    
    deinit {
        stopMonitoring()
    }
}

// Context refresh notification
extension Notification.Name {
    static let fileChanged = Notification.Name("fileChanged")
    static let contextNeedsRefresh = Notification.Name("contextNeedsRefresh")
}

// In ChatViewModel
private func setupFileMonitoring() {
    NotificationCenter.default.addObserver(
        forName: .fileChanged,
        object: nil,
        queue: .main
    ) { [weak self] notification in
        guard let path = notification.object as? String else { return }
        self?.handleFileChange(path)
    }
}

private func handleFileChange(_ path: String) {
    // Check if any context items reference this file
    let affectedItems = contextItems.filter { item in
        item.path == path || path.hasPrefix(item.path)
    }
    
    if !affectedItems.isEmpty {
        showContextRefreshAlert = true
    }
}
```

#### Week 11: Export & Integration Features
```swift
class ExportService {
    enum ExportFormat: CaseIterable {
        case markdown
        case html
        case plainText
        case json
        
        var fileExtension: String {
            switch self {
            case .markdown: return "md"
            case .html: return "html"
            case .plainText: return "txt"
            case .json: return "json"
            }
        }
    }
    
    func exportSession(_ session: Session, format: ExportFormat) throws -> Data {
        switch format {
        case .markdown:
            return try exportAsMarkdown(session)
        case .html:
            return try exportAsHTML(session)
        case .plainText:
            return try exportAsPlainText(session)
        case .json:
            return try exportAsJSON(session)
        }
    }
    
    private func exportAsMarkdown(_ session: Session) throws -> Data {
        var markdown = "# \(session.title)\n\n"
        markdown += "**Created:** \(session.createdAt.formatted())\n"
        markdown += "**Provider:** \(session.provider)\n"
        markdown += "**Model:** \(session.model)\n\n"
        
        for message in session.messages {
            let roleEmoji = message.role == .user ? "🧑‍💻" : "🤖"
            markdown += "## \(roleEmoji) \(message.role.rawValue.capitalized)\n\n"
            
            if !message.contextItems.isEmpty {
                markdown += "**Context:**\n"
                for item in message.contextItems {
                    markdown += "- `\(item.name)` (\(item.type))\n"
                }
                markdown += "\n"
            }
            
            markdown += "\(message.content)\n\n"
            
            if message.role == .assistant, let tokens = message.tokens {
                markdown += "*Tokens: \(tokens.input) in, \(tokens.output) out*\n\n"
            }
            
            markdown += "---\n\n"
        }
        
        return markdown.data(using: .utf8) ?? Data()
    }
    
    func exportCodeSnippet(_ content: String, language: String?) -> String {
        let sanitizedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let timestamp = Date().formatted(date: .abbreviated, time: .shortened)
        
        var snippet = "// Exported from OneShot - \(timestamp)\n"
        if let language = language {
            snippet += "// Language: \(language)\n"
        }
        snippet += "\n\(sanitizedContent)"
        
        return snippet
    }
    
    func quickApplyToEditor(_ content: String) {
        // Copy to clipboard with special marker for editor plugins
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(content, forType: .string)
        pasteboardItem.setString("oneshot-code-snippet", forType: NSPasteboard.PasteboardType("com.oneshot.code-snippet"))
        
        pasteboard.writeObjects([pasteboardItem])
        
        // Try to trigger AppleScript for supported editors
        tryAppleScriptIntegration(content)
    }
    
    private func tryAppleScriptIntegration(_ content: String) {
        let vsCodeScript = """
        tell application "Visual Studio Code"
            if it is running then
                tell application "System Events"
                    keystroke "v" using {command down}
                end tell
            end if
        end tell
        """
        
        let script = NSAppleScript(source: vsCodeScript)
        script?.executeAndReturnError(nil)
    }
}

struct ExportOptionsView: View {
    let session: Session
    @State private var selectedFormat: ExportService.ExportFormat = .markdown
    @State private var includeContext = true
    @State private var includeMetrics = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export Conversation")
                .font(.headline)
            
            // Format selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Format:")
                    .font(.subheadline.weight(.medium))
                
                Picker("Format", selection: $selectedFormat) {
                    ForEach(ExportService.ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue.capitalized).tag(format)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Options
            VStack(alignment: .leading, spacing: 8) {
                Text("Options:")
                    .font(.subheadline.weight(.medium))
                
                Toggle("Include context files", isOn: $includeContext)
                Toggle("Include performance metrics", isOn: $includeMetrics)
            }
            
            HStack {
                Spacer()
                Button("Cancel") {
                    // Close sheet
                }
                Button("Export") {
                    performExport()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400)
    }
    
    private func performExport() {
        let exportService = ExportService()
        
        do {
            let data = try exportService.exportSession(session, format: selectedFormat)
            
            let savePanel = NSSavePanel()
            savePanel.title = "Export Conversation"
            savePanel.nameFieldStringValue = "\(session.title).\(selectedFormat.fileExtension)"
            savePanel.allowedContentTypes = [.init(filenameExtension: selectedFormat.fileExtension)!]
            
            if savePanel.runModal() == .OK,
               let url = savePanel.url {
                try data.write(to: url)
            }
        } catch {
            // Handle error
            print("Export error: \(error)")
        }
    }
}
```

#### Week 12: Plugin Architecture Foundation
```swift
protocol PluginProtocol {
    var id: String { get }
    var name: String { get }
    var version: String { get }
    var description: String { get }
    var capabilities: Set<PluginCapability> { get }
    
    func initialize(context: PluginContext) async throws
    func execute(command: PluginCommand) async throws -> PluginResult
    func cleanup() async throws
}

enum PluginCapability {
    case fileSystem
    case network
    case shellExecution
    case systemIntegration
}

struct PluginContext {
    let workingDirectory: URL
    let allowedPaths: [URL]
    let environment: [String: String]
    let sandbox: PluginSandbox
}

struct PluginCommand {
    let name: String
    let parameters: [String: Any]
    let context: CommandContext
}

struct PluginResult {
    let success: Bool
    let output: String
    let data: Data?
    let metadata: [String: Any]
}

class PluginManager: ObservableObject {
    @Published var availablePlugins: [PluginInfo] = []
    @Published var enabledPlugins: [String] = []
    
    private var loadedPlugins: [String: PluginProtocol] = [:]
    private let pluginsDirectory: URL
    
    init() {
        pluginsDirectory = try! FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("OneShot/Plugins")