import CoreData
import Foundation

final class CoreDataStack {
    static let shared = CoreDataStack()
    
    private init() {}
    
    private func createManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // Create ConversationEntity
        let conversationEntity = NSEntityDescription()
        conversationEntity.name = "ConversationEntity"
        conversationEntity.managedObjectClassName = "ConversationEntity"
        
        // ConversationEntity attributes
        let conversationId = NSAttributeDescription()
        conversationId.name = "id"
        conversationId.attributeType = .UUIDAttributeType
        conversationId.isOptional = false
        
        let conversationTitle = NSAttributeDescription()
        conversationTitle.name = "title"
        conversationTitle.attributeType = .stringAttributeType
        conversationTitle.isOptional = false
        
        let conversationCreatedAt = NSAttributeDescription()
        conversationCreatedAt.name = "createdAt"
        conversationCreatedAt.attributeType = .dateAttributeType
        conversationCreatedAt.isOptional = false
        
        let conversationLastModified = NSAttributeDescription()
        conversationLastModified.name = "lastModified"
        conversationLastModified.attributeType = .dateAttributeType
        conversationLastModified.isOptional = false
        
        let conversationIsArchived = NSAttributeDescription()
        conversationIsArchived.name = "isArchived"
        conversationIsArchived.attributeType = .booleanAttributeType
        conversationIsArchived.isOptional = false
        conversationIsArchived.defaultValue = false
        
        let conversationProvider = NSAttributeDescription()
        conversationProvider.name = "provider"
        conversationProvider.attributeType = .stringAttributeType
        conversationProvider.isOptional = false
        
        let conversationModel = NSAttributeDescription()
        conversationModel.name = "model"
        conversationModel.attributeType = .stringAttributeType
        conversationModel.isOptional = false
        
        let conversationMetadata = NSAttributeDescription()
        conversationMetadata.name = "metadata"
        conversationMetadata.attributeType = .binaryDataAttributeType
        conversationMetadata.isOptional = true
        
        conversationEntity.properties = [
            conversationId, conversationTitle, conversationCreatedAt,
            conversationLastModified, conversationIsArchived, conversationProvider,
            conversationModel, conversationMetadata
        ]
        
        // Create MessageEntity
        let messageEntity = NSEntityDescription()
        messageEntity.name = "MessageEntity"
        messageEntity.managedObjectClassName = "MessageEntity"
        
        // MessageEntity attributes
        let messageId = NSAttributeDescription()
        messageId.name = "id"
        messageId.attributeType = .UUIDAttributeType
        messageId.isOptional = false
        
        let messageContent = NSAttributeDescription()
        messageContent.name = "content"
        messageContent.attributeType = .stringAttributeType
        messageContent.isOptional = false
        
        let messageRole = NSAttributeDescription()
        messageRole.name = "role"
        messageRole.attributeType = .stringAttributeType
        messageRole.isOptional = false
        
        let messageTimestamp = NSAttributeDescription()
        messageTimestamp.name = "timestamp"
        messageTimestamp.attributeType = .dateAttributeType
        messageTimestamp.isOptional = false
        
        let messageInputTokens = NSAttributeDescription()
        messageInputTokens.name = "inputTokens"
        messageInputTokens.attributeType = .integer32AttributeType
        messageInputTokens.isOptional = false
        messageInputTokens.defaultValue = 0
        
        let messageOutputTokens = NSAttributeDescription()
        messageOutputTokens.name = "outputTokens"
        messageOutputTokens.attributeType = .integer32AttributeType
        messageOutputTokens.isOptional = false
        messageOutputTokens.defaultValue = 0
        
        let messageMetadata = NSAttributeDescription()
        messageMetadata.name = "metadata"
        messageMetadata.attributeType = .binaryDataAttributeType
        messageMetadata.isOptional = true
        
        messageEntity.properties = [
            messageId, messageContent, messageRole, messageTimestamp,
            messageInputTokens, messageOutputTokens, messageMetadata
        ]
        
        // Create ContextItemEntity
        let contextItemEntity = NSEntityDescription()
        contextItemEntity.name = "ContextItemEntity"
        contextItemEntity.managedObjectClassName = "ContextItemEntity"
        
        // ContextItemEntity attributes
        let contextItemId = NSAttributeDescription()
        contextItemId.name = "id"
        contextItemId.attributeType = .stringAttributeType
        contextItemId.isOptional = false
        
        let contextItemType = NSAttributeDescription()
        contextItemType.name = "type"
        contextItemType.attributeType = .stringAttributeType
        contextItemType.isOptional = false
        
        let contextItemPath = NSAttributeDescription()
        contextItemPath.name = "path"
        contextItemPath.attributeType = .stringAttributeType
        contextItemPath.isOptional = false
        
        let contextItemName = NSAttributeDescription()
        contextItemName.name = "name"
        contextItemName.attributeType = .stringAttributeType
        contextItemName.isOptional = false
        
        let contextItemTokenCount = NSAttributeDescription()
        contextItemTokenCount.name = "tokenCount"
        contextItemTokenCount.attributeType = .integer32AttributeType
        contextItemTokenCount.isOptional = false
        contextItemTokenCount.defaultValue = 0
        
        let contextItemLastModified = NSAttributeDescription()
        contextItemLastModified.name = "lastModified"
        contextItemLastModified.attributeType = .dateAttributeType
        contextItemLastModified.isOptional = false
        
        let contextItemMetadata = NSAttributeDescription()
        contextItemMetadata.name = "metadata"
        contextItemMetadata.attributeType = .binaryDataAttributeType
        contextItemMetadata.isOptional = true
        
        contextItemEntity.properties = [
            contextItemId, contextItemType, contextItemPath, contextItemName,
            contextItemTokenCount, contextItemLastModified, contextItemMetadata
        ]
        
        // Create relationships
        let conversationMessagesRelationship = NSRelationshipDescription()
        conversationMessagesRelationship.name = "messages"
        conversationMessagesRelationship.destinationEntity = messageEntity
        conversationMessagesRelationship.maxCount = 0 // 0 means to-many
        conversationMessagesRelationship.deleteRule = .cascadeDeleteRule
        
        let messageConversationRelationship = NSRelationshipDescription()
        messageConversationRelationship.name = "conversation"
        messageConversationRelationship.destinationEntity = conversationEntity
        messageConversationRelationship.maxCount = 1 // 1 means to-one
        messageConversationRelationship.deleteRule = .nullifyDeleteRule
        
        let messageContextItemsRelationship = NSRelationshipDescription()
        messageContextItemsRelationship.name = "contextItems"
        messageContextItemsRelationship.destinationEntity = contextItemEntity
        messageContextItemsRelationship.maxCount = 0 // 0 means to-many
        messageContextItemsRelationship.deleteRule = .cascadeDeleteRule
        
        let contextItemMessageRelationship = NSRelationshipDescription()
        contextItemMessageRelationship.name = "message"
        contextItemMessageRelationship.destinationEntity = messageEntity
        contextItemMessageRelationship.maxCount = 1 // 1 means to-one
        contextItemMessageRelationship.deleteRule = .nullifyDeleteRule
        
        // Set inverse relationships
        conversationMessagesRelationship.inverseRelationship = messageConversationRelationship
        messageConversationRelationship.inverseRelationship = conversationMessagesRelationship
        messageContextItemsRelationship.inverseRelationship = contextItemMessageRelationship
        contextItemMessageRelationship.inverseRelationship = messageContextItemsRelationship
        
        // Add relationships to entities
        conversationEntity.properties.append(conversationMessagesRelationship)
        messageEntity.properties.append(contentsOf: [messageConversationRelationship, messageContextItemsRelationship])
        contextItemEntity.properties.append(contextItemMessageRelationship)
        
        // Add entities to model
        model.entities = [conversationEntity, messageEntity, contextItemEntity]
        
        return model
    }
    
    lazy var persistentContainer: NSPersistentContainer = {
        let managedObjectModel = createManagedObjectModel()
        let container = NSPersistentContainer(name: "OneShot", managedObjectModel: managedObjectModel)
        
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
    
    func executeFetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) throws -> [T] {
        return try self.fetch(request)
    }
    
    func executeCount<T: NSManagedObject>(for request: NSFetchRequest<T>) throws -> Int {
        return try self.count(for: request)
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