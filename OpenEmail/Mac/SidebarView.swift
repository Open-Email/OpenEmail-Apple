import SwiftUI
import Combine
import OpenEmailCore

struct SidebarView: View {
    @Environment(NavigationState.self) private var navigationState
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?
    @State private var viewModel = ScopesSidebarViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: .Spacing.xxxxSmall) {
            Image(.logo)
                //.resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 32, alignment: .leading)
                //.padding(.horizontal, .Spacing.xSmall)
                .padding(.bottom, .Spacing.default)

            ForEach(viewModel.items) { item in
                if (item.scope == .contacts) {
                    Spacer().frame(height: .Spacing.default)
                }
                SidebarItemView(
                    icon: item.scope.imageResource,
                    title: item.scope.displayName,
                    isSelected: item.scope.id == viewModel.selectedScope.id,
                    unreadCount: item.unreadCount
                ) {
                    navigationState.selectedScope = item.scope
                }
            }
        }
        //.listStyle(.sidebar)
        .padding(.horizontal, .Spacing.xSmall)
        .padding(.bottom, .Spacing.default)
        .frame(maxHeight: .infinity, alignment: .top)
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
                .frame(width: 14, height: 14)

            Text(title)
            
            Spacer()
            if unreadCount > 0 {
                Text("\(unreadCount)")
            }
        }
        .foregroundStyle(isSelected ? .themePrimary : .themeSecondary)
        .padding(.horizontal, .Spacing.xxSmall)
        .frame(height: 28, alignment: .leading)
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
