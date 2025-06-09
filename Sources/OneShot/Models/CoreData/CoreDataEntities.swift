import CoreData
import Foundation

// MARK: - ConversationEntity

@objc(ConversationEntity)
public class ConversationEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var createdAt: Date
    @NSManaged public var lastModified: Date
    @NSManaged public var isArchived: Bool
    @NSManaged public var provider: String
    @NSManaged public var model: String
    @NSManaged public var metadata: Data?
    @NSManaged public var messages: NSSet?
    
    @objc(addMessagesObject:)
    @NSManaged public func addToMessages(_ value: MessageEntity)
    
    @objc(removeMessagesObject:)
    @NSManaged public func removeFromMessages(_ value: MessageEntity)
    
    @objc(addMessages:)
    @NSManaged public func addToMessages(_ values: NSSet)
    
    @objc(removeMessages:)
    @NSManaged public func removeFromMessages(_ values: NSSet)
}

// MARK: - MessageEntity

@objc(MessageEntity)
public class MessageEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var content: String
    @NSManaged public var role: String
    @NSManaged public var timestamp: Date
    @NSManaged public var inputTokens: Int32
    @NSManaged public var outputTokens: Int32
    @NSManaged public var metadata: Data?
    @NSManaged public var conversation: ConversationEntity?
    @NSManaged public var contextItems: NSSet?
    
    @objc(addContextItemsObject:)
    @NSManaged public func addToContextItems(_ value: ContextItemEntity)
    
    @objc(removeContextItemsObject:)
    @NSManaged public func removeFromContextItems(_ value: ContextItemEntity)
    
    @objc(addContextItems:)
    @NSManaged public func addToContextItems(_ values: NSSet)
    
    @objc(removeContextItems:)
    @NSManaged public func removeFromContextItems(_ values: NSSet)
}

// MARK: - ContextItemEntity

@objc(ContextItemEntity)
public class ContextItemEntity: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var type: String
    @NSManaged public var path: String
    @NSManaged public var name: String
    @NSManaged public var tokenCount: Int32
    @NSManaged public var lastModified: Date
    @NSManaged public var metadata: Data?
    @NSManaged public var message: MessageEntity?
}

// MARK: - Fetch Requests

extension ConversationEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ConversationEntity> {
        return NSFetchRequest<ConversationEntity>(entityName: "ConversationEntity")
    }
    
    static func fetchAll() -> NSFetchRequest<ConversationEntity> {
        let request = fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ConversationEntity.lastModified, ascending: false)]
        return request
    }
    
    static func fetchActive() -> NSFetchRequest<ConversationEntity> {
        let request = fetchAll()
        request.predicate = NSPredicate(format: "isArchived == false")
        return request
    }
    
    static func fetchArchived() -> NSFetchRequest<ConversationEntity> {
        let request = fetchAll()
        request.predicate = NSPredicate(format: "isArchived == true")
        return request
    }
    
    static func fetchByID(_ id: UUID) -> NSFetchRequest<ConversationEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return request
    }
}

extension MessageEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<MessageEntity> {
        return NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
    }
    
    static func fetchForConversation(_ conversationID: UUID) -> NSFetchRequest<MessageEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "conversation.id == %@", conversationID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MessageEntity.timestamp, ascending: true)]
        return request
    }
}

extension ContextItemEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ContextItemEntity> {
        return NSFetchRequest<ContextItemEntity>(entityName: "ContextItemEntity")
    }
    
    static func fetchForMessage(_ messageID: UUID) -> NSFetchRequest<ContextItemEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "message.id == %@", messageID as CVarArg)
        return request
    }
}