import SwiftUI

struct ProfileEditorGroupItemView: View {
    let group: ProfileAttributesGroup
    var body: some View {
        Label(title: {
            Text(group.groupType.displayName)
        }, icon: {
            Image(group.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .padding(4)
        }).tag(group.groupType)
    }
}

private extension ProfileAttributesGroup {
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

#Preview {
    let groups: [ProfileAttributesGroupType] = [.general, .work, .personal]

    List(groups, id: \.self) { groupType in
        NavigationLink(value: groupType) {
            ProfileEditorGroupItemView(group: .init(groupType: groupType, attributes: []))
        }
    }
}
