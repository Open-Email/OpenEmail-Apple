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
                if item.scope == .contacts {
                    Spacer()
                }

                SidebarItemView(
                    icon: item.scope.imageResource,
                    title: item.scope.displayName,
                    subtitle: item.subtitle,
                    isSelected: item.scope.id == navigationState.selectedScope.id,
                    showsNewMessagesIndicator: item.shouldShowNewMessageIndicator
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
        .onChange(of: registeredEmailAddress) {
            reloadItems()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateNotifications)) { _ in
            reloadItems()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateMessages)) { _ in
            reloadItems()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateContacts)) { _ in
            reloadItems()
        }
        .task {
            await viewModel.reloadItems(isInitialUpdate: true)
        }
    }

    private func reloadItems() {
        Task {
            await viewModel.reloadItems(isInitialUpdate: false)
        }
    }
}

private struct SidebarItemView: View {
    let icon: ImageResource
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let showsNewMessagesIndicator: Bool
    let onSelection: () -> Void

    var body: some View {
        HStack {
            Image(icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)

            VStack(alignment: .leading, spacing: 0) {
                Text(title).bold()

                if let subtitle {
                    Text(subtitle)
                        .foregroundStyle(.accent)
                        .font(.footnote)
                }
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
        .overlay(alignment: .trailing) {
            if showsNewMessagesIndicator {
                Circle()
                    .fill(.accent)
                    .frame(width: 8)
                    .offset(x: -.Spacing.small)
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
