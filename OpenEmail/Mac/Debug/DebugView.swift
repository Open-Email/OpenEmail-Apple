import SwiftUI
import OpenEmailCore
import OpenEmailModel
import OpenEmailPersistence
import Logging

struct DebugView: View {
    @AppStorage(UserDefaultsKeys.useKeychainStore) var useKeychainStore: Bool = false
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) var registeredEmailAddress: String?
    @AppStorage(UserDefaultsKeys.publicEncryptionKey) var publicEncryptionKey: String?
    @AppStorage(UserDefaultsKeys.publicEncryptionKeyId) var publicEncryptionKeyId: String?
    @AppStorage(UserDefaultsKeys.publicSigningKey) var publicSigningKey: String?
    @Environment(NavigationState.self) var navigationState

    private let keysStore: KeysStoring
    private let contactRequestController = ContactRequestsController()
    @Injected(\.messagesStore) private var messagesStore
    @Injected(\.contactsStore) private var contactsStore
    @Injected(\.notificationsStore) private var notificationsStore
    @Injected(\.syncService) private var syncService
    @Injected(\.client) private var client
    @Injected(\.attachmentsManager) private var attachmentsManager

    @State private var contactRequests: [EmailAddress] = []

    init(keysStore: KeysStoring = standardKeyStore()) {
        self.keysStore = keysStore
    }

    var body: some View {
        TabView {
            List {
                Section {
                    Toggle(isOn: $useKeychainStore) {
                        VStack(alignment: .leading) {
                            Text("Use Keychain to store keys")
                            Text("requires restart")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    Spacer()

                    LabeledContent {
                        Text(registeredEmailAddress ?? "none")
                            .textSelection(.enabled)
                    } label: {
                        Text("Registered Email Address")
                    }

                    let keys = try? keysStore.getKeys()
                    LabeledContent {
                        Text(keys?.privateEncryptionKey ?? "none")
                            .textSelection(.enabled)
                    } label: {
                        Text("Private encryption key")
                    }

                    LabeledContent {
                        Text(keys?.privateSigningKey ?? "none")
                            .textSelection(.enabled)
                    } label: {
                        Text("Private signing key")
                    }

                    LabeledContent {
                        Text(publicEncryptionKey ?? "none")
                            .textSelection(.enabled)
                    } label: {
                        Text("Public encryption key")
                    }
                    LabeledContent {
                        Text(publicEncryptionKeyId ?? "none")
                            .textSelection(.enabled)
                    } label: {
                        Text("Public encryption key Id")
                    }
                    LabeledContent {
                        Text(publicSigningKey ?? "none")
                            .textSelection(.enabled)
                    } label: {
                        Text("Public signing key")
                    }
                }
            }
            .tabItem { Text("Account") }

            List {
                Section("Remote Notifications") {
                    AsyncButton("Fetch notifications") {
                        do {
                            if let localUser = LocalUser.current {
                                try await client.fetchNotifications(localUser: localUser)
                                Log.info("fetched notifications")
                            }
                        } catch {
                            Log.error("Error fetching notifications: ", context: error)
                        }
                    }
                }

                Section("Local Storage") {
                    AsyncButton("Delete all notifications") {
                        do {
                            try await notificationsStore.deleteAllNotifications()
                            Log.info("notifications deleted")
                        } catch {
                            Log.error("Error: could not delete notifications:", context: error)
                        }
                    }

                    AsyncButton("Print all notifications") {
                        do {
                            let notifications = try await notificationsStore.allNotifications()
                            notifications.forEach {
                                print($0)
                            }
                        } catch {
                            Log.error("Error: could not get notifications:", context: error)
                        }
                    }
                }

                Section("Contact requests") {
                    HStack {
                        Button {
                            reloadContactRequests()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }

                        if contactRequests.isEmpty {
                            Text("no requests")
                        } else {
                            Text("\(contactRequests.count) requests")
                            Button("print") {
                                contactRequests.forEach {
                                    print($0.address)
                                }
                            }
                        }
                    }
                }
            }
            .tabItem { Text("Notifications") }

            List {
                Text("selectedMessageIDs: \(navigationState.selectedMessageIDs)")

                Section("Remote Messages") {
                    AsyncButton("Fetch all messages") {
                        do {
                            if let localUser = LocalUser.current {
                                _ = try await client.executeNotifications(localUser: localUser)
                            }
                        } catch {
                            Log.error("Error fetching messages:", context: error)
                        }
                    }
                }

                Section("Local Storage") {
                    AsyncButton("Generate random message") {
                        guard let localUser = LocalUser.current else { return }
                        let message = Message.makeRandom(readers: [localUser.address.address])

                        do {
                            try await messagesStore.storeMessages([message])
                        } catch {
                            Log.error("Error: could not store messages:", context: error)
                        }
                    }

                    AsyncButton("Delete all messages") {
                        do {
                            try await messagesStore.deleteAllMessages()
                            navigationState.selectedMessageIDs.removeAll()
                            Log.info("messages deleted")
                        } catch {
                            Log.error("Error: could not delete messages:", context: error)
                        }
                    }

                    AsyncButton("Print all messages") {
                        do {
                            let messages = try await messagesStore.allMessages(searchText: "")
                            print(messages)
                        } catch {
                            Log.error("Error: could not get messages:", context: error)
                        }
                    }
                }

                Section {
                    LabeledContent("Next sync in:") {
                        if syncService.isSyncing {
                            Text("syncing now…")
                        } else {
                            if let syncDate = syncService.nextSyncDate {
                                Text(syncDate, style: .timer)
                            } else {
                                Text("–")
                            }
                        }
                    }

                    AsyncButton("Sync now") {
                        await syncService.synchronize()
                    }
                }
            }
            .tabItem { Text("Messages") }

            List(attachmentsManager.downloadInfos.values.map { $0.progress}) { downloadProgress in
                let status: String = {
                    if downloadProgress.didFinish { return "finished" }
                    if downloadProgress.didCancel { return "canceled" }
                    if downloadProgress.error != nil { return "error"}
                    return "in progress"
                }()

                Text("\(downloadProgress.attachment.filename), status: \(status), progress: \(downloadProgress.progress)")
            }
            .tabItem { Text("Attachments") }

            List {
                AsyncButton("Add bogus contact") {
                    guard let localUser = LocalUser.current else { return }

                    let address = "\(RandomWordGenerator.shared.next() ?? "blabla")@dsoijsdof.com"
                    let id = localUser.connectionLinkFor(remoteAddress: address)
                    let contact = Contact(id: id, addedOn: .now, address: address, receiveBroadcasts: false)
                    try? await contactsStore.storeContact(contact)
                }

                AsyncButton("Delete all contacts") {
                    try? await contactsStore.deleteAllContacts()
                }
            }
            .tabItem { Text("Contacts") }

            List {
                LabeledContent("DB URL") {
                    HStack {
                        if let url = PersistedStore.shared.storeURL {
                            Text(url.path)
                                .textSelection(.enabled)

                            Button {
                                NSWorkspace.shared.activateFileViewerSelecting([url])
                            } label: {
                                Image(systemName: "arrowshape.turn.up.forward.fill")
                            }
                        }
                    }
                }
            }
            .tabItem { Text("DB") }
        }
        .frame(minHeight: 500)
        .frame(width: 500)
        .onAppear {
            reloadContactRequests()
        }
    }

    private func reloadContactRequests() {
        Task {
            contactRequests = await contactRequestController.contactRequests
        }
    }
}

#Preview {
    DebugView()
        .environment(NavigationState())
}
