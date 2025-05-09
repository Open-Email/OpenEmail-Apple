import Foundation

import OpenEmailCore

extension ProfileAttribute {
    var info: String? {
        switch self {
        case .publicAccess: return "When disabled, contact requests are automatically ignored."
        case .publicLinks: return "When enabled, contacts in your address book are made public."
        case .lastSeenPublic: return "When enabled, the time of your last activity is made public."
        case .addressExpansion: return "Allows replacing your own address with alternative destinations."
        default: return nil
        }
    }
}
