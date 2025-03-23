import Foundation
import Combine
import Observation
import OpenEmailCore
import OpenEmailPersistence
import Logging
import Utils

extension Notification.Name {
    static let didSynchronizeMessages = Notification.Name("didSynchronizeMessages")
}

protocol MessageSyncing {
    var isSyncing: Bool { get }
    var nextSyncDate: Date? { get }
    func synchronize() async
    func fetchAuthorMessages(profile: Profile, includeBroadcasts: Bool) async
    func isActiveOutgoingMessageId(_ messageId: String) -> Bool
    func recallMessageId(_ messageId: String) async
    func appendOutgoingMessageId(_ messageId: String) async
}

@Observable
class SyncService: MessageSyncing {
    var isSyncing = false

    @ObservationIgnored
    @Injected(\.client) private var client

    @ObservationIgnored
    @Injected(\.messagesStore) private var messagesStore

    private var subscriptions = Set<AnyCancellable>()
    private var syncTimer: Timer?
    private var outgoingMessageIds: [String] = []

    var nextSyncDate: Date? {
        syncTimer?.fireDate
    }

    init() {
        UserDefaults.standard.publisher(for: \.notificationFetchingInterval)
            .removeDuplicates()
            .sink { _ in
                self.rescheduleSync()
            }
            .store(in: &subscriptions)

        NotificationCenter.default.publisher(for: .didUpdateContacts)
            .sink { notification in
                let updateType = PersistedStore.UpdateType(rawValue: ((notification.userInfo?["type"] as? String) ?? "")) ?? .add

                if updateType == .add {
                    Task {
                        await self.synchronize()
                    }
                }
            }
            .store(in: &subscriptions)
    }

    func isActiveOutgoingMessageId(_ messageId: String) -> Bool {
        return outgoingMessageIds.contains(messageId)
    }

    func recallMessageId(_ messageId: String) async {
        self.outgoingMessageIds = outgoingMessageIds.filter { $0 != messageId }
    }

    func appendOutgoingMessageId(_ messageId: String) async {
        self.outgoingMessageIds.append(messageId)
    }

    @MainActor
    func synchronize() async {
        guard !isSyncing else {
            Log.info("Syncing in progress, skipping scheduled synchronization")
            return
        }

        guard let localUser = LocalUser.current else {
            return
        }

        guard let localProfile = try? await client.fetchProfile(address: localUser.address, force: true) else {
            Log.error("could not fetch local profile")
            return
        }
        if localProfile[.name] != localUser.name {
            UserDefaults.standard.profileName = localProfile[.name]
        }

        defer { isSyncing = false }

        isSyncing = true
        Log.info("Starting syncing...")

        guard hasUserAccount() else { return }

        do {
            try await client.syncContacts(localUser: localUser)
        } catch {
            Log.error("Error synchronizing contacts: \(error)")
        }
        
        // Execute notifications
        var syncedAddresses: [String] = []
        do {
            guard hasUserAccount() else { return }

            // First fetch notifications from own home mail agent
            try await client.fetchNotifications(localUser: localUser)

            // Execute valid notifications by fetching from remotes
            guard hasUserAccount() else { return }

            syncedAddresses = try await client.executeNotifications(localUser: localUser)

            postMessagesSyncedNotification()
        } catch {
            Log.error("Error executing notifications: \(error)")
        }

         await withTaskGroup(of: Void.self) { group in
             group.addTask {
                 // Sync own outgoing messages
                 guard self.hasUserAccount() else { return }
                 
                 do {
                     self.outgoingMessageIds = try await self.client.fetchLocalMessages(localUser: localUser, localProfile: localProfile)
                     await self.cleanUpOutboxMessages()
                 } catch {
                     Log.error("Error fetching local messages: \(error)")
                 }
             }
             
             group.addTask {
                 // For all contacts, try fetch messages
                 guard self.hasUserAccount() else { return }
                 do {
                     try await self.fetchMessagesForContacts(localUser, syncedAddresses)
                 } catch {
                     Log.error("Error fetching profile messages: \(error)")
                 }
                 
             }
             
             await group.waitForAll()
        }

        Log.info("Syncing complete")
    }
    
    private func fetchMessagesForContacts(_ localUser: LocalUser, _ syncedAddresses: [String]) async throws {
        let contacts = try await PersistedStore.shared.allContacts()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for contact in contacts {
                group.addTask {
                    // Only for those not already fetched via notifications
                    if syncedAddresses.contains(contact.address) {
                        return
                    }
                    if let emailAddress = EmailAddress(contact.address),
                       let profile = try await self.client.fetchProfile(address: emailAddress, force: true) {
                        _ = try await self.client.fetchRemoteMessages(localUser: localUser, authorProfile: profile)

                        if contact.receiveBroadcasts {
                            _ = try await self.client.fetchRemoteBroadcastMessages(localUser: localUser, authorProfile: profile)
                        }
                    }
                }
            }
            try await group.waitForAll()
        }
    }

    private func hasUserAccount() -> Bool {
        UserDefaults.standard.registeredEmailAddress != nil
    }

    @MainActor
    private func postMessagesSyncedNotification() {
        NotificationCenter.default.post(name: .didSynchronizeMessages, object: nil)
    }

    @MainActor
    func fetchAuthorMessages(profile: Profile, includeBroadcasts: Bool) async {
        defer { isSyncing = false }

        guard !isSyncing else {
            return
        }

        guard let localUser = LocalUser.current else {
            return
        }

        isSyncing = true
        Log.info("Fetching from user \(profile.address.address)")

        do {
            _ = try await client.fetchRemoteMessages(localUser: localUser, authorProfile: profile)

            if includeBroadcasts {
                _ = try await client.fetchRemoteBroadcastMessages(localUser: localUser, authorProfile: profile)
            }
        } catch {
            Log.error("could not fetch messages from user \(profile.address.address): \(error)")
        }
    }

    private func rescheduleSync() {
        syncTimer?.invalidate()
        syncTimer = nil

        let interval = UserDefaults.standard.notificationFetchingInterval

        if interval != -1 {
            syncTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(interval * 60), repeats: true) { _ in
                Task {
                    await self.synchronize()
                }
            }
        }
    }

    /// Oubtbox messages disappear from the server after a while, so they have to be deleted from the local
    /// storage in order to stay in sync with the server.
    ///
    /// This is best effort, ignoring any errors.
    private func cleanUpOutboxMessages() async {
        guard
            let localUser = LocalUser.current,
            let allMessages = try? await messagesStore.allMessages(searchText: "")
        else {
            return
        }

        let localOutboxMessageIds = allMessages
            .filteredBy(scope: .outbox, localUser: localUser)
            .map { $0.id }
            .toSet()

        let messageIdsToDelete = localOutboxMessageIds.subtracting(outgoingMessageIds.toSet())
        for messageId in messageIdsToDelete {
            try? await messagesStore.deleteMessage(id: messageId)
        }
    }
}
