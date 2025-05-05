import SwiftUI
import OpenEmailCore

struct SidebarView: View {
    @Environment(NavigationState.self) var navigationState
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?

    @State private var viewModel = ScopesSidebarViewModel()

    @Injected(\.syncService) private var syncService

    var body: some View {
        List(selection: $selectedScope) {
            Section {
                ForEach(viewModel.items) { item in
                    NavigationLink(value: item.scope) {
                        HStack {
                            Image(item.scope.imageResource)
                            Text(item.scope.displayName).fontWeight(.medium)
                        }
                    }
                    .padding(.vertical, .Spacing.xSmall)
                    .if(item.scope == .broadcasts) {
                        $0.listRowSeparator(.hidden, edges: .top)
                    }
                    .if(item.scope == .trash) {
                        $0.listRowSeparator(.hidden, edges: .bottom)
                    }
                }
            } header: {
                VStack(alignment: .leading) {
                    Image(.logo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: .Spacing.xLarge)
                }
                .padding(.vertical, .Spacing.default)
            } footer: {
                nextSyncInfo
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
            await viewModel.reloadItems(isInitialUpdate: true)
        }
    }

    private func reloadItems() {
        Task {
            await viewModel.reloadItems(isInitialUpdate: false)
        }
    }

    @ViewBuilder
    private var nextSyncInfo: some View {
        HStack(spacing: .Spacing.xSmall) {
            Image(.refresh)
            Group {
                let syncDate = syncService.nextSyncDate ?? .distantFuture
                Text("Next sync in ") + Text(syncDate, format: .relative(presentation: .numeric))
            }
            .fontWeight(.medium)
            .monospacedDigit()
            .foregroundStyle(.primary)
        }
        .padding(.top, .Spacing.large)
    }
}

#if DEBUG

private struct ScopesSidebarViewPreviewContainer: View {
    @State private var scope: SidebarScope?

    var body: some View {
        SidebarView(selectedScope: $scope)
    }
}

#Preview {
    ScopesSidebarViewPreviewContainer()
}

#endif
