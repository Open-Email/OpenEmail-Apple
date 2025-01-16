import Foundation
import SwiftData

@Model
class PersistedNotification {
    @Attribute(.unique) var id: String
    var receivedOn: Date
    var link: String
    var address: String?
    var authorFingerPrint: String
    
    var isProccessed: Bool

    init(id: String, receivedOn: Date, link: String, address: String?, authorFingerPrint: String, isProccessed: Bool) {
        self.id = id
        self.receivedOn = receivedOn
        self.link = link
        self.address = address
        self.authorFingerPrint = authorFingerPrint
        self.isProccessed = isProccessed
    }

}
