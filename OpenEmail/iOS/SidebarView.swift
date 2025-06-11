import SwiftUI
import OpenEmailCore

struct SidebarView: View {
    @Environment(NavigationState.self) private var navigationState
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?

    @State private var viewModel = ScopesSidebarViewModel()

    @Injected(\.syncService) private var syncService

   
    var body: some View {
        List(viewModel.items, selection: Binding<SidebarScope?>(
            get: { navigationState.selectedScope },
            set: {
                if let scope = $0 {
                    navigationState.selectedScope = scope
                }
            }
        )) { item in
            Label(title: {
                Text(item.scope.displayName)
            }, icon: {
                Image(item.scope.imageResource)
            }).tag(item.scope)
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
