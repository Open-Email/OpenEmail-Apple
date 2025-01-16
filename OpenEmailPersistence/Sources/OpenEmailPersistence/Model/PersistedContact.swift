import Foundation
import SwiftData

@Model
class PersistedContact {
    @Attribute(.unique) var id: String
    var addedOn: Date
    var address: String
    var name: String?
    var cachedProfileImageURL: URL?
    var receiveBroadcasts: Bool

    init(id: String, addedOn: Date, address: String, receiveBroadcasts: Bool, name: String?, cachedProfileImageURL: URL?) {
        self.id = id
        self.addedOn = addedOn
        self.address = address
        self.receiveBroadcasts = receiveBroadcasts
        self.name = name
        self.cachedProfileImageURL = cachedProfileImageURL
    }
}
