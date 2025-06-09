import Foundation

struct ContextItem: Identifiable, Codable, Hashable {
    let id: String
    let type: ContextType
    let path: String
    let name: String
    let content: String
    let tokenCount: Int
    let lastModified: Date
    let metadata: ContextMetadata
    
    init(
        id: String = UUID().uuidString,
        type: ContextType,
        path: String,
        name: String,
        content: String,
        tokenCount: Int = 0,
        lastModified: Date = Date(),
        metadata: ContextMetadata = ContextMetadata()
    ) {
        self.id = id
        self.type = type
        self.path = path
        self.name = name
        self.content = content
        self.tokenCount = tokenCount
        self.lastModified = lastModified
        self.metadata = metadata
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ContextItem, rhs: ContextItem) -> Bool {
        lhs.id == rhs.id
    }
}

enum ContextType: Codable, Hashable {
    case file(language: String?)
    case directory
    case clipboard
    case selection
    case output
    case url(String)
    
    var displayName: String {
        switch self {
        case .file: return "File"
        case .directory: return "Directory" 
        case .clipboard: return "Clipboard"
        case .selection: return "Selection"
        case .output: return "Output"
        case .url: return "URL"
        }
    }
    
    var icon: String {
        switch self {
        case .file: return "doc.text"
        case .directory: return "folder"
        case .clipboard: return "doc.on.clipboard"
        case .selection: return "selection.pin.in.out"
        case .output: return "terminal"
        case .url: return "link"
        }
    }
}

struct ContextMetadata: Codable {
    let fileSize: Int?
    let encoding: String?
    let mimeType: String?
    let gitStatus: GitFileStatus?
    let lineCount: Int?
    let language: String?
    let customProperties: [String: String]
    
    init(
        fileSize: Int? = nil,
        encoding: String? = nil,
        mimeType: String? = nil,
        gitStatus: GitFileStatus? = nil,
        lineCount: Int? = nil,
        language: String? = nil,
        customProperties: [String: String] = [:]
    ) {
        self.fileSize = fileSize
        self.encoding = encoding
        self.mimeType = mimeType
        self.gitStatus = gitStatus
        self.lineCount = lineCount
        self.language = language
        self.customProperties = customProperties
    }
}

enum GitFileStatus: String, Codable {
    case untracked = "??"
    case modified = "M"
    case added = "A"
    case deleted = "D"
    case renamed = "R"
    case copied = "C"
    case unmerged = "U"
    case ignored = "!"
    case clean = ""
}

enum ContextScope {
    case global
    case project(path: String)
    case directory(path: String)
    case workspace
}

protocol ContextSource {
    var id: String { get }
    var name: String { get }
    var type: ContextSourceType { get }
    
    func getAvailableReferences() async throws -> [String]
    func resolveReference(_ reference: String) async throws -> ContextItem
}

enum ContextSourceType {
    case fileSystem
    case git
    case clipboard
    case selection
    case custom(String)
}