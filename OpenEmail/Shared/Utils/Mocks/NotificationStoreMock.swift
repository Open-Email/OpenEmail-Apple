import Foundation
import OpenEmailModel
import OpenEmailPersistence

#if DEBUG
class NotificationStoreMock: NotificationStoring {
    func storeNotification(_ notification: OpenEmailModel.Notification) async throws {
    }
    
    func storeNotifications(_ notifications: [OpenEmailModel.Notification]) async throws {
    }
    
    func notification(id: String) async throws -> OpenEmailModel.Notification? {
        nil
    }
    
    func allNotifications() async throws -> [OpenEmailModel.Notification] {
        []
    }
    
    func deleteNotification(id: String) async throws {
    }
    
    func deleteNotifications(forLink link: String) async throws {
    }

    func deleteAllNotifications() async throws {
    }
}

#endif
