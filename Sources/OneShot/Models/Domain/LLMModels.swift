import Foundation

struct LLMModel: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let contextWindow: Int
    let inputPricing: Double?
    let outputPricing: Double?
    let capabilities: Set<ModelCapability>
    let provider: String
    let isLocal: Bool
    
    init(
        id: String,
        name: String,
        contextWindow: Int,
        inputPricing: Double? = nil,
        outputPricing: Double? = nil,
        capabilities: Set<ModelCapability> = [.chat],
        provider: String,
        isLocal: Bool = false
    ) {
        self.id = id
        self.name = name
        self.contextWindow = contextWindow
        self.inputPricing = inputPricing
        self.outputPricing = outputPricing
        self.capabilities = capabilities
        self.provider = provider
        self.isLocal = isLocal
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(provider)
    }
    
    static func == (lhs: LLMModel, rhs: LLMModel) -> Bool {
        lhs.id == rhs.id && lhs.provider == rhs.provider
    }
}

enum ModelCapability: String, Codable, CaseIterable {
    case chat = "chat"
    case codeGeneration = "codeGeneration"
    case codeAnalysis = "codeAnalysis"
    case functionCalling = "functionCalling"
    case imageGeneration = "imageGeneration"
    case imageAnalysis = "imageAnalysis"
    case embedding = "embedding"
    
    var displayName: String {
        switch self {
        case .chat: return "Chat"
        case .codeGeneration: return "Code Generation"
        case .codeAnalysis: return "Code Analysis"
        case .functionCalling: return "Function Calling"
        case .imageGeneration: return "Image Generation"
        case .imageAnalysis: return "Image Analysis"
        case .embedding: return "Text Embedding"
        }
    }
}

struct LLMParameters: Codable {
    let temperature: Double
    let maxTokens: Int?
    let topP: Double?
    let frequencyPenalty: Double?
    let presencePenalty: Double?
    let stopSequences: [String]?
    
    init(
        temperature: Double = 0.7,
        maxTokens: Int? = nil,
        topP: Double? = nil,
        frequencyPenalty: Double? = nil,
        presencePenalty: Double? = nil,
        stopSequences: [String]? = nil
    ) {
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.topP = topP
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
        self.stopSequences = stopSequences
    }
    
    static let `default` = LLMParameters()
    
    static let creative = LLMParameters(temperature: 0.9)
    
    static let precise = LLMParameters(temperature: 0.1)
    
    static let balanced = LLMParameters(temperature: 0.7)
}

struct LLMConfiguration: Codable {
    let model: LLMModel
    let parameters: LLMParameters
    let systemPrompt: String?
    let contextOptimization: ContextOptimizationStrategy
    
    init(
        model: LLMModel,
        parameters: LLMParameters = .default,
        systemPrompt: String? = nil,
        contextOptimization: ContextOptimizationStrategy = .smart
    ) {
        self.model = model
        self.parameters = parameters
        self.systemPrompt = systemPrompt
        self.contextOptimization = contextOptimization
    }
}

enum ContextOptimizationStrategy: String, Codable, CaseIterable {
    case none = "none"
    case truncate = "truncate"
    case summarize = "summarize"
    case smart = "smart"
    
    var displayName: String {
        switch self {
        case .none: return "No Optimization"
        case .truncate: return "Truncate Content"
        case .summarize: return "Summarize Content"
        case .smart: return "Smart Optimization"
        }
    }
    
    var description: String {
        switch self {
        case .none: return "Include all context without modification"
        case .truncate: return "Remove oldest content when token limit is exceeded"
        case .summarize: return "Summarize large content blocks"
        case .smart: return "Intelligently optimize context based on relevance"
        }
    }
}

struct LLMRequest {
    let id: UUID
    let message: String
    let context: [ContextItem]
    let configuration: LLMConfiguration
    let timestamp: Date
    
    init(
        id: UUID = UUID(),
        message: String,
        context: [ContextItem] = [],
        configuration: LLMConfiguration,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.message = message
        self.context = context
        self.configuration = configuration
        self.timestamp = timestamp
    }
}

struct LLMResponse {
    let id: UUID
    let requestId: UUID
    let content: String
    let finishReason: FinishReason
    let tokens: TokenUsage
    let latency: TimeInterval
    let timestamp: Date
    
    init(
        id: UUID = UUID(),
        requestId: UUID,
        content: String,
        finishReason: FinishReason,
        tokens: TokenUsage,
        latency: TimeInterval,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.requestId = requestId
        self.content = content
        self.finishReason = finishReason
        self.tokens = tokens
        self.latency = latency
        self.timestamp = timestamp
    }
}

enum FinishReason: String, Codable {
    case stop = "stop"
    case length = "length"
    case contentFilter = "content_filter"
    case error = "error"
    case cancelled = "cancelled"
}