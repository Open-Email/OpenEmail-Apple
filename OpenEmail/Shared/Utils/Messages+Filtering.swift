import Foundation
import OpenEmailModel
import OpenEmailCore

enum SidebarScope: String, CaseIterable, Identifiable {
    case broadcasts
    case inbox
    case outbox
    case drafts
    case trash
    case contacts

    var id: String { rawValue }
}

extension [Message] {
    var unreadCount: Int {
        filter { $0.isRead == false }.count
    }

    func filteredBy(scope: SidebarScope, localUser: LocalUser) -> [Message] {
        switch scope {
        case .broadcasts:
            filter {
                $0.isBroadcast && EmailAddress($0.author) != localUser.address && $0.deletedAt == nil && !$0.isDraft
            }
        case .inbox:
            filter {
                $0.readers.contains(localUser.address.address) && $0.deletedAt == nil && !$0.isDraft
            }
        case .outbox:
            filter {
                EmailAddress($0.author) == localUser.address && $0.deletedAt == nil && !$0.isDraft
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
