import Foundation
import OpenEmailModel
import Observation

@Observable class NavigationState {
    var selectedMessageThreads: Set<MessageThread> = []
    var selectedScope: SidebarScope = .messages {
        didSet {
            clearSelection()
        }
    }
    var selectedContact: ContactListItem? = nil
    
    func clearSelection() {
        selectedMessageThreads.removeAll()
        selectedContact = nil
    }
}
