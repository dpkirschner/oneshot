import Foundation

protocol LLMProvider: AnyObject, Identifiable {
    var id: String { get }
    var name: String { get }
    var isAvailable: Bool { get }
    var supportedModels: [LLMModel] { get }
    var metrics: ProviderMetrics { get }
    var requiresAuthentication: Bool { get }
    
    func authenticate(credentials: [String: String]) async throws
    func sendMessage(
        _ message: String,
        context: [ContextItem],
        model: LLMModel,
        parameters: LLMParameters
    ) async throws -> AsyncThrowingStream<MessageChunk, Error>
    
    func getModels() async throws -> [LLMModel]
    func healthCheck() async -> Bool
    func validateCredentials() async -> Bool
}

protocol LLMProviderService: AnyObject {
    var availableProviders: [any LLMProvider] { get }
    var currentProvider: (any LLMProvider)? { get set }
    var isConfigured: Bool { get }
    
    func sendMessage(
        _ message: String,
        context: [ContextItem],
        configuration: LLMConfiguration
    ) async throws -> AsyncThrowingStream<MessageChunk, Error>
    
    func addProvider(_ provider: any LLMProvider)
    func removeProvider(id: String)
    func getProvider(id: String) -> (any LLMProvider)?
    func validateProvider(_ provider: any LLMProvider) async -> Bool
}

struct ProviderMetrics: Codable {
    let requestCount: Int
    let averageLatency: TimeInterval
    let tokensPerSecond: Double
    let errorCount: Int
    let lastHealthCheck: Date
    let isHealthy: Bool
    let totalTokensProcessed: Int
    let averageTokensPerRequest: Double
    
    init(
        requestCount: Int = 0,
        averageLatency: TimeInterval = 0,
        tokensPerSecond: Double = 0,
        errorCount: Int = 0,
        lastHealthCheck: Date = Date(),
        isHealthy: Bool = true,
        totalTokensProcessed: Int = 0,
        averageTokensPerRequest: Double = 0
    ) {
        self.requestCount = requestCount
        self.averageLatency = averageLatency
        self.tokensPerSecond = tokensPerSecond
        self.errorCount = errorCount
        self.lastHealthCheck = lastHealthCheck
        self.isHealthy = isHealthy
        self.totalTokensProcessed = totalTokensProcessed
        self.averageTokensPerRequest = averageTokensPerRequest
    }
    
    static let empty = ProviderMetrics()
    
    var errorRate: Double {
        guard requestCount > 0 else { return 0 }
        return Double(errorCount) / Double(requestCount)
    }
    
    var uptime: TimeInterval {
        Date().timeIntervalSince(lastHealthCheck)
    }
}

enum LLMProviderError: LocalizedError {
    case notConfigured
    case authenticationFailed
    case networkError(Error)
    case invalidResponse
    case rateLimitExceeded
    case insufficientCredits
    case modelNotAvailable(String)
    case contextTooLarge(Int, Int) // current, maximum
    case invalidParameters(String)
    case providerUnavailable
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Provider is not properly configured"
        case .authenticationFailed:
            return "Authentication failed. Please check your API key"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Received invalid response from provider"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later"
        case .insufficientCredits:
            return "Insufficient credits or quota exceeded"
        case .modelNotAvailable(let model):
            return "Model '\(model)' is not available"
        case .contextTooLarge(let current, let maximum):
            return "Context too large: \(current) tokens (max: \(maximum))"
        case .invalidParameters(let message):
            return "Invalid parameters: \(message)"
        case .providerUnavailable:
            return "Provider is currently unavailable"
        }
    }
}

extension LLMProvider {
    var displayName: String { name }
    
    var statusColor: String {
        isAvailable ? "green" : "red"
    }
    
    var statusText: String {
        isAvailable ? "Available" : "Unavailable"
    }
}
