import SwiftUI
import OpenEmailCore
import Logging

struct ProfileEditorView: View {
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?
    @State private var viewModel = ProfileEditorViewModel()
    @State private var selectedGroup: ProfileAttributesGroupType = .general

    private func makeProfileBinding() -> Binding<Profile?> {
        Binding(
            get: { viewModel.profile },
            set: { viewModel.profile = $0 }
        )
    }

    var body: some View {
        
        HSplitView {
            VStack(alignment: .leading) {
                Text("Profile")
                    .font(.title)
                    .fontWeight(.semibold)
                    .padding(.Spacing.default)

                List(
                    Profile.groupedAttributes,
                    selection: $selectedGroup
                ) { attribute in
                    ProfileEditorGroupItemView(group: attribute)
                        .listRowSeparator(.hidden)
                }.scrollContentBackground(.hidden)
                
            }
            .frame(width: 175)
            .background {
                    VisualEffectView(material: .sidebar)
                        .edgesIgnoringSafeArea(.all)
                }

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
            .frame(minWidth: 400, idealWidth: 600)
        }
        .background(.regularMaterial)
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

public func getEmptyBindingForField<T>(_ defaultValue: T) -> Binding<T> {
    return .constant(defaultValue)
}

#Preview {
    ProfileEditorView()
        .frame(width: 800, height: 600)
}

#Preview("Sidebar") {
    let profile = Profile.makeFake()

    List {
        ForEach(Profile.groupedAttributes) { group in
            ProfileEditorGroupItemView(group: group)
        }
    }
    .listStyle(.plain)
    .frame(width: 250, height: 500)
}
