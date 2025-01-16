import Foundation
import OpenEmailModel

extension OpenEmailModel.Notification {
    func toPersisted() -> PersistedNotification {
        PersistedNotification(
            id: id,
            receivedOn: receivedOn,
            link: link,
            address: address,
            authorFingerPrint: authorFingerPrint,
            isProccessed: isProcessed
        )
    }
}

extension PersistedNotification {
    func toLocal() -> OpenEmailModel.Notification {
        OpenEmailModel.Notification(
            id: id,
            receivedOn: receivedOn,
            link: link,
            address: address,
            authorFingerPrint: authorFingerPrint,
            isProccessed: isProccessed
        )
    }
}
