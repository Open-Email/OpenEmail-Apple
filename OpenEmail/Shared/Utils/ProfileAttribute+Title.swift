import Foundation
import OpenEmailCore

extension ProfileAttribute {
    var displayTitle: String {
        switch self {
        case .about: return "About"
        case .addressExpansion: return "Address expansion"
        case .away: return "Away"
        case .awayWarning: return "Away message"
        case .birthday: return "Birthday"
        case .books: return "Books"
        case .department: return "Department"
        case .education: return "Education"
        case .encryptionKey: return "Encryption key"
        case .gender: return "Gender"
        case .interests: return "Interests"
        case .jobTitle: return "Job title"
        case .languages: return "Languages"
        case .lastSigningKey: return "Last signing key"
        case .location: return "Location"
        case .mailingAddress: return "Mailing address"
        case .movies: return "Movies"
        case .music: return "Music"
        case .name: return "Name"
        case .notes: return "Notes"
        case .organization: return "Organization"
        case .phone: return "Phone"
        case .placesLived: return "Places lived"
        case .publicAccess: return "Public access"
        case .relationshipStatus: return "Relationship status"
        case .signingKey: return "Signing key"
        case .sports: return "Sports"
        case .status: return "Status"
        case .streams: return "Streams"
        case .website: return "Website"
        case .work: return "Work"
        case .lastSeenPublic: return "Last seen public"
        case .lastSeen: return "Last seen"
        case .updated: return "Updated"
        case .publicLinks: return "Public links querying"
        }
    }
}
