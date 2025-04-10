import Foundation
import SwiftData
import OpenEmailModel
import Utils

@ModelActor
public actor PersistedStore {
    public static let shared = PersistedStore()

    public enum UpdateType: String {
        case add
        case update
        case delete
    }

    nonisolated public var storeURL: URL? {
        modelContainer.configurations.first?.url
    }

    public init(storeUrl: URL? = nil) {
        let finalStoreUrl = storeUrl ?? FileManager.default.documentsDirectoryUrl().appending(path: "OpenEmail.store")

        do {
            let config = ModelConfiguration(url: finalStoreUrl)
            let container = try ModelContainer(
                for: PersistedMessage.self, PersistedContact.self, PersistedNotification.self,
                configurations: config
            )
            self.init(modelContainer: container)
        } catch {
            fatalError("Could not initialize model container at \(finalStoreUrl.path())")
        }
    }

    public func deleteAllData() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await self.deleteAllContacts()
            }
            
            group.addTask {
                try await self.deleteAllMessages()
            }
            
            group.addTask {
                try await self.deleteAllNotifications()
            }
            
            try await group.waitForAll()
        }
    }
}
