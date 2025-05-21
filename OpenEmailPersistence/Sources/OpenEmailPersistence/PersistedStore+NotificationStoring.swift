import Foundation
import SwiftData
import OpenEmailModel

public protocol NotificationStoring {
    func storeNotification(_ notification: OpenEmailModel.Notification) async throws
    func storeNotifications(_ notifications: [OpenEmailModel.Notification]) async throws
    func notification(id: String) async throws -> OpenEmailModel.Notification?
    func allNotifications() async throws -> [OpenEmailModel.Notification]
    func deleteNotification(id: String) async throws
    func deleteNotifications(forLink link: String) async throws
    func markAsProcessed(link: String) async throws
    func deleteAllNotifications() async throws
}

public extension Foundation.Notification.Name {
    static let didUpdateNotifications = Self.init("didUpdateNotifications")
}

extension PersistedStore: NotificationStoring {
    public func storeNotification(_ notification: OpenEmailModel.Notification) async throws {
        try await storeNotifications([notification])
    }

    public func storeNotifications(_ notifications: [OpenEmailModel.Notification]) async throws {
        for notification in notifications {
            let persisted = notification.toPersisted()
            modelContext.insert(persisted)
        }

        try modelContext.save()
        await postUpdateNotification()
    }

    public func notification(id: String) async throws -> OpenEmailModel.Notification? {
        try await fetchPersistedNotification(id: id)?.toLocal()
    }

    private func fetchPersistedNotification(id: String) async throws -> PersistedNotification? {
        let fetch = FetchDescriptor<PersistedNotification>(
            predicate: #Predicate { $0.id == id }
        )

        let results = try modelContext.fetch(fetch)
        return results.first
    }


    public func allNotifications() async throws -> [OpenEmailModel.Notification] {
        var fetch = FetchDescriptor<PersistedNotification>(sortBy: [SortDescriptor<PersistedNotification>(\.receivedOn)])
        fetch.includePendingChanges = true

        let results = try modelContext.fetch(fetch)
        return results.map { $0.toLocal() }
    }

    public func deleteNotification(id: String) async throws {
        try modelContext.delete(
            model: PersistedNotification.self,
            where: #Predicate { $0.id == id }
        )

        try modelContext.save()
        await postUpdateNotification()
    }

    public func deleteNotifications(forLink link: String) async throws {
        try modelContext.delete(
            model: PersistedNotification.self,
            where: #Predicate { $0.link == link }
        )

        try modelContext.save()
        await postUpdateNotification()
    }
    
    public func markAsProcessed(link: String) async throws {
        let fetch = FetchDescriptor<PersistedNotification>(
            predicate: #Predicate { $0.link == link }
        )
        
        if let result = try modelContext.fetch(fetch).first {
            result.isProccessed = true
            modelContext.insert(result)
            try modelContext.save()
            await postUpdateNotification()
        }
    }

    public func deleteAllNotifications() async throws {
        try modelContext.delete(model: PersistedNotification.self)
        try modelContext.save()
        await postUpdateNotification()
    }

    @MainActor
    private func postUpdateNotification() {
        NotificationCenter.default.post(name: .didUpdateNotifications, object: nil)
    }
}
