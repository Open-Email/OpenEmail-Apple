import Foundation
import OpenEmailModel
import OpenEmailPersistence

#if DEBUG
class MessageStoreMock: MessageStoring {
    var stubMessages: [Message] = [
        Message.makeRandom(id: "1"),
        Message.makeRandom(id: "2"),
        Message.makeRandom(id: "3")
    ]

    func messageExists(id: String) async throws -> Bool {
        true
    }

    func message(id: String) throws -> OpenEmailModel.Message? {
        let message = stubMessages.first { $0.id == id }
        return message ?? stubMessages.first
    }

    func storeMessage(_ message: Message) {
    }

    func storeMessages(_ messages: [Message]) {
    }
    
    func allMessages(searchText: String) async throws -> [Message] {
        stubMessages
    }

    func allUnreadMessages() async throws -> [Message] {
        stubMessages.filter { !$0.isRead }
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
