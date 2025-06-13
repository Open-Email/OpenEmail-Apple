import SwiftUI
import OpenEmailCore
import Logging

struct ProfileEditorTabView: View {
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?
    @State private var viewModel = ProfileEditorViewModel()
    @State private var selectedGroup: ProfileAttributesGroupType?

    var body: some View {
        NavigationSplitView {
            List(Profile.groupedAttributes, selection: $selectedGroup) { group in
                Label(title: {
                    Text(group.groupType.displayName)
                }, icon: {
                    Image(group.icon)
                }).tag(group.groupType)
                
            }
            .navigationTitle("Profile")
        } detail: {
            if let selectedGroup {
                Group {
                    switch selectedGroup {
                    case .general: GeneralProfileAttributesEditorView(profile: makeProfileBinding(), didChangeImage: { image, imageData in
                        viewModel.profileImage = image
                        viewModel.profileImageData = imageData
                        viewModel.didChangeImage = true
                        viewModel.updateProfile()
                    })
                    case .personal: PersonalProfileAttributesEditorView(profile: makeProfileBinding())
                    case .work: WorkProfileAttributesEditorView(profile: makeProfileBinding())
                    case .interests: InterestsProfileAttributesEditorView(profile: makeProfileBinding())
                    case .contacts: ContactsProfileAttributesEditorView(profile: makeProfileBinding())
                    case .configuration: ConfigurationProfileAttributesEditorView(profile: makeProfileBinding())
                    }
                }
                .navigationTitle(selectedGroup.displayName)
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

    private func makeProfileBinding() -> Binding<Profile> {
        Binding(
            get: { viewModel.profile! },
            set: { viewModel.profile = $0 }
        )
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
