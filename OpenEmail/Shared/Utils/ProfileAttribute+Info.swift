import Foundation

import OpenEmailCore

extension ProfileAttribute {
    var info: String? {
        switch self {
        case .about: return "A brief description about self"
        case .organization: return "The organization associated with"
        case .jobTitle: return "Work or position description"
        case .publicAccess: return "When enabled, contact requests are accepted, otherwise ignored."
        case .publicLinks: return "When enabled, existence of a particular contact in address book may be queried."
        case .lastSeenPublic: return "When enabled, last activity time is made public."
        case .addressExpansion: return "Address expansions allow replacing own address with other destinations."
        default: return nil
        }
    }
}
