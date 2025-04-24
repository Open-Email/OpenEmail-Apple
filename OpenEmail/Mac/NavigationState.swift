import Foundation
import Observation

@Observable class NavigationState {
    var selectedMessageIDs: Set<String> = []
    var selectedScope: SidebarScope = .inbox
    var selectedContact: ContactListItem? = nil
}
