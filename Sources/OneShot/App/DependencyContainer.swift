import Foundation
import SwiftUI
import AppKit

protocol ServiceContainer {
    func resolve<T>(_ type: T.Type) -> T
    func register<T>(_ type: T.Type, factory: @escaping () -> T)
    func registerSingleton<T>(_ type: T.Type, factory: @escaping () -> T)
    func registerSingleton<T>(_ type: T.Type, instance: T)
}

final class DefaultServiceContainer: ServiceContainer {
    private var factories: [String: Any] = [:]
    private var singletons: [String: Any] = [:]
    private let lock = NSLock()
    
    init() {
        setupDefaultServices()
    }
    
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = String(describing: type)
        factories[key] = factory
    }
    
    func registerSingleton<T>(_ type: T.Type, factory: @escaping () -> T) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = String(describing: type)
        factories[key] = factory
    }
    
    func registerSingleton<T>(_ type: T.Type, instance: T) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = String(describing: type)
        singletons[key] = instance
    }
    
    func resolve<T>(_ type: T.Type) -> T {
        lock.lock()
        defer { lock.unlock() }
        
        let key = String(describing: type)
        
        // Check if we already have a singleton instance
        if let singleton = singletons[key] as? T {
            return singleton
        }
        
        // Create new instance using factory
        guard let factory = factories[key] else {
            fatalError("Service not registered: \(type)")
        }
        
        let instance: T
        if let factoryFunc = factory as? () -> T {
            instance = factoryFunc()
        } else {
            fatalError("Invalid factory for service: \(type)")
        }
        
        // Store as singleton if it was registered as one
        if factories[key] != nil {
            singletons[key] = instance
        }
        
        return instance
    }
    
    private func setupDefaultServices() {
        // Register default service implementations
        registerSingleton(LLMProviderService.self) {
            let service = DefaultLLMProviderService(container: self)
            
            // Register OpenAI provider
            let openAIProvider = OpenAIProvider()
            service.addProvider(openAIProvider)
            
            // Try to load API key from keychain
            let keychainService = self.resolve(KeychainService.self)
            if let apiKey = try? keychainService.get(DefaultKeychainService.openAIAPIKey) {
                Task {
                    try? await openAIProvider.authenticate(credentials: ["apiKey": apiKey])
                }
            }
            
            return service
        }
        
        registerSingleton(ContextManager.self) {
            DefaultContextManager(container: self)
        }
        
        registerSingleton(SessionManager.self) {
            CoreDataSessionManager(container: self)
        }
        
        registerSingleton(DiagnosticsService.self) {
            DefaultDiagnosticsService(container: self)
        }
        
        registerSingleton(KeychainService.self) {
            DefaultKeychainService()
        }
        
        registerSingleton(AppStateManager.self) {
            MainActor.assumeIsolated {
                AppStateManager(container: self)
            }
        }
    }
}

// MARK: - Service Container Extensions

extension DefaultServiceContainer {
    func registerLLMProvider(_ provider: any LLMProvider) {
        let llmService = resolve(LLMProviderService.self)
        llmService.addProvider(provider)
    }
    
    func setupTestContainer() -> DefaultServiceContainer {
        let testContainer = DefaultServiceContainer()
        
        // Register mock services for testing
        testContainer.registerSingleton(LLMProviderService.self) {
            MockLLMProviderService()
        }
        
        testContainer.registerSingleton(ContextManager.self) {
            MockContextManager()
        }
        
        testContainer.registerSingleton(SessionManager.self) {
            MockSessionManager()
        }
        
        testContainer.registerSingleton(DiagnosticsService.self) {
            MockDiagnosticsService()
        }
        
        return testContainer
    }
}

// MARK: - App State Manager

@MainActor
final class AppStateManager: ObservableObject {
    @Published var isConfigured = false
    @Published var currentTheme: AppTheme = .system
    @Published var globalHotkey: GlobalHotkey?
    @Published var isOnboardingComplete = false
    @Published var recentFiles: [URL] = []
    @Published var favoritePrompts: [String] = []
    
    private let container: ServiceContainer
    private let userDefaults = UserDefaults.standard
    
    init(container: ServiceContainer) {
        self.container = container
        loadSettings()
    }
    
    func loadSettings() {
        isOnboardingComplete = userDefaults.bool(forKey: "onboardingComplete")
        currentTheme = AppTheme(rawValue: userDefaults.string(forKey: "theme") ?? "system") ?? .system
        
        if let hotkeyData = userDefaults.data(forKey: "globalHotkey"),
           let hotkey = try? JSONDecoder().decode(GlobalHotkey.self, from: hotkeyData) {
            globalHotkey = hotkey
        }
        
        if let recentFilesData = userDefaults.data(forKey: "recentFiles"),
           let urls = try? JSONDecoder().decode([URL].self, from: recentFilesData) {
            recentFiles = urls
        }
        
        favoritePrompts = userDefaults.stringArray(forKey: "favoritePrompts") ?? []
        
        checkConfiguration()
    }
    
    func saveSettings() {
        userDefaults.set(isOnboardingComplete, forKey: "onboardingComplete")
        userDefaults.set(currentTheme.rawValue, forKey: "theme")
        
        if let hotkey = globalHotkey,
           let data = try? JSONEncoder().encode(hotkey) {
            userDefaults.set(data, forKey: "globalHotkey")
        }
        
        if let data = try? JSONEncoder().encode(recentFiles) {
            userDefaults.set(data, forKey: "recentFiles")
        }
        
        userDefaults.set(favoritePrompts, forKey: "favoritePrompts")
    }
    
    func completeOnboarding() {
        isOnboardingComplete = true
        saveSettings()
    }
    
    func addRecentFile(_ url: URL) {
        recentFiles.removeAll { $0 == url }
        recentFiles.insert(url, at: 0)
        
        // Keep only last 10 files
        if recentFiles.count > 10 {
            recentFiles = Array(recentFiles.prefix(10))
        }
        
        saveSettings()
    }
    
    func clearRecentFiles() {
        recentFiles.removeAll()
        saveSettings()
    }
    
    func addFavoritePrompt(_ prompt: String) {
        if !favoritePrompts.contains(prompt) {
            favoritePrompts.append(prompt)
            saveSettings()
        }
    }
    
    func removeFavoritePrompt(_ prompt: String) {
        favoritePrompts.removeAll { $0 == prompt }
        saveSettings()
    }
    
    private func checkConfiguration() {
        let llmService = container.resolve(LLMProviderService.self)
        isConfigured = llmService.isConfigured
    }
}

// MARK: - Supporting Types

enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
}

struct GlobalHotkey: Codable {
    let keyCode: UInt16
    let modifierFlags: UInt
    let displayString: String
    
    init(keyCode: UInt16, modifierFlags: UInt, displayString: String) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
        self.displayString = displayString
    }
    
    static let defaultHotkey = GlobalHotkey(
        keyCode: 49, // Space
        modifierFlags: 1048840, // Cmd+Shift
        displayString: "⌘⇧Space"
    )
}

// MARK: - Service Protocols for Dependency Injection

protocol KeychainService {
    func set(_ value: String, for key: String) throws
    func get(_ key: String) throws -> String?
    func delete(_ key: String) throws
    func getAllKeys() -> [String]
}

// MARK: - Forward Declarations for Default Implementations

class DefaultLLMProviderService: LLMProviderService, ObservableObject {
    @Published var availableProviders: [any LLMProvider] = []
    @Published var currentProvider: (any LLMProvider)?
    
    private let container: ServiceContainer
    
    var isConfigured: Bool {
        currentProvider != nil && currentProvider?.isAvailable == true
    }
    
    init(container: ServiceContainer) {
        self.container = container
    }
    
    func sendMessage(_ message: String, context: [ContextItem], configuration: LLMConfiguration) async throws -> AsyncThrowingStream<MessageChunk, Error> {
        guard let provider = currentProvider else {
            throw LLMProviderError.notConfigured
        }
        
        // Verify the model is supported by the current provider
        guard provider.supportedModels.contains(where: { $0.id == configuration.model.id }) else {
            throw LLMProviderError.modelNotAvailable(configuration.model.id)
        }
        
        return try await provider.sendMessage(
            message,
            context: context,
            model: configuration.model,
            parameters: configuration.parameters
        )
    }
    
    func addProvider(_ provider: any LLMProvider) {
        availableProviders.append(provider)
        if currentProvider == nil {
            currentProvider = provider
        }
    }
    
    func removeProvider(id: String) {
        availableProviders.removeAll { $0.id == id }
        if currentProvider?.id == id {
            currentProvider = availableProviders.first
        }
    }
    
    func getProvider(id: String) -> (any LLMProvider)? {
        availableProviders.first { $0.id == id }
    }
    
    func validateProvider(_ provider: any LLMProvider) async -> Bool {
        await provider.healthCheck()
    }
}

class DefaultContextManager: ContextManager, ObservableObject {
    @Published var activeContextItems: [ContextItem] = []
    @Published var availableReferences: [String] = []
    @Published var monitoredPaths: Set<String> = []
    
    private let container: ServiceContainer
    
    init(container: ServiceContainer) {
        self.container = container
    }
    
    func resolveReference(_ reference: String) async throws -> ContextItem {
        if reference.hasPrefix("@file:") {
            let path = String(reference.dropFirst(6))
            return try await loadFileContext(path: path)
        } else if reference.hasPrefix("@folder:") {
            let path = String(reference.dropFirst(8))
            return try await loadDirectoryContext(path: path)
        } else if reference == "@clipboard" {
            return try await loadClipboardContext()
        } else {
            throw ContextError.invalidReference(reference)
        }
    }
    
    func getAvailableReferences(in scope: ContextScope) -> [String] {
        availableReferences
    }
    
    func addContextSource(_ source: ContextSource) {
        // Store context sources for future reference
    }
    
    func removeContextSource(id: String) {
        // Remove context sources
    }
    
    private func loadFileContext(path: String) async throws -> ContextItem {
        let url = URL(fileURLWithPath: path)
        
        guard FileManager.default.fileExists(atPath: path) else {
            throw ContextError.fileNotFound(path)
        }
        
        guard FileManager.default.isReadableFile(atPath: path) else {
            throw ContextError.accessDenied(path)
        }
        
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let fileExtension = url.pathExtension
            let language = detectLanguage(from: fileExtension)
            
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            let modificationDate = attributes[.modificationDate] as? Date ?? Date()
            
            return ContextItem(
                id: path,
                type: .file(language: language),
                path: path,
                name: url.lastPathComponent,
                content: content,
                tokenCount: estimateTokenCount(content),
                lastModified: modificationDate
            )
        } catch {
            throw ContextError.encodingError(path)
        }
    }
    
    private func loadDirectoryContext(path: String) async throws -> ContextItem {
        let url = URL(fileURLWithPath: path)
        
        guard FileManager.default.fileExists(atPath: path) else {
            throw ContextError.fileNotFound(path)
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: path)
            let fileList = contents.joined(separator: "\n")
            
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            let modificationDate = attributes[.modificationDate] as? Date ?? Date()
            
            return ContextItem(
                id: path,
                type: .directory,
                path: path,
                name: url.lastPathComponent,
                content: "Directory contents:\n\(fileList)",
                tokenCount: estimateTokenCount(fileList),
                lastModified: modificationDate
            )
        } catch {
            throw ContextError.accessDenied(path)
        }
    }
    
    private func loadClipboardContext() async throws -> ContextItem {
        let pasteboard = NSPasteboard.general
        let content = pasteboard.string(forType: .string) ?? ""
        
        return ContextItem(
            id: "clipboard",
            type: .clipboard,
            path: "clipboard://",
            name: "Clipboard",
            content: content,
            tokenCount: estimateTokenCount(content),
            lastModified: Date()
        )
    }
    
    private func detectLanguage(from fileExtension: String) -> String? {
        let languageMap: [String: String] = [
            "swift": "swift",
            "js": "javascript",
            "ts": "typescript",
            "py": "python",
            "java": "java",
            "kt": "kotlin",
            "cpp": "cpp",
            "c": "c",
            "h": "c",
            "hpp": "cpp",
            "cs": "csharp",
            "go": "go",
            "rs": "rust",
            "php": "php",
            "rb": "ruby",
            "html": "html",
            "css": "css",
            "scss": "scss",
            "json": "json",
            "xml": "xml",
            "yaml": "yaml",
            "yml": "yaml",
            "md": "markdown",
            "sh": "bash",
            "zsh": "bash",
            "fish": "fish"
        ]
        
        return languageMap[fileExtension.lowercased()]
    }
    
    private func estimateTokenCount(_ text: String) -> Int {
        // Rough estimation: ~4 characters per token
        return max(1, text.count / 4)
    }
    
    func addContextItem(_ item: ContextItem) {
        activeContextItems.append(item)
    }
    
    func removeContextItem(id: String) {
        activeContextItems.removeAll { $0.id == id }
    }
    
    func clearContext() {
        activeContextItems.removeAll()
    }
    
    func startMonitoring(path: String) {
        monitoredPaths.insert(path)
    }
    
    func stopMonitoring(path: String) {
        monitoredPaths.remove(path)
    }
    
    func stopAllMonitoring() {
        monitoredPaths.removeAll()
    }
    
    func calculateTokenCount(for items: [ContextItem]) -> Int {
        items.reduce(0) { $0 + $1.tokenCount }
    }
    
    func optimizeContext(_ items: [ContextItem], maxTokens: Int, strategy: ContextOptimizationStrategy) -> [ContextItem] {
        // Implementation will be added in next phase
        return items
    }
    
    func refreshContext() async {
        // Implementation will be added in next phase
    }
}

class CoreDataSessionManager: SessionManager, ObservableObject {
    @Published var currentSession: Session?
    @Published var recentSessions: [SessionSummary] = []
    
    private let container: ServiceContainer
    
    init(container: ServiceContainer) {
        self.container = container
    }
    
    func createSession(title: String?, provider: String, model: String) -> Session {
        let session = Session(
            title: title ?? "New Chat",
            provider: provider,
            model: model
        )
        currentSession = session
        return session
    }
    
    func getSession(id: UUID) throws -> Session {
        // Implementation will be added in next phase
        fatalError("Not implemented yet")
    }
    
    func getAllSessions() -> [SessionSummary] {
        recentSessions
    }
    
    func getRecentSessions(limit: Int) -> [SessionSummary] {
        Array(recentSessions.prefix(limit))
    }
    
    func saveSession(_ session: Session) throws {
        // Implementation will be added in next phase
    }
    
    func saveMessage(_ message: Message, to sessionId: UUID) throws {
        // Implementation will be added in next phase
    }
    
    func updateSessionTitle(_ sessionId: UUID, title: String) throws {
        // Implementation will be added in next phase
    }
    
    func searchSessions(query: String, filters: SessionFilters?) -> [SessionSummary] {
        // Implementation will be added in next phase
        return []
    }
    
    func archiveSession(id: UUID) throws {
        // Implementation will be added in next phase
    }
    
    func unarchiveSession(id: UUID) throws {
        // Implementation will be added in next phase
    }
    
    func deleteSession(id: UUID) throws {
        // Implementation will be added in next phase
    }
    
    func exportSession(id: UUID, format: ExportFormat) throws -> Data {
        // Implementation will be added in next phase
        Data()
    }
    
    func importSession(from data: Data, format: ExportFormat) throws -> Session {
        // Implementation will be added in next phase
        fatalError("Not implemented yet")
    }
    
    func setCurrentSession(_ session: Session?) {
        currentSession = session
    }
    
    func autoSaveEnabled(for sessionId: UUID) -> Bool {
        true
    }
    
    func setAutoSave(enabled: Bool, for sessionId: UUID) {
        // Implementation will be added in next phase
    }
}

class DefaultDiagnosticsService: DiagnosticsService, ObservableObject {
    @Published var metrics: AppMetrics = .empty
    @Published var isCollectingMetrics = true
    
    private let container: ServiceContainer
    
    init(container: ServiceContainer) {
        self.container = container
    }
    
    func recordRequest(_ request: LLMRequest, duration: TimeInterval, tokens: TokenUsage) {
        // Implementation will be added in next phase
    }
    
    func recordError(_ error: Error, context: [String: Any]) {
        // Implementation will be added in next phase
    }
    
    func recordEvent(_ event: DiagnosticEvent) {
        // Implementation will be added in next phase
    }
    
    func getProviderMetrics() -> [String: ProviderMetrics] {
        [:]
    }
    
    func getProviderMetrics(for providerId: String) -> ProviderMetrics? {
        nil
    }
    
    func getRecentRequests(limit: Int) -> [RequestMetric] {
        []
    }
    
    func getRecentErrors(limit: Int) -> [ErrorMetric] {
        []
    }
    
    func exportMetrics(format: MetricsExportFormat) -> Data {
        Data()
    }
    
    func clearMetrics() {
        metrics = .empty
    }
    
    func resetMetrics() {
        metrics = .empty
    }
}


// MARK: - Mock Services for Testing

class MockLLMProviderService: LLMProviderService, ObservableObject {
    @Published var availableProviders: [any LLMProvider] = []
    @Published var currentProvider: (any LLMProvider)?
    var isConfigured: Bool = true
    
    func sendMessage(_ message: String, context: [ContextItem], configuration: LLMConfiguration) async throws -> AsyncThrowingStream<MessageChunk, Error> {
        AsyncThrowingStream(MessageChunk.self, bufferingPolicy: .unbounded) { continuation in
            continuation.yield(MessageChunk(content: "Mock response", isComplete: true))
            continuation.finish()
        }
    }
    
    func addProvider(_ provider: any LLMProvider) {}
    func removeProvider(id: String) {}
    func getProvider(id: String) -> (any LLMProvider)? { nil }
    func validateProvider(_ provider: any LLMProvider) async -> Bool { true }
}

class MockContextManager: ContextManager, ObservableObject {
    @Published var activeContextItems: [ContextItem] = []
    @Published var availableReferences: [String] = []
    @Published var monitoredPaths: Set<String> = []
    
    func resolveReference(_ reference: String) async throws -> ContextItem {
        ContextItem(type: .file(language: nil), path: reference, name: "mock.txt", content: "Mock content")
    }
    
    func getAvailableReferences(in scope: ContextScope) -> [String] { [] }
    func addContextSource(_ source: ContextSource) {}
    func removeContextSource(id: String) {}
    func addContextItem(_ item: ContextItem) {}
    func removeContextItem(id: String) {}
    func clearContext() {}
    func startMonitoring(path: String) {}
    func stopMonitoring(path: String) {}
    func stopAllMonitoring() {}
    func calculateTokenCount(for items: [ContextItem]) -> Int { 0 }
    func optimizeContext(_ items: [ContextItem], maxTokens: Int, strategy: ContextOptimizationStrategy) -> [ContextItem] { items }
    func refreshContext() async {}
}

class MockSessionManager: SessionManager, ObservableObject {
    @Published var currentSession: Session?
    @Published var recentSessions: [SessionSummary] = []
    
    func createSession(title: String?, provider: String, model: String) -> Session {
        Session(title: title ?? "Mock", provider: provider, model: model)
    }
    
    func getSession(id: UUID) throws -> Session { 
        Session(title: "Mock", provider: "mock", model: "mock")
    }
    
    func getAllSessions() -> [SessionSummary] { [] }
    func getRecentSessions(limit: Int) -> [SessionSummary] { [] }
    func saveSession(_ session: Session) throws {}
    func saveMessage(_ message: Message, to sessionId: UUID) throws {}
    func updateSessionTitle(_ sessionId: UUID, title: String) throws {}
    func searchSessions(query: String, filters: SessionFilters?) -> [SessionSummary] { [] }
    func archiveSession(id: UUID) throws {}
    func unarchiveSession(id: UUID) throws {}
    func deleteSession(id: UUID) throws {}
    func exportSession(id: UUID, format: ExportFormat) throws -> Data { Data() }
    func importSession(from data: Data, format: ExportFormat) throws -> Session {
        Session(title: "Imported", provider: "mock", model: "mock")
    }
    func setCurrentSession(_ session: Session?) {}
    func autoSaveEnabled(for sessionId: UUID) -> Bool { true }
    func setAutoSave(enabled: Bool, for sessionId: UUID) {}
}

class MockDiagnosticsService: DiagnosticsService, ObservableObject {
    @Published var metrics: AppMetrics = .empty
    @Published var isCollectingMetrics = true
    
    func recordRequest(_ request: LLMRequest, duration: TimeInterval, tokens: TokenUsage) {}
    func recordError(_ error: Error, context: [String: Any]) {}
    func recordEvent(_ event: DiagnosticEvent) {}
    func getProviderMetrics() -> [String: ProviderMetrics] { [:] }
    func getProviderMetrics(for providerId: String) -> ProviderMetrics? { nil }
    func getRecentRequests(limit: Int) -> [RequestMetric] { [] }
    func getRecentErrors(limit: Int) -> [ErrorMetric] { [] }
    func exportMetrics(format: MetricsExportFormat) -> Data { Data() }
    func clearMetrics() {}
    func resetMetrics() {}
}
