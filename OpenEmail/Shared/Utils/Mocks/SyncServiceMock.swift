import Foundation
import OpenEmailCore

#if DEBUG
class SyncServiceMock: MessageSyncing {
    var isSyncing: Bool = false
    func synchronize() async {}
    func fetchAuthorMessages(profile: Profile, includeBroadcasts: Bool) async {}
}
#endif
