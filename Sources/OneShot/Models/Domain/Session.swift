import Foundation

struct Session: Identifiable, Codable {
    let id: UUID
    let title: String
    let createdAt: Date
    let lastModified: Date
    let isArchived: Bool
    let provider: String
    let model: String
    let messages: [Message]
    let metadata: SessionMetadata
    
    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        lastModified: Date = Date(),
        isArchived: Bool = false,
        provider: String,
        model: String,
        messages: [Message] = [],
        metadata: SessionMetadata = SessionMetadata()
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.lastModified = lastModified
        self.isArchived = isArchived
        self.provider = provider
        self.model = model
        self.messages = messages
        self.metadata = metadata
    }
}

struct SessionSummary: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let createdAt: Date
    let lastModified: Date
    let isArchived: Bool
    let provider: String
    let model: String
    let messageCount: Int
    let totalTokens: Int
    
    init(from session: Session) {
        self.id = session.id
        self.title = session.title
        self.createdAt = session.createdAt
        self.lastModified = session.lastModified
        self.isArchived = session.isArchived
        self.provider = session.provider
        self.model = session.model
        self.messageCount = session.messages.count
        self.totalTokens = session.messages.compactMap(\.tokens).reduce(0) { $0 + $1.total }
    }
}

struct SessionMetadata: Codable {
    let tags: [String]
    let customProperties: [String: String]
    
    init(tags: [String] = [], customProperties: [String: String] = [:]) {
        self.tags = tags
        self.customProperties = customProperties
    }
}

struct SessionFilters {
    let provider: String?
    let dateRange: DateRange?
    let archivedOnly: Bool
    let tags: [String]
    
    init(
        provider: String? = nil,
        dateRange: DateRange? = nil,
        archivedOnly: Bool = false,
        tags: [String] = []
    ) {
        self.provider = provider
        self.dateRange = dateRange
        self.archivedOnly = archivedOnly
        self.tags = tags
    }
}

struct DateRange {
    let start: Date
    let end: Date
}

enum ExportFormat: String, CaseIterable {
    case markdown = "markdown"
    case html = "html"
    case plainText = "plainText"
    case json = "json"
    
    var fileExtension: String {
        switch self {
        case .markdown: return "md"
        case .html: return "html"
        case .plainText: return "txt"
        case .json: return "json"
        }
    }
}