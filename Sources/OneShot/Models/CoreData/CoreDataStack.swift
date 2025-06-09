import CoreData
import Foundation

final class CoreDataStack {
    static let shared = CoreDataStack()
    
    private init() {}
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "OneShot")
        
        // Configure the store description for better performance
        let storeDescription = container.persistentStoreDescriptions.first
        storeDescription?.shouldInferMappingModelAutomatically = true
        storeDescription?.shouldMigrateStoreAutomatically = true
        
        // Set store options for better performance
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                // In production, you would want to handle this more gracefully
                fatalError("Core Data error: \(error), \(error.userInfo)")
            }
        }
        
        // Enable automatic merging of changes
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    func newBackgroundContext() -> NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }
    
    func save() {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("Core Data save error: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                do {
                    let result = try block(context)
                    try context.save()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - Entity Extensions

extension ConversationEntity {
    func toDomainModel() -> Session {
        let messageEntities = (messages?.allObjects as? [MessageEntity]) ?? []
        let domainMessages = messageEntities
            .sorted { $0.timestamp < $1.timestamp }
            .map { $0.toDomainModel() }
        
        let metadata = self.metadata.flatMap { data in
            try? JSONDecoder().decode(SessionMetadata.self, from: data)
        } ?? SessionMetadata()
        
        return Session(
            id: id,
            title: title,
            createdAt: createdAt,
            lastModified: lastModified,
            isArchived: isArchived,
            provider: provider,
            model: model,
            messages: domainMessages,
            metadata: metadata
        )
    }
    
    func update(from session: Session) {
        title = session.title
        lastModified = session.lastModified
        isArchived = session.isArchived
        provider = session.provider
        model = session.model
        
        if let metadataData = try? JSONEncoder().encode(session.metadata) {
            metadata = metadataData
        }
    }
    
    static func create(from session: Session, in context: NSManagedObjectContext) -> ConversationEntity {
        let entity = ConversationEntity(context: context)
        entity.id = session.id
        entity.createdAt = session.createdAt
        entity.update(from: session)
        return entity
    }
}

extension MessageEntity {
    func toDomainModel() -> Message {
        let contextEntities = (contextItems?.allObjects as? [ContextItemEntity]) ?? []
        let domainContextItems = contextEntities.map { $0.toDomainModel() }
        
        let tokens = TokenUsage(input: Int(inputTokens), output: Int(outputTokens))
        
        let messageMetadata = self.metadata.flatMap { data in
            try? JSONDecoder().decode(MessageMetadata.self, from: data)
        } ?? MessageMetadata()
        
        return Message(
            id: id,
            content: content,
            role: MessageRole(rawValue: role) ?? .user,
            timestamp: timestamp,
            tokens: tokens,
            contextItems: domainContextItems,
            metadata: messageMetadata
        )
    }
    
    func update(from message: Message) {
        content = message.content
        role = message.role.rawValue
        timestamp = message.timestamp
        inputTokens = Int32(message.tokens?.input ?? 0)
        outputTokens = Int32(message.tokens?.output ?? 0)
        
        if let metadataData = try? JSONEncoder().encode(message.metadata) {
            metadata = metadataData
        }
    }
    
    static func create(from message: Message, in context: NSManagedObjectContext) -> MessageEntity {
        let entity = MessageEntity(context: context)
        entity.id = message.id
        entity.update(from: message)
        return entity
    }
}

extension ContextItemEntity {
    func toDomainModel() -> ContextItem {
        let contextType: ContextType
        switch type {
        case "file":
            contextType = .file(language: nil)
        case "directory":
            contextType = .directory
        case "clipboard":
            contextType = .clipboard
        case "selection":
            contextType = .selection
        case "output":
            contextType = .output
        default:
            contextType = .file(language: nil)
        }
        
        let contextMetadata = self.metadata.flatMap { data in
            try? JSONDecoder().decode(ContextMetadata.self, from: data)
        } ?? ContextMetadata()
        
        return ContextItem(
            id: id,
            type: contextType,
            path: path,
            name: name,
            content: "", // Content is not stored in Core Data for performance
            tokenCount: Int(tokenCount),
            lastModified: lastModified,
            metadata: contextMetadata
        )
    }
    
    func update(from contextItem: ContextItem) {
        id = contextItem.id
        type = contextItem.type.displayName.lowercased()
        path = contextItem.path
        name = contextItem.name
        tokenCount = Int32(contextItem.tokenCount)
        lastModified = contextItem.lastModified
        
        if let metadataData = try? JSONEncoder().encode(contextItem.metadata) {
            metadata = metadataData
        }
    }
    
    static func create(from contextItem: ContextItem, in context: NSManagedObjectContext) -> ContextItemEntity {
        let entity = ContextItemEntity(context: context)
        entity.update(from: contextItem)
        return entity
    }
}

// MARK: - Core Data Utilities

extension NSManagedObjectContext {
    func saveIfNeeded() throws {
        if hasChanges {
            try save()
        }
    }
    
    func fetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) throws -> [T] {
        return try fetch(request)
    }
    
    func count<T: NSManagedObject>(for request: NSFetchRequest<T>) throws -> Int {
        return try count(for: request)
    }
    
    func deleteAndSave(_ object: NSManagedObject) throws {
        delete(object)
        try saveIfNeeded()
    }
    
    func deleteAllObjects<T: NSManagedObject>(ofType type: T.Type) throws {
        let request = NSFetchRequest<T>(entityName: String(describing: type))
        let objects = try fetch(request)
        objects.forEach { delete($0) }
        try saveIfNeeded()
    }
}

// MARK: - Migration Support

extension CoreDataStack {
    static func destroyStore() {
        let coordinator = shared.persistentContainer.persistentStoreCoordinator
        
        for store in coordinator.persistentStores {
            if let storeURL = store.url {
                do {
                    try coordinator.destroyPersistentStore(at: storeURL, ofType: store.type, options: nil)
                    try FileManager.default.removeItem(at: storeURL)
                } catch {
                    print("Failed to destroy store: \(error)")
                }
            }
        }
    }
    
    func clearAllData() throws {
        let context = newBackgroundContext()
        
        try context.performAndWait {
            try context.deleteAllObjects(ofType: ConversationEntity.self)
            try context.deleteAllObjects(ofType: MessageEntity.self)
            try context.deleteAllObjects(ofType: ContextItemEntity.self)
        }
    }
}