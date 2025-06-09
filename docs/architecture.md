# OneShot Technical Architecture Specification

## Architecture Overview

OneShot follows a layered MVVM architecture with dependency injection, designed for testability, maintainability, and extensibility. The app is built entirely in Swift with SwiftUI for the UI layer.

```
┌─────────────────────────────────────────────────┐
│                UI Layer (SwiftUI)               │
├─────────────────────────────────────────────────┤
│              ViewModels (ObservableObject)      │
├─────────────────────────────────────────────────┤
│                Service Layer                    │
├─────────────────────────────────────────────────┤
│                Data Layer                       │
└─────────────────────────────────────────────────┘
```

## Core Components

### 1. Dependency Container

```swift
protocol ServiceContainer {
    func resolve<T>(_ type: T.Type) -> T
    func register<T>(_ type: T.Type, factory: @escaping () -> T)
    func registerSingleton<T>(_ type: T.Type, factory: @escaping () -> T)
}

class DefaultServiceContainer: ServiceContainer {
    private var factories: [String: Any] = [:]
    private var singletons: [String: Any] = [:]
    
    // Implementation details...
}
```

### 2. App Entry Point

```swift
@main
struct OneShot: App {
    let container = DefaultServiceContainer()
    
    init() {
        setupDependencies()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(container.resolve(AppStateManager.self))
        }
        .commands {
            GlobalCommands()
        }
    }
    
    private func setupDependencies() {
        // Register all services
        container.registerSingleton(LLMProviderService.self) { DefaultLLMProviderService() }
        container.registerSingleton(ContextManager.self) { DefaultContextManager() }
        container.registerSingleton(SessionManager.self) { CoreDataSessionManager() }
        container.registerSingleton(DiagnosticsService.self) { DefaultDiagnosticsService() }
    }
}
```

## Service Layer Protocols

### LLM Provider Service

```swift
protocol LLMProviderService {
    var availableProviders: [LLMProvider] { get }
    var currentProvider: LLMProvider? { get set }
    
    func sendMessage(
        _ message: String, 
        context: [ContextItem], 
        configuration: LLMConfiguration
    ) async throws -> AsyncStream<MessageChunk>
    
    func addProvider(_ provider: LLMProvider)
    func removeProvider(id: String)
}

protocol LLMProvider {
    var id: String { get }
    var name: String { get }
    var isAvailable: Bool { get }
    var supportedModels: [LLMModel] { get }
    var metrics: ProviderMetrics { get }
    
    func authenticate(credentials: [String: String]) async throws
    func sendMessage(
        _ message: String,
        context: [ContextItem],
        model: LLMModel,
        parameters: LLMParameters
    ) async throws -> AsyncStream<MessageChunk>
    
    func getModels() async throws -> [LLMModel]
    func healthCheck() async -> Bool
}

struct LLMModel {
    let id: String
    let name: String
    let contextWindow: Int
    let inputPricing: Double?
    let outputPricing: Double?
    let capabilities: Set<ModelCapability>
}

struct LLMParameters {
    let temperature: Double
    let maxTokens: Int?
    let topP: Double?
    let frequencyPenalty: Double?
    let presencePenalty: Double?
}

enum ModelCapability {
    case chat
    case codeGeneration
    case codeAnalysis
    case functionCalling
}
```

### Context Management

```swift
protocol ContextManager {
    func resolveReference(_ reference: String) async throws -> ContextItem
    func getAvailableReferences(in scope: ContextScope) -> [String]
    func addContextSource(_ source: ContextSource)
    func removeContextSource(id: String)
    func startMonitoring(path: String)
    func stopMonitoring(path: String)
    func calculateTokenCount(for items: [ContextItem]) -> Int
    func optimizeContext(_ items: [ContextItem], maxTokens: Int) -> [ContextItem]
}

enum ContextScope {
    case global
    case project(path: String)
    case directory(path: String)
}

struct ContextItem {
    let id: String
    let type: ContextType
    let path: String
    let name: String
    let content: String
    let tokenCount: Int
    let lastModified: Date
    let metadata: ContextMetadata
}

enum ContextType {
    case file(language: String?)
    case directory
    case clipboard
    case selection
    case output
}

struct ContextMetadata {
    let fileSize: Int?
    let encoding: String.Encoding?
    let mimeType: String?
    let gitStatus: GitFileStatus?
}
```

### Session Management

```swift
protocol SessionManager {
    func createSession(title: String?) -> Session
    func getSession(id: UUID) throws -> Session
    func getAllSessions() -> [SessionSummary]
    func saveMessage(_ message: Message, to sessionId: UUID) throws
    func searchSessions(query: String, filters: SessionFilters?) -> [SessionSummary]
    func archiveSession(id: UUID) throws
    func deleteSession(id: UUID) throws
    func exportSession(id: UUID, format: ExportFormat) throws -> Data
}

struct Session {
    let id: UUID
    let title: String
    let createdAt: Date
    let lastModified: Date
    let isArchived: Bool
    let provider: String
    let model: String
    let messages: [Message]
    let metadata: SessionMetadata
}

struct Message {
    let id: UUID
    let content: String
    let role: MessageRole
    let timestamp: Date
    let tokens: TokenUsage?
    let contextItems: [ContextItem]
    let metadata: MessageMetadata
}

enum MessageRole {
    case user
    case assistant
    case system
}

struct TokenUsage {
    let input: Int
    let output: Int
    let total: Int
}
```

### Diagnostics Service

```swift
protocol DiagnosticsService {
    var metrics: AppMetrics { get }
    
    func recordRequest(_ request: LLMRequest, duration: TimeInterval, tokens: TokenUsage)
    func recordError(_ error: Error, context: [String: Any])
    func getProviderMetrics() -> [String: ProviderMetrics]
    func exportMetrics() -> Data
}

struct AppMetrics {
    let totalRequests: Int
    let averageLatency: TimeInterval
    let tokensPerSecond: Double
    let errorRate: Double
    let uptime: TimeInterval
}

struct ProviderMetrics {
    let requestCount: Int
    let averageLatency: TimeInterval
    let tokensPerSecond: Double
    let errorCount: Int
    let lastHealthCheck: Date
    let isHealthy: Bool
}
```

## Data Models

### Core Data Schema

```swift
// Conversation Entity
@objc(Conversation)
public class ConversationEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var createdAt: Date
    @NSManaged public var lastModified: Date
    @NSManaged public var isArchived: Bool
    @NSManaged public var provider: String
    @NSManaged public var model: String
    @NSManaged public var messages: NSSet
    @NSManaged public var metadata: Data?
}

// Message Entity
@objc(Message)
public class MessageEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var content: String
    @NSManaged public var role: String
    @NSManaged public var timestamp: Date
    @NSManaged public var inputTokens: Int32
    @NSManaged public var outputTokens: Int32
    @NSManaged public var conversation: ConversationEntity
    @NSManaged public var contextItems: NSSet
}

// ContextItem Entity
@objc(ContextItem)
public class ContextItemEntity: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var type: String
    @NSManaged public var path: String
    @NSManaged public var name: String
    @NSManaged public var tokenCount: Int32
    @NSManaged public var lastModified: Date
    @NSManaged public var metadata: Data?
    @NSManaged public var message: MessageEntity
}
```

## ViewModels

### Main Chat ViewModel

```swift
@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [DisplayMessage] = []
    @Published var currentInput: String = ""
    @Published var isGenerating: Bool = false
    @Published var contextItems: [ContextItem] = []
    @Published var availableReferences: [String] = []
    
    private let llmService: LLMProviderService
    private let contextManager: ContextManager
    private let sessionManager: SessionManager
    private let diagnostics: DiagnosticsService
    
    private var currentSession: Session?
    
    init(
        llmService: LLMProviderService,
        contextManager: ContextManager,
        sessionManager: SessionManager,
        diagnostics: DiagnosticsService
    ) {
        self.llmService = llmService
        self.contextManager = contextManager
        self.sessionManager = sessionManager
        self.diagnostics = diagnostics
        
        setupReferencesMonitoring()
    }
    
    func sendMessage() async {
        guard !currentInput.isEmpty else { return }
        
        let userMessage = Message(
            content: currentInput,
            role: .user,
            contextItems: contextItems
        )
        
        messages.append(DisplayMessage(from: userMessage))
        isGenerating = true
        
        do {
            let response = try await llmService.sendMessage(
                currentInput,
                context: contextItems,
                configuration: getCurrentConfiguration()
            )
            
            var assistantMessage = DisplayMessage.empty(role: .assistant)
            messages.append(assistantMessage)
            
            for await chunk in response {
                assistantMessage.content += chunk.content
                messages[messages.count - 1] = assistantMessage
            }
            
            // Save to session
            if let session = currentSession {
                try sessionManager.saveMessage(userMessage, to: session.id)
                try sessionManager.saveMessage(
                    Message(from: assistantMessage),
                    to: session.id
                )
            }
            
        } catch {
            // Handle error
            messages.append(DisplayMessage.error(error.localizedDescription))
            diagnostics.recordError(error, context: ["action": "sendMessage"])
        }
        
        isGenerating = false
        currentInput = ""
        contextItems.removeAll()
    }
    
    func processReference(_ reference: String) async {
        do {
            let contextItem = try await contextManager.resolveReference(reference)
            contextItems.append(contextItem)
            availableReferences = contextManager.getAvailableReferences(in: .global)
        } catch {
            // Handle error
        }
    }
}
```

### Settings ViewModel

```swift
@MainActor
class SettingsViewModel: ObservableObject {
    @Published var providers: [LLMProvider] = []
    @Published var currentProvider: LLMProvider?
    @Published var apiKeys: [String: String] = [:]
    @Published var globalHotkey: KeyboardShortcut?
    @Published var theme: AppTheme = .system
    
    private let llmService: LLMProviderService
    private let keychain: KeychainService
    
    func addProvider(_ provider: LLMProvider) {
        llmService.addProvider(provider)
        loadProviders()
    }
    
    func saveApiKey(for provider: String, key: String) {
        keychain.set(key, for: "api_key_\(provider)")
        apiKeys[provider] = key
    }
    
    func testConnection(for provider: LLMProvider) async -> Bool {
        return await provider.healthCheck()
    }
}
```

## File Structure

```
OneShot/
├── App/
│   ├── OneShotApp.swift
│   ├── ContentView.swift
│   └── DependencyContainer.swift
├── Views/
│   ├── Chat/
│   │   ├── ChatView.swift
│   │   ├── MessageView.swift
│   │   ├── InputView.swift
│   │   └── ContextIndicatorView.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   ├── ProvidersView.swift
│   │   └── PreferencesView.swift
│   └── Diagnostics/
│       ├── MetricsView.swift
│       └── PerformanceView.swift
├── ViewModels/
│   ├── ChatViewModel.swift
│   ├── SettingsViewModel.swift
│   └── DiagnosticsViewModel.swift
├── Services/
│   ├── LLM/
│   │   ├── LLMProviderService.swift
│   │   ├── OpenAIProvider.swift
│   │   └── OllamaProvider.swift
│   ├── Context/
│   │   ├── ContextManager.swift
│   │   ├── FileMonitor.swift
│   │   └── ContextOptimizer.swift
│   ├── Session/
│   │   ├── SessionManager.swift
│   │   └── CoreDataStack.swift
│   └── Diagnostics/
│       └── DiagnosticsService.swift
├── Models/
│   ├── Domain/
│   │   ├── Session.swift
│   │   ├── Message.swift
│   │   ├── ContextItem.swift
│   │   └── LLMModels.swift
│   └── CoreData/
│       ├── OneShot.xcdatamodeld
│       └── CoreDataModels.swift
├── Utilities/
│   ├── Extensions/
│   ├── Helpers/
│   └── Constants.swift
└── Resources/
    ├── Assets.xcassets
    ├── Localizable.strings
    └── Info.plist
```

## Build Configuration

### Project Settings
- **Deployment Target**: macOS 13.0
- **Swift Version**: 5.9
- **Architecture**: arm64, x86_64
- **Code Signing**: Developer ID Application

### Capabilities Required
- App Sandbox: NO (for file system access)
- Hardened Runtime: YES
- Keychain Sharing: YES
- Network Client: YES (for LLM API calls)

### Privacy Permissions
- File and Folder Access (for context injection)
- Accessibility (for global hotkeys)
- Network (for LLM providers)

This architecture provides a solid foundation for building OneShot with clean separation of concerns, testability, and extensibility for future features like plugins.