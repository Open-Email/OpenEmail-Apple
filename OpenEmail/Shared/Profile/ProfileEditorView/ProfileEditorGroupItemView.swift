import SwiftUI

struct ProfileEditorGroupItemView: View {
    let group: ProfileAttributesGroup
    let isSelected: Bool
    let onSelection: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
#if os(iOS)
            Image(group.icon)
            Text(group.groupType.displayName)
                .fontWeight(.medium)
#else
            icon
            Text(group.groupType.displayName)
                .foregroundStyle(isSelected ? .themePrimary : .themeSecondary)
#endif
        }
#if os(iOS)
        .padding(.vertical, .Spacing.xSmall)
#else
        .foregroundStyle(isSelected ? .themePrimary : .themeSecondary)
        .padding(.horizontal, .Spacing.small)
        .frame(height: 60)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelection()
        }
#endif
    }

    @ViewBuilder
    private var icon: some View {
        ZStack {
            Circle()
                .fill(isSelected ? .themePrimary : .themeIconBackground)
                .frame(width: 40, height: 40)
                .overlay {
                    if colorScheme == .light {
                        Circle().stroke(Color.themeLineGray)
                    }
                }

            Image(group.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundStyle(isSelected ? .themeBackground : .themePrimary)
        }
        .frame(width: 40, height: 40)
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
    .listStyle(.plain)
}
