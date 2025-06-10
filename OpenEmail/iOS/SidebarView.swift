import SwiftUI
import OpenEmailCore

struct SidebarView: View {
    @Environment(NavigationState.self) private var navigationState
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?

    @State private var viewModel = ScopesSidebarViewModel()

    @Injected(\.syncService) private var syncService

    var body: some View {
        List(selection: Binding<SidebarScope?>(
            get: { navigationState.selectedScope },
            set: { navigationState.selectedScope = $0 ?? .inbox }
        )) {
            ForEach(viewModel.items, id: \.scope) { item in
                HStack {
                    Image(item.scope.imageResource)
                    Text(item.scope.displayName)
                        .fontWeight(.medium)
                    Spacer()
                    if item.unreadCount > 0 {
                        Text("\(item.unreadCount)").badge(item.unreadCount)
                    }
                }
                .tag(item.scope)
                .padding(.vertical, .Spacing.xSmall)
            }
        }
        .listStyle(.grouped)
        .scrollContentBackground(.hidden)
        .refreshable {
            await syncService.synchronize()
        }
        .navigationTitle("Folders")
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
            await viewModel.reloadItems()
        }
    }

    private func reloadItems() {
        Task {
            await viewModel.reloadItems()
        }
    }
}

#if DEBUG

private struct ScopesSidebarViewPreviewContainer: View {

    var body: some View {
        SidebarView()
    }
}

#Preview {
    ScopesSidebarViewPreviewContainer()
}

#endif
