import Foundation
import Observation

@Observable class NavigationState {
    var selectedMessageIDs: Set<String> = []
    var selectedScope: SidebarScope = .inbox {
        didSet {
            clearSelection()
        }
    }
    var selectedContact: ContactListItem? = nil
    
    func clearSelection() {
        selectedMessageIDs.removeAll()
        selectedContact = nil
    }
}
