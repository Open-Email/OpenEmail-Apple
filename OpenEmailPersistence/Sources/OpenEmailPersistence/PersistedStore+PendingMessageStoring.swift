//
//  PersistedStore+PendingMessageStoring.swift
//  OpenEmailPersistence
//
//  Created by Antony Akimchenko on 14.06.25.
//

import Foundation
import SwiftData
import OpenEmailModel
import Combine
import Utils

public protocol PendingMessageStoring {
    func storePendingMessage(_ message: PendingMessage) async throws
    func storePendingMessages(_ messages: [PendingMessage]) async throws
    func pendingMessageExists(id: String) async throws -> Bool
    func pendingMessage(id: String) async throws -> PendingMessage?
    func allPendingMessages(searchText: String) async throws -> [PendingMessage]
    func deletePendingMessage(id: String) async throws
    func deletePendingMessages(ids: [String]) async throws
    func deleteAllPendingMessages() async throws
}

public extension Foundation.Notification.Name {
    static let didUpdatePendingMessages = Self.init("didUpdatePendingMessages")
}

extension PersistedStore: PendingMessageStoring {

    public func storePendingMessage(_ message: PendingMessage) async throws {
        try await storePendingMessages([message])
    }
    
    public func storePendingMessages(_ messages: [PendingMessage]) async throws {
        for message in messages {
            modelContext.insert(message.toPersisted())
        }
        
        try modelContext.save()
        await postUpdateNotification()
    }
    
    public func pendingMessageExists(id: String) async throws -> Bool {
        try await fetchPendingMessage(id: id) != nil
    }
    
    public func pendingMessage(id: String) async throws -> PendingMessage? {
        return try await fetchPendingMessage(id: id)?.toLocal()
    }
    
    private func fetchPendingMessage(id: String) async throws -> PersistedPendingMessage? {
        let fetch = FetchDescriptor<PersistedPendingMessage>(
            predicate: #Predicate { $0.id == id }
        )
        
        let results = try modelContext.fetch(fetch)
        return results.first
    }
    
    public func allPendingMessages(searchText: String) async throws -> [PendingMessage] {
        let cleanSearchText = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        var fetch = FetchDescriptor<PersistedPendingMessage>(
            predicate: #Predicate { message in
                cleanSearchText.isEmpty ||
                message.subject.localizedStandardContains(cleanSearchText) ||
                message.body?.localizedStandardContains(cleanSearchText) ?? false ||
                message.author.localizedStandardContains(cleanSearchText) ||
                message.readersStr.localizedStandardContains(cleanSearchText)
            },
            sortBy: [SortDescriptor<PersistedPendingMessage>(\.authoredOn, order: .reverse)])
        fetch.includePendingChanges = true
        
        let results = try modelContext.fetch(fetch)
        return results.map { $0.toLocal() }
    }
    
   
    
    public func deletePendingMessage(id: String) async throws {
        try modelContext.delete(
            model: PersistedPendingMessage.self,
            where: #Predicate { $0.id == id }
        )
        
        try modelContext.save()
        await postUpdateNotification()
    }
    
    public func deletePendingMessages(ids: [String]) async throws {
        for id in ids {
            try await deletePendingMessage(id: id)
        }
    }
    
    public func deleteAllPendingMessages() async throws {
        try modelContext.delete(model: PersistedPendingMessage.self)
        try modelContext.save()
        await postUpdateNotification()
    }
    
    @MainActor
    private func postUpdateNotification() {
        NotificationCenter.default.post(name: .didUpdatePendingMessages, object: nil)
    }
}
