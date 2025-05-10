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
            ForEach(viewModel.items) { item in
                if (item.scope == .broadcasts) {
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
        .padding(.Spacing.xSmall)
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
    @State var isHovering: Bool = false

    var body: some View {
        Button {
            openWindow(id: WindowIDs.profileEditor)
        } label: {
            HStack(spacing: .Spacing.small) {
                ProfileImageView(
                    emailAddress: registeredEmailAddress,
                    size: .small
                )
                VStack(alignment: .leading, spacing: 0) {
                    if let name = profileName {
                        Text(name)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .font(.headline)
                    }
                    
                    if let address = registeredEmailAddress {
                        Text(address)
                            .font(.subheadline)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                            .truncationMode(.tail)
                    }
                }
            }
            .padding(.Spacing.xSmall)
            .onHover { isHovering in
                self.isHovering = isHovering
            }
            .background(
                RoundedRectangle(cornerRadius: .CornerRadii.small, style: .circular)
                    .fill(isHovering ? .themeIconBackground : Color.clear)
            )
            
            
        }.buttonStyle(.borderless)
            
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
                .foregroundStyle(.accent)

            Text(title)
            
            Spacer()
            if unreadCount > 0 {
                Text("\(unreadCount)")
            }
        }
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
