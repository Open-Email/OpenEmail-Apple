import Foundation
import SwiftUI

extension SidebarScope {
    var imageResource: ImageResource {
        switch self {
        case .messages: .scopeInbox
        case .drafts: .scopeDrafts
        case .trash: .scopeTrash
        case .contacts: .scopeContacts
        }
    }

    var displayName: String {
        switch self {
        case .messages: "Messages"
        case .drafts: "Drafts"
        case .trash: "Trash"
        case .contacts: "Contacts"
        }
    }
}
