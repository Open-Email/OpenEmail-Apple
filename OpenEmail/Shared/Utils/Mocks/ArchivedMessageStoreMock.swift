//
//  ArchivedMessageStoreMock.swift
//  OpenEmail
//
//  Created by Antony Akimchenko on 07.05.25.
//

import Foundation
import OpenEmailModel
import OpenEmailPersistence


#if DEBUG
class ArchivedMessageStoreMock: ArchivedMessageStoring {
    func allArchivedMessages(ids: [String]) async throws -> [OpenEmailModel.Message] {
        return []
    }

    func deleteArchivedMessages(ids: [String]) async throws {
    }

    var stubMessages: [Message] = [
        Message.makeRandom(id: "1"),
        Message.makeRandom(id: "2"),
        Message.makeRandom(id: "3")
    ]

    func archivedMessageExists(id: String) async throws -> Bool {
        true
    }

    func archivedMessage(id: String) throws -> OpenEmailModel.Message? {
        let message = stubMessages.first { $0.id == id }
        return message ?? stubMessages.first
    }

    func storeArchivedMessage(_ message: Message) {
    }

    func storeArchivedMessages(_ messages: [Message]) {
    }
    
    func allArchivedMessages(searchText: String) async throws -> [Message] {
        stubMessages
    }

    func deleteArchivedMessage(id: String) throws {
    }
    
    func deleteAllArchivedMessages() throws {
    }
}
#endif
