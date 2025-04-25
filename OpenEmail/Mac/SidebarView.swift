import SwiftUI
import Combine
import OpenEmailCore

struct SidebarView: View {
    @Environment(NavigationState.self) private var navigationState
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?
    @Binding private var viewModel: ScopesSidebarViewModel
    
    init (scopesSidebarViewModel: Binding<ScopesSidebarViewModel>) {
        _viewModel = scopesSidebarViewModel
    }

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
            
            Spacer()
            ProfileButton()
        }
        .padding(.horizontal, .Spacing.xSmall)
        .padding(.bottom, .Spacing.default)
        .frame(maxHeight: .infinity, alignment: .top)
        .onChange(of: navigationState.selectedScope) {
            viewModel.selectedScope = navigationState.selectedScope
        }
    }
}

private struct ProfileButton: View {
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?
    @AppStorage(UserDefaultsKeys.profileName) private var profileName: String?

    @Environment(\.openWindow) private var openWindow

    @State private var isHovering = false
    @State private var isPressed = false

    var body: some View {
        Button {
            openWindow(id: WindowIDs.profileEditor)
        } label: {
            HStack(spacing: .Spacing.small) {
                ProfileImageView(emailAddress: registeredEmailAddress, size: 26)
                VStack(alignment: .leading, spacing: 0) {
                    Text(profileName ?? "No Name").bold()
                        .foregroundStyle(.primary)
                    Text(registeredEmailAddress ?? "").font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(4)
            .background {
                if isHovering {
                    RoundedRectangle(cornerRadius: .CornerRadii.small)
                        .foregroundStyle(.tertiary)
                }
            }
            .animation(.default, value: isHovering)
            .onHover {
                isHovering = $0
                if !isHovering {
                    isPressed = false
                }
            }
        }
        .buttonStyle(.plain)
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
                RoundedRectangle(cornerRadius: .CornerRadii.small, style: .circular)
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
    SidebarView(scopesSidebarViewModel: Binding<ScopesSidebarViewModel>(
        get: {
            ScopesSidebarViewModel()
        },
        set: { _ in }
    ))
    .frame(height: 800)
    .environment(NavigationState())
}
