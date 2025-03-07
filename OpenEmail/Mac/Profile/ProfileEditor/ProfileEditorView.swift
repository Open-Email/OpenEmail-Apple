import SwiftUI
import OpenEmailCore
import Logging

struct ProfileEditorView: View {
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?
    @State private var viewModel = ProfileEditorViewModel()
    @State private var selectedGroup: ProfileAttributesGroupType = .general

    private func makeProfileBinding() -> Binding<Profile> {
        Binding(
            get: { viewModel.profile! },
            set: { viewModel.profile = $0 }
        )
    }

    var body: some View {
        Group {
            if let profile = viewModel.profile {
                HSplitView {
                    VStack(alignment: .leading) {
                        Text("Profile")
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .padding(.Spacing.default)

                        List {
                            ForEach(profile.groupedAttributes) { group in
                                ProfileEditorGroupItemView(group: group, isSelected: group.groupType == selectedGroup) {
                                    selectedGroup = group.groupType
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .listStyle(.plain)
                        .background(.themeViewBackground)
                    }
                    .frame(maxHeight: .infinity)
                    .frame(width: 250)

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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                if viewModel.isLoadingProfile {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("No profile found")
                        .bold()
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .background(.themeViewBackground)
        .frame(minHeight: 500)
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
    ProfileEditorView()
        .frame(width: 800, height: 600)
}

#Preview("Sidebar") {
    let profile = Profile.makeFake()

    List {
        ForEach(profile.groupedAttributes) { group in
            ProfileEditorGroupItemView(group: group, isSelected: group.groupType == .general) {
            }
        }
    }
    .scrollContentBackground(.hidden)
    .listStyle(.plain)
    .background(.themeViewBackground)
    .frame(width: 250, height: 500)
}
