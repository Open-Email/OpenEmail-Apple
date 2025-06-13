import Foundation
import OpenEmailCore
import SwiftUI

enum ProfileAttributesGroupType: String {
    case general
    case personal
    case work
    case interests
    case contacts
    case configuration

    var displayName: String {
        switch self {
        case .general: "General"
        case .work: "Work"
        case .personal: "Personal"
        case .interests: "Interests"
        case .contacts: "Contact"
        case .configuration: "Configuration"
        }
    }
    
    var shouldShowInPreview: Bool {
        switch self {
        case .configuration: return false
        default: return true
        }
    }
}

extension ProfileAttributesGroup {
    var icon: ImageResource {
        switch groupType {
            case .general: .ProfileAttributesGroup.general
            case .work: .ProfileAttributesGroup.work
            case .personal: .ProfileAttributesGroup.personal
            case .interests: .ProfileAttributesGroup.interests
            case .contacts: .ProfileAttributesGroup.contacts
            case .configuration: .ProfileAttributesGroup.configuration
        }
    }
}

struct ProfileAttributesGroup: Identifiable {
    let groupType: ProfileAttributesGroupType
    let attributes: [ProfileAttribute]
    var id: String { groupType.rawValue }
}

extension Profile {
    static let groupedAttributes: [ProfileAttributesGroup] = [
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
