import SwiftUI

struct ProfileEditorGroupItemView: View {
    let group: ProfileAttributesGroup
    let isSelected: Bool
    let onSelection: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: .Spacing.xSmall) {
            icon
            Text(group.groupType.displayName).foregroundStyle(.themePrimary)
            Spacer()
        }
        .padding(.horizontal, .Spacing.xSmall)
        .padding(.vertical, .Spacing.xxSmall)
        .frame(alignment: .leading)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: .CornerRadii.small, style: .circular)
                    .fill(.themeIconBackground)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: .CornerRadii.small, style: .circular))
        .onTapGesture {
            onSelection()
        }
    }

    @ViewBuilder
    private var icon: some View {
        Image(group.icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaledToFit()
            .frame(width: 14, height: 14)
            .foregroundStyle(.accent)
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
            ProfileEditorGroupItemView(group: .init(groupType: groupType, attributes: []), isSelected: false, onSelection: {})
        }
    }
}
