import SwiftUI
import OpenEmailCore
import Logging

struct ProfileEditorTabView: View {
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?
    @State private var viewModel = ProfileEditorViewModel()
    @State private var selectedGroup: ProfileAttributesGroupType?

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedGroup) {
                if let profile = viewModel.profile {
                    ForEach(profile.groupedAttributes) { group in
                        NavigationLink(value: group.groupType) {
                            ProfileEditorGroupItemView(group: group, isSelected: false, onSelection: {})
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Profile")
        } detail: {
            if let selectedGroup {
                Text("Group: \(selectedGroup)")
            }
        }
        .onAppear {
            reloadProfile()
        }
        .onChange(of: registeredEmailAddress) {
            reloadProfile()
        }
        .onChange(of: viewModel.profile) {
            viewModel.updateProfile()
        }
    }

    private func reloadProfile() {
        Task {
            do {
                try await viewModel.loadProfile()
            } catch {
                // TODO: show error
                Log.error("Could not load profile: \(error)")
            }
        }
    }
}

#Preview {
    ProfileEditorTabView()
}
