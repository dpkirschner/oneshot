import Foundation

protocol ContextManager: AnyObject, ObservableObject {
    var activeContextItems: [ContextItem] { get }
    var availableReferences: [String] { get }
    var monitoredPaths: Set<String> { get }
    
    func resolveReference(_ reference: String) async throws -> ContextItem
    func getAvailableReferences(in scope: ContextScope) -> [String]
    func addContextSource(_ source: ContextSource)
    func removeContextSource(id: String)
    func addContextItem(_ item: ContextItem)
    func removeContextItem(id: String)
    func clearContext()
    
    func startMonitoring(path: String)
    func stopMonitoring(path: String)
    func stopAllMonitoring()
    
    func calculateTokenCount(for items: [ContextItem]) -> Int
    func optimizeContext(_ items: [ContextItem], maxTokens: Int, strategy: ContextOptimizationStrategy) -> [ContextItem]
    func refreshContext() async
}

enum ContextError: LocalizedError {
    case fileNotFound(String)
    case accessDenied(String)
    case invalidReference(String)
    case sourceNotFound(String)
    case contextTooLarge(Int, Int)
    case encodingError(String)
    case monitoringFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .accessDenied(let path):
            return "Access denied: \(path)"
        case .invalidReference(let reference):
            return "Invalid reference: \(reference)"
        case .sourceNotFound(let sourceId):
            return "Context source not found: \(sourceId)"
        case .contextTooLarge(let current, let maximum):
            return "Context too large: \(current) tokens (max: \(maximum))"
        case .encodingError(let path):
            return "Encoding error for file: \(path)"
        case .monitoringFailed(let path):
            return "Failed to monitor path: \(path)"
        }
    }
}

protocol ContextOptimizer {
    func optimizeContext(
        _ items: [ContextItem],
        maxTokens: Int,
        strategy: ContextOptimizationStrategy
    ) async -> [ContextItem]
    
    func estimateTokenCount(for content: String) -> Int
    func summarizeContent(_ content: String, targetTokens: Int) async throws -> String
    func extractRelevantSections(_ content: String, query: String, maxTokens: Int) async -> String
}

protocol FileMonitor: AnyObject {
    var delegate: FileMonitorDelegate? { get set }
    var monitoredPaths: Set<String> { get }
    
    func startMonitoring(path: String) throws
    func stopMonitoring(path: String)
    func stopAllMonitoring()
}

protocol FileMonitorDelegate: AnyObject {
    func fileMonitor(_ monitor: FileMonitor, didDetectChangeAt path: String)
    func fileMonitor(_ monitor: FileMonitor, didEncounterError error: Error)
}

extension ContextManager {
    func addFileContext(at url: URL) async throws {
        let reference = "@file:\(url.path)"
        let contextItem = try await resolveReference(reference)
        addContextItem(contextItem)
    }
    
    func addDirectoryContext(at url: URL, recursive: Bool = false) async throws {
        let reference = "@folder:\(url.path)"
        if recursive {
            // Add recursive flag to reference
        }
        let contextItem = try await resolveReference(reference)
        addContextItem(contextItem)
    }
    
    func addClipboardContext() async throws {
        let reference = "@clipboard"
        let contextItem = try await resolveReference(reference)
        addContextItem(contextItem)
    }
    
    var totalTokenCount: Int {
        calculateTokenCount(for: activeContextItems)
    }
    
    var contextSummary: String {
        let fileCount = activeContextItems.filter { 
            if case .file = $0.type { return true }
            return false
        }.count
        
        let dirCount = activeContextItems.filter {
            if case .directory = $0.type { return true }
            return false
        }.count
        
        var summary = []
        if fileCount > 0 { summary.append("\(fileCount) file(s)") }
        if dirCount > 0 { summary.append("\(dirCount) folder(s)") }
        
        return summary.isEmpty ? "No context" : summary.joined(separator: ", ")
    }
}