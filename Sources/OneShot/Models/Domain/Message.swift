import Foundation

struct Message: Identifiable, Codable {
    let id: UUID
    let content: String
    let role: MessageRole
    let timestamp: Date
    let tokens: TokenUsage?
    let contextItems: [ContextItem]
    let metadata: MessageMetadata
    
    init(
        id: UUID = UUID(),
        content: String,
        role: MessageRole,
        timestamp: Date = Date(),
        tokens: TokenUsage? = nil,
        contextItems: [ContextItem] = [],
        metadata: MessageMetadata = MessageMetadata()
    ) {
        self.id = id
        self.content = content
        self.role = role
        self.timestamp = timestamp
        self.tokens = tokens
        self.contextItems = contextItems
        self.metadata = metadata
    }
}

enum MessageRole: String, Codable, CaseIterable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .user: return "User"
        case .assistant: return "Assistant"
        case .system: return "System"
        }
    }
}

struct TokenUsage: Codable {
    let input: Int
    let output: Int
    let total: Int
    
    init(input: Int, output: Int) {
        self.input = input
        self.output = output
        self.total = input + output
    }
}

struct MessageMetadata: Codable {
    let latency: TimeInterval?
    let model: String?
    let temperature: Double?
    let maxTokens: Int?
    let error: String?
    let customProperties: [String: String]
    
    init(
        latency: TimeInterval? = nil,
        model: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        error: String? = nil,
        customProperties: [String: String] = [:]
    ) {
        self.latency = latency
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.error = error
        self.customProperties = customProperties
    }
}

struct MessageChunk: Codable {
    let content: String
    let isComplete: Bool
    let metadata: [String: String]
    
    init(
        content: String,
        isComplete: Bool = false,
        metadata: [String: String] = [:]
    ) {
        self.content = content
        self.isComplete = isComplete
        self.metadata = metadata
    }
}

struct DisplayMessage: Identifiable {
    let id: UUID
    var content: String
    let role: MessageRole
    let timestamp: Date
    let contextItems: [ContextItem]
    let isStreaming: Bool
    let error: String?
    
    init(
        id: UUID = UUID(),
        content: String = "",
        role: MessageRole,
        timestamp: Date = Date(),
        contextItems: [ContextItem] = [],
        isStreaming: Bool = false,
        error: String? = nil
    ) {
        self.id = id
        self.content = content
        self.role = role
        self.timestamp = timestamp
        self.contextItems = contextItems
        self.isStreaming = isStreaming
        self.error = error
    }
    
    init(from message: Message) {
        self.id = message.id
        self.content = message.content
        self.role = message.role
        self.timestamp = message.timestamp
        self.contextItems = message.contextItems
        self.isStreaming = false
        self.error = message.metadata.error
    }
    
    static func empty(role: MessageRole) -> DisplayMessage {
        DisplayMessage(role: role, isStreaming: true)
    }
    
    static func error(_ errorMessage: String) -> DisplayMessage {
        DisplayMessage(
            content: "Error: \(errorMessage)",
            role: .system,
            error: errorMessage
        )
    }
}