//
//  MessageThread.swift
//  OpenEmailModel
//
//  Created by Antony Akimchenko on 04.08.25.
//

public struct MessageThread: Identifiable, Equatable, Hashable {
    public let subjectId: String
    public var messages: [Message]
    
    public init(subjectId: String, messages: [Message]) {
        self.subjectId = subjectId
        self.messages = messages
    }
    
    public var subject: String? {
        return messages.first?.subject
    }
    
    public var id: String {
        return subjectId
    }
    
    public var isDeleted: Bool {
        return messages.allSatisfy(\.isDeleted)
    }
    
    public var isDraft: Bool {
        return messages.allSatisfy(\.isDraft)
    }
    
    public var isRead: Bool {
        return messages.allSatisfy(\.isRead)
    }
    
    public var hasFiles: Bool {
        return messages.contains(where: \.hasFiles)
    }
    
    public var topic: String {
        return messages.first?.subject ?? ""
    }
    
    public var readers: [String] {
        return messages.reduce(into: Set<String>()) { readers, message in
            message.readers.forEach { readers.insert($0) }
            readers.insert(message.author)
        }.sorted()
    }
    
}
