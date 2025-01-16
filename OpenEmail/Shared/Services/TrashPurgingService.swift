import Foundation
import OpenEmailPersistence

class TrashPurgingService {
    private var timer: Timer?

    @Injected(\.messagesStore) private var messagesStore

    init() {
        // run immediately after launch
        purge()

        // schedule to run every 12 hours
        timer = .scheduledTimer(withTimeInterval: .hours(12), repeats: true) { _ in
            self.purge()
        }
    }

    private func purge() {
        let deletionDays = UserDefaults.standard.automaticTrashDeletionDays

        guard deletionDays > 0 else {
            return
        }

        let targetDate = Date.now.addingDays(-deletionDays)

        Task {
            let deletedMessages = (try? await messagesStore.allDeletedMessages()) ?? []
            for message in deletedMessages {
                guard let deletedAt = message.deletedAt else { continue }

                if deletedAt <= targetDate {
                    try? await messagesStore.deleteMessage(id: message.id)
                }
            }
        }
    }
}
