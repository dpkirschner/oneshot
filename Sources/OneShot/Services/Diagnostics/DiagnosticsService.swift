import Foundation

protocol DiagnosticsService: AnyObject, ObservableObject {
    var metrics: AppMetrics { get }
    var isCollectingMetrics: Bool { get set }
    
    func recordRequest(_ request: LLMRequest, duration: TimeInterval, tokens: TokenUsage)
    func recordError(_ error: Error, context: [String: Any])
    func recordEvent(_ event: DiagnosticEvent)
    
    func getProviderMetrics() -> [String: ProviderMetrics]
    func getProviderMetrics(for providerId: String) -> ProviderMetrics?
    func getRecentRequests(limit: Int) -> [RequestMetric]
    func getRecentErrors(limit: Int) -> [ErrorMetric]
    
    func exportMetrics(format: MetricsExportFormat) -> Data
    func clearMetrics()
    func resetMetrics()
}

struct AppMetrics: Codable {
    let totalRequests: Int
    let averageLatency: TimeInterval
    let tokensPerSecond: Double
    let errorRate: Double
    let uptime: TimeInterval
    let memoryUsage: MemoryUsage
    let sessionCount: Int
    let messageCount: Int
    let totalTokensProcessed: Int
    let lastUpdated: Date
    
    init(
        totalRequests: Int = 0,
        averageLatency: TimeInterval = 0,
        tokensPerSecond: Double = 0,
        errorRate: Double = 0,
        uptime: TimeInterval = 0,
        memoryUsage: MemoryUsage = MemoryUsage(),
        sessionCount: Int = 0,
        messageCount: Int = 0,
        totalTokensProcessed: Int = 0,
        lastUpdated: Date = Date()
    ) {
        self.totalRequests = totalRequests
        self.averageLatency = averageLatency
        self.tokensPerSecond = tokensPerSecond
        self.errorRate = errorRate
        self.uptime = uptime
        self.memoryUsage = memoryUsage
        self.sessionCount = sessionCount
        self.messageCount = messageCount
        self.totalTokensProcessed = totalTokensProcessed
        self.lastUpdated = lastUpdated
    }
    
    static let empty = AppMetrics()
}

struct MemoryUsage: Codable {
    let current: Int // bytes
    let peak: Int // bytes
    let available: Int // bytes
    
    init(current: Int = 0, peak: Int = 0, available: Int = 0) {
        self.current = current
        self.peak = peak
        self.available = available
    }
    
    var currentMB: Double {
        Double(current) / 1024 / 1024
    }
    
    var peakMB: Double {
        Double(peak) / 1024 / 1024
    }
    
    var availableMB: Double {
        Double(available) / 1024 / 1024
    }
}

struct RequestMetric: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let providerId: String
    let modelId: String
    let inputTokens: Int
    let outputTokens: Int
    let latency: TimeInterval
    let success: Bool
    let errorMessage: String?
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        providerId: String,
        modelId: String,
        inputTokens: Int,
        outputTokens: Int,
        latency: TimeInterval,
        success: Bool = true,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.providerId = providerId
        self.modelId = modelId
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.latency = latency
        self.success = success
        self.errorMessage = errorMessage
    }
    
    var totalTokens: Int {
        inputTokens + outputTokens
    }
    
    var tokensPerSecond: Double {
        guard latency > 0 else { return 0 }
        return Double(outputTokens) / latency
    }
}

struct ErrorMetric: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let errorType: String
    let errorMessage: String
    let context: [String: String]
    let stackTrace: String?
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        errorType: String,
        errorMessage: String,
        context: [String: String] = [:],
        stackTrace: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.errorType = errorType
        self.errorMessage = errorMessage
        self.context = context
        self.stackTrace = stackTrace
    }
}

enum DiagnosticEvent {
    case appLaunched
    case appTerminated
    case sessionCreated(UUID)
    case sessionDeleted(UUID)
    case providerAdded(String)
    case providerRemoved(String)
    case contextAdded(String)
    case contextRemoved(String)
    case exportCompleted(ExportFormat)
    case importCompleted(ExportFormat)
    case customEvent(String, [String: Any])
    
    var name: String {
        switch self {
        case .appLaunched: return "app_launched"
        case .appTerminated: return "app_terminated"
        case .sessionCreated: return "session_created"
        case .sessionDeleted: return "session_deleted"
        case .providerAdded: return "provider_added"
        case .providerRemoved: return "provider_removed"
        case .contextAdded: return "context_added"
        case .contextRemoved: return "context_removed"
        case .exportCompleted: return "export_completed"
        case .importCompleted: return "import_completed"
        case .customEvent(let name, _): return name
        }
    }
}

enum MetricsExportFormat: String, CaseIterable {
    case json = "json"
    case csv = "csv"
    case txt = "txt"
    
    var fileExtension: String { rawValue }
    
    var displayName: String {
        switch self {
        case .json: return "JSON"
        case .csv: return "CSV"
        case .txt: return "Plain Text"
        }
    }
}

protocol PerformanceMonitor {
    func startMonitoring()
    func stopMonitoring()
    func getCurrentMemoryUsage() -> MemoryUsage
    func getCurrentCPUUsage() -> Double
    func getNetworkStats() -> NetworkStats
}

struct NetworkStats: Codable {
    let bytesReceived: Int
    let bytesSent: Int
    let requestCount: Int
    let averageRequestTime: TimeInterval
    
    init(
        bytesReceived: Int = 0,
        bytesSent: Int = 0,
        requestCount: Int = 0,
        averageRequestTime: TimeInterval = 0
    ) {
        self.bytesReceived = bytesReceived
        self.bytesSent = bytesSent
        self.requestCount = requestCount
        self.averageRequestTime = averageRequestTime
    }
}

extension DiagnosticsService {
    func recordSuccessfulRequest(
        _ request: LLMRequest,
        response: LLMResponse
    ) {
        recordRequest(request, duration: response.latency, tokens: response.tokens)
    }
    
    func recordFailedRequest(
        _ request: LLMRequest,
        error: Error,
        duration: TimeInterval
    ) {
        recordRequest(request, duration: duration, tokens: TokenUsage(input: 0, output: 0))
        recordError(error, context: [
            "request_id": request.id.uuidString,
            "provider": request.configuration.model.provider,
            "model": request.configuration.model.id
        ])
    }
    
    func getHealthStatus() -> HealthStatus {
        let providerMetrics = getProviderMetrics()
        let allHealthy = providerMetrics.values.allSatisfy { $0.isHealthy }
        let averageLatency = metrics.averageLatency
        let errorRate = metrics.errorRate
        
        let status: HealthLevel
        if !allHealthy {
            status = .critical
        } else if errorRate > 0.1 || averageLatency > 10.0 {
            status = .warning
        } else {
            status = .healthy
        }
        
        return HealthStatus(
            level: status,
            message: status.message,
            lastChecked: Date(),
            details: [
                "providers_healthy": String(allHealthy),
                "error_rate": String(format: "%.2f%%", errorRate * 100),
                "avg_latency": String(format: "%.2fs", averageLatency)
            ]
        )
    }
}

struct HealthStatus {
    let level: HealthLevel
    let message: String
    let lastChecked: Date
    let details: [String: String]
}

enum HealthLevel {
    case healthy
    case warning
    case critical
    
    var message: String {
        switch self {
        case .healthy: return "All systems operational"
        case .warning: return "Some issues detected"
        case .critical: return "Critical issues require attention"
        }
    }
    
    var color: String {
        switch self {
        case .healthy: return "green"
        case .warning: return "yellow"
        case .critical: return "red"
        }
    }
}