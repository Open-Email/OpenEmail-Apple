import SwiftUI

struct SidebarView: View {
    @Binding var selectedScope: SidebarScope?

    @State private var viewModel = ScopesSidebarViewModel()

    @Injected(\.syncService) private var syncService

    var body: some View {
        List(SidebarScope.allCases, selection: $selectedScope) { scope in
            NavigationLink(value: scope) {
                Image(scope.imageResource)
                    .foregroundStyle(.accent)

                HStack {
                    Text(scope.displayName)

                    let count = scope == .drafts ? viewModel.draftsCount : viewModel.currentUnreadCounts[scope] ?? 0
                    if count > 0 {
                        Spacer()
                        Text("\(count)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await syncService.synchronize()
        }
        .navigationTitle("Folders")
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
