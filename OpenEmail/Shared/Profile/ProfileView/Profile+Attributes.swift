import Foundation
import OpenEmailCore

enum ProfileAttributesGroupType: String {
    case general
    case personal
    case work
    case interests
    case contacts
    case configuration
}

struct ProfileAttributesGroup: Identifiable {
    let groupType: ProfileAttributesGroupType
    let attributes: [ProfileAttribute]
    var id: String { groupType.rawValue }

    var displayName: String {
        switch groupType {
        case .general: "General"
        case .work: "Work"
        case .personal: "Personal"
        case .interests: "Interests"
        case .contacts: "Contacts"
        case .configuration: "Configuration"
        }
    }
}

extension Profile {
    var groupedAttributes: [ProfileAttributesGroup] {
        [
            ProfileAttributesGroup(
                groupType: .general,
                attributes: [
                    .status,
                    .about
                ]
            ),
            ProfileAttributesGroup(
                groupType: .personal,
                attributes: [
                    .gender,
                    .relationshipStatus,
                    .birthday,
                    .education,
                    .languages,
                    .placesLived,
                    .notes
                ]
            ),
            ProfileAttributesGroup(
                groupType: .work,
                attributes: [
                    .work,
                    .organization,
                    .department,
                    .jobTitle
                ]
            ),
            ProfileAttributesGroup(
                groupType: .interests,
                attributes: [
                    .interests,
                    .books,
                    .movies,
                    .music,
                    .sports
                ]
            ),
            ProfileAttributesGroup(
                groupType: .contacts,
                attributes: [
                    .website,
                    .location,
                    .mailingAddress,
                    .phone,
                    .streams
                ]
            ),
            ProfileAttributesGroup(
                groupType: .configuration,
                attributes: [
                    .publicAccess,
                    .publicLinks,
                    .lastSeenPublic,
                    .lastSeen,
                    .addressExpansion
                ]
            )
        ]
    }

    func isGroupEmpty(group: ProfileAttributesGroup) -> Bool {
        for attribute in group.attributes {
            if self[attribute] != nil {
                return false
            }
        }

        return true
    }
}

enum ProfileAttributeType {
    case text(multiline: Bool)
    case boolean
    case date(relative: Bool)
}

extension ProfileAttribute {
    var attributeType: ProfileAttributeType {
        switch self {
        case .about, .notes:
            return .text(multiline: true)
        case .away, .publicAccess, .publicLinks, .lastSeenPublic:
            return .boolean
        case .lastSeen:
            return .date(relative: true)
        default:
            return .text(multiline: false)
        }
    }
}
