import Foundation
import OpenEmailPersistence
import OpenEmailCore
import Utils

private struct SyncServiceKey: InjectionKey {
    #if DEBUG
    static var currentValue: MessageSyncing = isPreview ? SyncServiceMock() : SyncService()
    #else
    static var currentValue: MessageSyncing = SyncService()
    #endif
}

private struct ContactsStoreKey: InjectionKey {
    #if DEBUG
    static var currentValue: ContactStoring = isPreview ? ContactStoreMock() : PersistedStore.shared
    #else
    static var currentValue: ContactStoring = PersistedStore.shared
    #endif
}

private struct MessagesStoreKey: InjectionKey {
    #if DEBUG
    static var currentValue: MessageStoring = isPreview ? MessageStoreMock() : PersistedStore.shared
    #else
    static var currentValue: MessageStoring = PersistedStore.shared
    #endif
}

private struct NotificationsStoreKey: InjectionKey {
    #if DEBUG
    static var currentValue: NotificationStoring = isPreview ? NotificationStoreMock() : PersistedStore.shared
    #else
    static var currentValue: NotificationStoring = PersistedStore.shared
    #endif
}

private struct ClientKey: InjectionKey {
    #if DEBUG
    static var currentValue: Client = isPreview ? EmailClientMock() : DefaultClient.shared
    #else
    static var currentValue: Client = DefaultClient.shared
    #endif
}

private struct AttachmentsManagerKey: InjectionKey {
    static var currentValue: AttachmentsManaging = AttachmentsManager.shared
}

private struct NetworkConnectionMonitorKey: InjectionKey {
    static var currentValue: NetworkConnectionMonitor = NetworkConnectionMonitor()
}

extension InjectedValues {
    var syncService: MessageSyncing {
        get { Self[SyncServiceKey.self] }
        set { Self[SyncServiceKey.self] = newValue }
    }

    var contactsStore: ContactStoring {
        get { Self[ContactsStoreKey.self] }
        set { Self[ContactsStoreKey.self] = newValue }
    }   

    var messagesStore: MessageStoring {
        get { Self[MessagesStoreKey.self] }
        set { Self[MessagesStoreKey.self] = newValue }
    }    

    var notificationsStore: NotificationStoring {
        get { Self[NotificationsStoreKey.self] }
        set { Self[NotificationsStoreKey.self] = newValue }
    }

    var client: Client {
        get { Self[ClientKey.self] }
        set { Self[ClientKey.self] = newValue }
    }

    var attachmentsManager: AttachmentsManaging {
        get { Self[AttachmentsManagerKey.self] }
        set { Self[AttachmentsManagerKey.self] = newValue }
    }

    var networkConnectionMonitor: NetworkConnectionMonitor {
        get { Self[NetworkConnectionMonitorKey.self] }
        set { Self[NetworkConnectionMonitorKey.self] = newValue }
    }
}
