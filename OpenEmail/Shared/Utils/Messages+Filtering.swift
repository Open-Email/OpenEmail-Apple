import Foundation
import OpenEmailModel
import OpenEmailCore

enum SidebarScope: String, CaseIterable, Identifiable {
    case messages
    case drafts
    case trash
    case contacts

    var id: String { rawValue }
}

extension [Message] {
   
    func filteredBy(scope: SidebarScope) -> [Message] {
        switch scope {
        case .messages:
            filter {
                $0.deletedAt == nil && !$0.isDraft
            }
        case .drafts:
            filter {
                $0.deletedAt == nil && $0.isDraft
            }
        case .trash:
            filter {
                $0.deletedAt != nil
            }
        case .contacts:
            []
        }
    }
}

extension Message {
    func isOutbox() -> Bool {
        self.author == LocalUser.current?.address.address
    }
}
