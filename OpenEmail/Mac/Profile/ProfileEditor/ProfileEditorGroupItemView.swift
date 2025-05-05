import SwiftUI

struct ProfileEditorGroupItemView: View {
    let group: ProfileAttributesGroup
    let isSelected: Bool
    let onSelection: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: .Spacing.xSmall) {
            icon
            Text(group.groupType.displayName).foregroundStyle(isSelected ? .themePrimary : .themeSecondary)
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
        ZStack {
            Circle()
                .fill(isSelected ? .themePrimary : .themeIconBackground)
                .frame(width: 24, height: 24)
                .overlay {
                    if colorScheme == .light {
                        Circle().stroke(Color.themeLineGray)
                    }
                }

            Image(group.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(isSelected ? .themeViewBackground : .themePrimary)
        }
        .frame(width: 24, height: 24)
        .clipShape(Circle())
        .shadow(color: .themeShadow, radius: 4, y: 2)
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
