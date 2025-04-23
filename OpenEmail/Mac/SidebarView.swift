import SwiftUI
import Combine
import OpenEmailCore

private let itemHeight: CGFloat = 48
private let iconSize: CGFloat = 24

struct SidebarView: View {
    @Environment(NavigationState.self) private var navigationState
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?
    @State private var viewModel = ScopesSidebarViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: .Spacing.default) {
            Image(.logo)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: itemHeight)
                .padding(.horizontal, 10)
                .padding(.bottom, .Spacing.xSmall)

            ForEach(viewModel.items) { item in
                SidebarItemView(
                    icon: item.scope.imageResource,
                    title: item.scope.displayName,
                    isSelected: item.scope.id == viewModel.selectedScope.id,
                    unreadCount: item.unreadCount
                ) {
                    navigationState.selectedScope = item.scope
                }
                .frame(maxWidth: .sidebarWidth, alignment: .leading)
            }
        }
        .frame(width: .sidebarWidth)
        .padding(.horizontal, .Spacing.xSmall)
        .padding(.bottom, .Spacing.default)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.themeBackground)
        .onChange(of: navigationState.selectedScope) {
            viewModel.selectedScope = navigationState.selectedScope
        }
    }
}

private struct SidebarItemView: View {
    let icon: ImageResource
    let title: String
    let isSelected: Bool
    let unreadCount: Int
    let onSelection: () -> Void

    var body: some View {
        HStack {
            Image(icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)

            Text(title)
                .fontWeight(.medium)
            
            Spacer()
            if unreadCount > 0 {
                Text("\(unreadCount)")
            }
        }
        .foregroundStyle(isSelected ? .themePrimary : .themeSecondary)
        .padding(.horizontal, .Spacing.small)
        .frame(height: itemHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: .CornerRadii.default, style: .circular)
                    .fill(.themeIconBackground)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelection()
        }
    }
}

#Preview {
        SidebarView()
            .frame(height: 800)
            .environment(NavigationState())
}
