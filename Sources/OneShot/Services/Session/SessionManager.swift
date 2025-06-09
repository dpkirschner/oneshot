import Foundation

protocol SessionManager: AnyObject {
    var currentSession: Session? { get }
    var recentSessions: [SessionSummary] { get }
    
    func createSession(title: String?, provider: String, model: String) -> Session
    func getSession(id: UUID) throws -> Session
    func getAllSessions() -> [SessionSummary]
    func getRecentSessions(limit: Int) -> [SessionSummary]
    
    func saveSession(_ session: Session) throws
    func saveMessage(_ message: Message, to sessionId: UUID) throws
    func updateSessionTitle(_ sessionId: UUID, title: String) throws
    
    func searchSessions(query: String, filters: SessionFilters?) -> [SessionSummary]
    func archiveSession(id: UUID) throws
    func unarchiveSession(id: UUID) throws
    func deleteSession(id: UUID) throws
    
    func exportSession(id: UUID, format: ExportFormat) throws -> Data
    func importSession(from data: Data, format: ExportFormat) throws -> Session
    
    func setCurrentSession(_ session: Session?)
    func autoSaveEnabled(for sessionId: UUID) -> Bool
    func setAutoSave(enabled: Bool, for sessionId: UUID)
}

enum SessionError: LocalizedError {
    case sessionNotFound(UUID)
    case messageNotFound(UUID)
    case saveError(Error)
    case loadError(Error)
    case exportError(String)
    case importError(String)
    case invalidFormat
    case storageError(String)
    
    var errorDescription: String? {
        switch self {
        case .sessionNotFound(let id):
            return "Session not found: \(id)"
        case .messageNotFound(let id):
            return "Message not found: \(id)"
        case .saveError(let error):
            return "Failed to save: \(error.localizedDescription)"
        case .loadError(let error):
            return "Failed to load: \(error.localizedDescription)"
        case .exportError(let message):
            return "Export failed: \(message)"
        case .importError(let message):
            return "Import failed: \(message)"
        case .invalidFormat:
            return "Invalid file format"
        case .storageError(let message):
            return "Storage error: \(message)"
        }
    }
}

protocol SessionAnalytics {
    func recordSessionCreated(_ session: Session)
    func recordMessageSent(_ message: Message, in sessionId: UUID)
    func recordSessionArchived(_ sessionId: UUID)
    func recordSessionDeleted(_ sessionId: UUID)
    func recordExport(sessionId: UUID, format: ExportFormat)
    
    func getSessionStats(for sessionId: UUID) -> SessionStats
    func getGlobalStats() -> GlobalSessionStats
}

struct SessionStats {
    let sessionId: UUID
    let messageCount: Int
    let totalTokens: Int
    let averageLatency: TimeInterval
    let totalCost: Double?
    let createdAt: Date
    let lastActivity: Date
    let providers: Set<String>
    let models: Set<String>
}

struct GlobalSessionStats {
    let totalSessions: Int
    let totalMessages: Int
    let totalTokens: Int
    let averageSessionLength: Int
    let totalCost: Double?
    let favoriteProvider: String?
    let favoriteModel: String?
    let activeDays: Int
}

extension SessionManager {
    func createQuickSession(provider: String, model: String) -> Session {
        let title = "Chat \(Date().formatted(date: .abbreviated, time: .shortened))"
        return createSession(title: title, provider: provider, model: model)
    }
    
    func duplicateSession(_ sessionId: UUID) throws -> Session {
        let originalSession = try getSession(id: sessionId)
        let newSession = Session(
            title: "\(originalSession.title) (Copy)",
            provider: originalSession.provider,
            model: originalSession.model,
            messages: originalSession.messages,
            metadata: originalSession.metadata
        )
        try saveSession(newSession)
        return newSession
    }
    
    func mergeMessages(from sourceSessionId: UUID, to targetSessionId: UUID) throws {
        let sourceSession = try getSession(id: sourceSessionId)
        let targetSession = try getSession(id: targetSessionId)
        
        let mergedMessages = (targetSession.messages + sourceSession.messages)
            .sorted { $0.timestamp < $1.timestamp }
        
        let mergedSession = Session(
            id: targetSession.id,
            title: targetSession.title,
            createdAt: targetSession.createdAt,
            lastModified: Date(),
            isArchived: targetSession.isArchived,
            provider: targetSession.provider,
            model: targetSession.model,
            messages: mergedMessages,
            metadata: targetSession.metadata
        )
        
        try saveSession(mergedSession)
    }
    
    func getArchivedSessions() -> [SessionSummary] {
        return getAllSessions().filter { $0.isArchived }
    }
    
    func getActiveSessions() -> [SessionSummary] {
        return getAllSessions().filter { !$0.isArchived }
    }
    
    func bulkArchive(_ sessionIds: [UUID]) throws {
        for sessionId in sessionIds {
            try archiveSession(id: sessionId)
        }
    }
    
    func bulkDelete(_ sessionIds: [UUID]) throws {
        for sessionId in sessionIds {
            try deleteSession(id: sessionId)
        }
    }
}