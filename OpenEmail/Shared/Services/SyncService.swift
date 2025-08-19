import Foundation
import Combine
import Observation
import OpenEmailCore
import OpenEmailPersistence
import Logging
import Utils
#if os(iOS)
import BackgroundTasks
#endif


extension Notification.Name {
    static let didSynchronizeMessages = Notification.Name("didSynchronizeMessages")
}

protocol MessageSyncing {
    var isSyncing: Bool { get }
    func synchronize() async
    func fetchAuthorMessages(profile: Profile, includeBroadcasts: Bool) async
}

@Observable
class SyncService: MessageSyncing {
    
    static let shared = SyncService()
    
    var isSyncing = false

    @ObservationIgnored
    @Injected(\.client) private var client

    @ObservationIgnored
    @Injected(\.messagesStore) private var messagesStore
    
    @ObservationIgnored
    @Injected(\.pendingMessageStore) private var pendingMessageStore
    
    @ObservationIgnored
    private let userDefaults = UserDefaults.standard

    private var subscriptions = Set<AnyCancellable>()
    
#if os(macOS)
    private var scheduler: NSBackgroundActivityScheduler?
#endif
    
    
    private init() {
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
    
    public func setupPublishers() {
        UserDefaults.standard.publisher(for: \.notificationFetchingInterval,
                                        options: [.initial, .new])
        .removeDuplicates()
        .sink { [weak self] interval in
            if interval > 0 {
                self?.configureSchedulers(interval: Double(interval) * 60)
            }
        }
        .store(in: &subscriptions)
    }
    
    private func configureSchedulers(interval: TimeInterval) {
#if os(macOS)
        // Invalidate and recreate the macOS scheduler
        scheduler?.invalidate()
        let mac = NSBackgroundActivityScheduler(identifier: "\(String(describing: Bundle.main.bundleIdentifier)).refreshState")
        mac.repeats = true
        mac.interval = interval
        mac.schedule { completion in
            Task {
                await self.synchronize()
                completion(.finished)
            }
        }
        scheduler = mac
#elseif os(iOS)
        // Schedule the iOS BGAppRefreshTask
        scheduleAppRefresh(interval: interval)
#endif
    }
    
#if os(iOS)
    private let refreshTaskID = "\(String(Bundle.main.bundleIdentifier!)).refreshState"
    
    public func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: refreshTaskID,
            using: nil
        ) { [weak self] task in
            self?.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    private func scheduleAppRefresh(interval: TimeInterval) {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }
    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        // Always reschedule for next time
        scheduleAppRefresh(interval: Double(userDefaults.notificationFetchingInterval) * 60.0)
        
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        Task {
            await self.synchronize()
            task.setTaskCompleted(success: true)
        }
    }
#endif
    
    @MainActor
    func synchronize() async {
        guard !isSyncing else {
            Log.info("Syncing in progress, skipping scheduled synchronization")
            return
        }

        guard let localUser = LocalUser.current else {
            return
        }
        
        let localProfile: Profile?

          do {
            localProfile = try await client.fetchProfile(address: localUser.address, force: true)
              
        } catch {
            if let userError = error as? UserError, userError == .profileNotFound {
                LogoutUseCase().logout()
            }
            Log.error("could not fetch local profile")
            return
        }
        
        guard let localProfile else {
            return
        }
        
        if localProfile[.name] != localUser.name {
            UserDefaults.standard.profileName = localProfile[.name]
        }

        defer { isSyncing = false }

        isSyncing = true
        Log.info("Starting syncing...")

        await uploadPendingOutbox()
        
        guard hasUserAccount() else { return }

        do {
            try await client.syncContacts(localUser: localUser)
        } catch {
            Log.error("Error synchronizing contacts: \(error)")
        }
        
        let syncedAddresses = await getSyncedAddresses()
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                // Sync own outgoing messages
                guard self.hasUserAccount() else { return }
                
                if let remoteOutgoingMessageIds = try? await self.client.fetchLocalMessages(localUser: localUser, localProfile: localProfile) {
                    await self.cleanUpOutboxMessages(remoteOutboxIds: remoteOutgoingMessageIds)
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
        
        
        
        postMessagesSyncedNotification()
        Log.info("Syncing complete")
    }
    
    private func getSyncedAddresses() async -> [String] {
        
        guard let localUser = LocalUser.current else {
            return []
        }
        
        // Execute notifications
        var syncedAddresses: [String] = []
        do {
            guard hasUserAccount() else { return [] }
            
            // First fetch notifications from own home mail agent
            try await client.fetchNotifications(localUser: localUser)
            
            // Execute valid notifications by fetching from remotes
            guard hasUserAccount() else { return [] }
            
            syncedAddresses = try await client.executeNotifications(localUser: localUser)
            
        } catch {
            Log.error("Error executing notifications: \(error)")
        }
        
        return syncedAddresses
    }
    
    private func uploadPendingOutbox() async {
        
        guard let localUser = LocalUser.current else {
            return
        }
        
        let pendingMessages = (try? await pendingMessageStore.allPendingMessages(searchText: "")) ?? []
        await withTaskGroup { group in
            for pendingMessage in pendingMessages {
                group.addTask {
                    
                    if pendingMessage.isBroadcast {
                        do {
                            let _ = try await self.client.uploadBroadcastMessage(
                                localUser: localUser,
                                subject: pendingMessage.subject,
                                subjectId: pendingMessage.subjectId,
                                body: Data((pendingMessage.body ?? "").bytes),
                                urls: pendingMessage.draftAttachmentUrls,
                                progressHandler: nil
                            )
                        } catch {
                            Log.error("Could not upload pending broadcast: \(error)")
                        }
                        
                    } else {
                        do {
                            let _ = try await self.client.uploadPrivateMessage(
                                localUser: localUser,
                                subject: pendingMessage.subject,
                                subjectId: pendingMessage.subjectId,
                                readersAddresses: pendingMessage.readers
                                    .map { address in EmailAddress(address)! },
                                body: Data((pendingMessage.body ?? "").bytes),
                                urls: pendingMessage.draftAttachmentUrls,
                                progressHandler: nil
                            )
                        } catch {
                            Log.error("Could not upload pending private message: \(error)")
                        }
                        
                    }
                    do {
                        try await self.pendingMessageStore.deletePendingMessage(id: pendingMessage.id)
                    } catch {
                        Log.error("Could not delete pending message: \(error)")
                    }
                }
            }
            await group.waitForAll()
        }
    }
    
    private func fetchMessagesForContacts(_ localUser: LocalUser, _ syncedAddresses: [String]) async throws {
        let contacts = try await PersistedStore.shared.allContacts().filter {
            syncedAddresses.contains($0.address) == false
        }
        let maxConcurrentTasks = min(5, contacts.count)
        
        func getContactMessages(_ index: Int) async throws {
            if let emailAddress = EmailAddress(contacts[index].address),
               let profile = try await self.client.fetchProfile(address: emailAddress, force: true) {
                _ = try await self.client.fetchRemoteMessages(localUser: localUser, authorProfile: profile)

                if contacts[index].receiveBroadcasts {
                    _ = try await self.client.fetchRemoteBroadcastMessages(localUser: localUser, authorProfile: profile)
                }
            }
        }
       
        await withTaskGroup { group in
            for index in 0..<maxConcurrentTasks {
                group.addTask {
                    try? await getContactMessages(index)
                }
            }
            var tmpIndex = maxConcurrentTasks
            
            while await group.next() != nil {
                if (tmpIndex < contacts.count) {
                    let i = tmpIndex
                    tmpIndex += 1
                    group.addTask {
                        try? await getContactMessages(i)
                    }
                }
            }
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
    
    private func cleanUpOutboxMessages(remoteOutboxIds: [String]) async {
        guard
            let localUser = LocalUser.current,
            let allMessages = try? await messagesStore.allMessages(searchText: "")
        else {
            return
        }
        
        let localOutboxMessages = allMessages.filter { $0.author == localUser.address.address }
        
        for localMessage in localOutboxMessages {
            if !remoteOutboxIds.contains(localMessage.id) {
                try? await messagesStore
                    .markAsDeleted(message: localMessage, deleted: true)
            }
        }
    }
}
