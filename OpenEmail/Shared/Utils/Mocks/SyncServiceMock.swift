import Foundation
import OpenEmailCore

#if DEBUG
class SyncServiceMock: MessageSyncing {
    var nextSyncDate: Date?

    var isSyncing: Bool = false

    func synchronize() async {}
    func fetchAuthorMessages(profile: Profile, includeBroadcasts: Bool) async {}
    func isActiveOutgoingMessageId(_ messageId: String) -> Bool {
        return true
    }
    func recallMessageId(_ messageId: String) {}
    func appendOutgoingMessageId(_ messageId: String) {}
}
#endif
