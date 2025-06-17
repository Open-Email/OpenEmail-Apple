//
//  PendingMessageStoreMock.swift
//  OpenEmail
//
//  Created by Antony Akimchenko on 16.06.25.
//

import Foundation
import OpenEmailModel
import OpenEmailPersistence

#if DEBUG
class PendingMessageStoreMock: PendingMessageStoring {
    func storePendingMessage(_ message: OpenEmailModel.PendingMessage) async throws {
        
    }

    func storePendingMessages(_ messages: [OpenEmailModel.PendingMessage]) async throws {
        
    }

    func pendingMessageExists(id: String) async throws -> Bool {
        true
    }

    func pendingMessage(id: String) async throws -> OpenEmailModel.PendingMessage? {
        nil
    }

    func allPendingMessages(searchText: String) async throws -> [OpenEmailModel.PendingMessage] {
        []
    }

    func deletePendingMessage(id: String) async throws {
        
    }

    func deletePendingMessages(ids: [String]) async throws {
        
    }

    func deleteAllPendingMessages() async throws {
        
    }

   
}
#endif
