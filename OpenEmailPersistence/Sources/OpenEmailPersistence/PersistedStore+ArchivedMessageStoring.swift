//
//  PersistedStore+ArchivedMessageStoring.swift
//  OpenEmailPersistence
//
//  Created by Antony Akimchenko on 07.05.25.
//

import OpenEmailModel
import Foundation
import SwiftData

public protocol ArchivedMessageStoring {
    func storeArchivedMessage(_ message: Message) async throws
    func storeArchivedMessages(_ messages: [Message]) async throws
    func archivedMessageExists(id: String) async throws -> Bool
    func archivedMessage(id: String) async throws -> Message?
    func allArchivedMessages(searchText: String) async throws -> [Message]
    func deleteArchivedMessage(id: String) async throws
    func deleteAllArchivedMessages() async throws
}

public extension Foundation.Notification.Name {
    static let didUpdateArchivedMessages = Self.init("didUpdateArchivedMessages")
}

extension PersistedStore: ArchivedMessageStoring {

    public func storeArchivedMessage(_ message: Message) async throws {
        try await storeMessages([message])
    }

    public func storeArchivedMessages(_ messages: [Message]) async throws {
        for message in messages {
            _ = message.toPersisted(modelContext: modelContext)
        }

        try modelContext.save()
        await postUpdateNotification()
    }
    
    public func archivedMessageExists(id: String) async throws -> Bool {
        try await fetchArchivedPersistedMessage(id: id) != nil
    }

    public func archivedMessage(id: String) async throws -> Message? {
        return try await fetchArchivedPersistedMessage(id: id)?.toLocal()
    }

    private func fetchArchivedPersistedMessage(id: String) async throws -> PersistedMessage? {
        let fetch = FetchDescriptor<PersistedMessage>(
            predicate: #Predicate { $0.id == id }
        )

        let results = try modelContext.fetch(fetch)
        return results.first
    }
    
    public func allArchivedMessages(searchText: String) async throws -> [Message] {
        let cleanSearchText = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        var fetch = FetchDescriptor<PersistedMessage>(
            predicate: #Predicate { message in
                cleanSearchText.isEmpty ||
                message.subject.localizedStandardContains(cleanSearchText) ||
                message.body?.localizedStandardContains(cleanSearchText) ?? false ||
                message.author.localizedStandardContains(cleanSearchText) ||
                message.readersStr.localizedStandardContains(cleanSearchText)
            },
            sortBy: [SortDescriptor<PersistedMessage>(\.authoredOn, order: .reverse)])
        fetch.includePendingChanges = true

        let results = try modelContext.fetch(fetch)
        return results.map { $0.toLocal() }
    }
    
    public func deleteArchivedMessage(id: String) async throws {
        try modelContext.delete(
            model: PersistedMessage.self,
            where: #Predicate { $0.id == id }
        )

        try modelContext.save()
        await postUpdateNotification()
    }

    public func deleteAllArchivedMessages() async throws {
        try modelContext.delete(model: PersistedMessage.self)
        try modelContext.save()
        await postUpdateNotification()
    }
}

@MainActor
private func postUpdateNotification() {
    NotificationCenter.default.post(name: .didUpdateArchivedMessages, object: nil)
}
