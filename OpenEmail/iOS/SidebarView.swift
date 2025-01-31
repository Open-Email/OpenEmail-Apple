import SwiftUI
import OpenEmailCore

struct SidebarView: View {
    @Binding var selectedScope: SidebarScope?
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?

    @State private var viewModel = ScopesSidebarViewModel()

    @Injected(\.syncService) private var syncService

    var body: some View {
        List(selection: $selectedScope) {
            Section {
                ForEach(viewModel.items) { item in
                    NavigationLink(value: item.scope) {
                        Image(item.scope.imageResource)
                            .foregroundStyle(.accent)

                        HStack {
                            Text(item.scope.displayName)
                        }
                    }
                }
            } header: {
            } footer: {
                VStack {
                    HStack {
                        Spacer()
                        Image(.logo)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 24)
                        Spacer()
                    }

                    nextSyncInfo
                }
                .padding()
            }
        }
        .listStyle(.insetGrouped)
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
        HStack {
            Image(systemName: "arrow.triangle.2.circlepath")
            Group {
                let syncDate = syncService.nextSyncDate ?? .distantFuture
                Text("Next sync in ") + Text(syncDate, format: .relative(presentation: .numeric))
            }
            .fontWeight(.medium)
            .monospacedDigit()
        }
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
