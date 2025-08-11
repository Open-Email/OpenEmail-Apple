import Foundation
import OpenEmailModel
import OpenEmailPersistence

#if DEBUG
class MessageStoreMock: MessageStoring {
    func deleteMessages(ids: [String]) async throws {
        
    }

    var stubMessages: [MessageThread] = [
        MessageThread.makeRandom(id: "1"),
        MessageThread.makeRandom(id: "2"),
        MessageThread.makeRandom(id: "3")
    ]

    func messageExists(id: String) async throws -> Bool {
        true
    }

    func message(id: String) throws -> OpenEmailModel.Message? {
        let message = stubMessages.first { $0.id == id }?.messages.first
        return message ?? stubMessages.first?.messages.first
    }

    func storeMessage(_ message: Message) {
    }

    func storeMessages(_ messages: [Message]) {
    }
    
    func allMessages(searchText: String) async throws -> [Message] {
        stubMessages.first?.messages ?? []
    }

    func allUnreadMessages() async throws -> [Message] {
        stubMessages.first?.messages.filter { !$0.isRead } ?? []
    }

    func allDeletedMessages() async throws -> [Message] {
        []
    }

    func deleteMessage(id: String) throws {
    }
    
    func deleteAllMessages() throws {
    }

    func markAsDeleted(message: Message, deleted: Bool) async throws {
    }
}
#endif
