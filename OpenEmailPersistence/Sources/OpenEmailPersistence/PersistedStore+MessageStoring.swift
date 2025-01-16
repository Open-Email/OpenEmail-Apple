import Foundation
import SwiftData
import OpenEmailModel
import Combine
import Utils

public protocol MessageStoring {
    func storeMessage(_ message: Message) async throws
    func storeMessages(_ messages: [Message]) async throws
    func messageExists(id: String) async throws -> Bool
    func message(id: String) async throws -> Message?
    func allMessages(searchText: String) async throws -> [Message]
    func allUnreadMessages() async throws -> [Message]
    func allDeletedMessages() async throws -> [Message]
    func deleteMessage(id: String) async throws
    func deleteAllMessages() async throws
    func markAsDeleted(message: Message, deleted: Bool) async throws
}

public extension Foundation.Notification.Name {
    static let didUpdateMessages = Self.init("didUpdateMessages")
}

extension PersistedStore: MessageStoring {
    public func storeMessage(_ message: Message) async throws {
        try await storeMessages([message])
    }

    public func storeMessages(_ messages: [Message]) async throws {
        for message in messages {
            _ = message.toPersisted(modelContext: modelContext)
        }

        try modelContext.save()
        await postUpdateNotification()
    }

    public func messageExists(id: String) async throws -> Bool {
        try await fetchPersistedMessage(id: id) != nil
    }

    public func message(id: String) async throws -> Message? {
        return try await fetchPersistedMessage(id: id)?.toLocal()
    }

    private func fetchPersistedMessage(id: String) async throws -> PersistedMessage? {
        let fetch = FetchDescriptor<PersistedMessage>(
            predicate: #Predicate { $0.id == id }
        )

        let results = try modelContext.fetch(fetch)
        return results.first
    }

    public func allMessages(searchText: String) async throws -> [Message] {
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

    public func allUnreadMessages() async throws -> [Message] {
        var fetch = FetchDescriptor<PersistedMessage>(
            predicate: #Predicate { message in
                message.isRead == false
            }
        )

        fetch.includePendingChanges = true

        let results = try modelContext.fetch(fetch)
        return results.map { $0.toLocal() }
    }

    public func allDeletedMessages() async throws -> [Message] {
        var fetch = FetchDescriptor<PersistedMessage>(
            predicate: #Predicate { message in
                message.deletedAt != nil
            }
        )
        fetch.includePendingChanges = true
        let results = try modelContext.fetch(fetch)
        return results.map { $0.toLocal() }
    }

    public func deleteMessage(id: String) async throws {
        try modelContext.delete(
            model: PersistedMessage.self,
            where: #Predicate { $0.id == id }
        )

        try modelContext.save()
        await postUpdateNotification()
    }

    public func deleteAllMessages() async throws {
        try modelContext.delete(model: PersistedMessage.self)
        try modelContext.save()
        await postUpdateNotification()
    }

    public func markAsDeleted(message: Message, deleted: Bool) async throws {
        var message = message
        message.deletedAt = deleted ? .now : nil
        try await storeMessage(message)
    }

    @MainActor
    private func postUpdateNotification() {
        NotificationCenter.default.post(name: .didUpdateMessages, object: nil)
    }
}
