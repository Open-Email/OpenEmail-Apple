import Foundation
import SwiftUI

extension SidebarScope {
    var imageResource: ImageResource {
        switch self {
        case .broadcasts: .scopeBroadcasts
        case .inbox: .scopeInbox
        case .outbox: .scopeOutbox
        case .drafts: .scopeDrafts
        case .trash: .scopeTrash
        case .contacts: .scopeContacts
        }
    }

    var displayName: String {
        switch self {
        case .broadcasts: "Broadcasts"
        case .inbox: "Inbox"
        case .outbox: "Outbox"
        case .drafts: "Drafts"
        case .trash: "Trash"
        case .contacts: "Contacts"
        }
    }
}
