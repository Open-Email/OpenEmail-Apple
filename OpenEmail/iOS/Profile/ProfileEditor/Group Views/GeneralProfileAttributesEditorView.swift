import SwiftUI
import PhotosUI
import OpenEmailModel
import OpenEmailCore
import Logging
import Utils

struct GeneralProfileAttributesEditorView: View {
    @Binding var profile: Profile
    var didChangeImage: (OEImage?) -> Void

    @State private var showingPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var image: OEImage?

    var body: some View {
        List {
            generalSection
            currentSection
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private var generalSection: some View {
        Section {
            profileImageView

            VStack(alignment: .leading, spacing: .Spacing.small) {
                TextField("Name", text: $profile.name, prompt: Text("Name"))
                    .textFieldStyle(.openEmail)

                Text(profile.address.address)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                    Toggle(ProfileAttribute.away.displayTitle, isOn: $profile.away)
                        .toggleStyle(.switch)
                        .tint(.accentColor)

                    if profile[boolean: .away] == true {
                        OpenEmailTextEditor(text: $profile.awayWarning)
                            .frame(height: 80)
                    }
                }
            }
        }
        .listRowSeparator(.hidden)
    }

    private var profileImageView: some View {
        VStack(spacing: .Spacing.large) {
            ProfileImageView(
                emailAddress: profile.address.address,
                overrideImage: image?.swiftUIImage,
                shape: .circle,
                size: 80,
                placeholder: { _ in
                    Image(.profileTab)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: .Spacing.xxLarge)
                }
            )

            HStack(spacing: .Spacing.default) {
                Button {
                    showingPhotoPicker = true
                } label: {
                    HStack {
                        Image(.editProfile)
                        Text("Edit")
                    }
                }

                Button {
                    deleteImage()
                } label: {
                    HStack {
                        Image(.trash)
                        Text("Delete")
                    }
                }
            }
            .buttonStyle(ActionButtonStyle(isImageOnly: true, height: 32))
            .padding(.Spacing.xSmall)
        }
        .frame(maxWidth: .infinity)
        .photosPicker(isPresented: $showingPhotoPicker, selection: $photoPickerItem, matching: .images)
        .onChange(of: photoPickerItem) {
            guard let photoPickerItem else { return }
            Task {
                do {
                    if let data = try await photoPickerItem.loadTransferable(type: Data.self) {
                        if let uiImage = UIImage(data: data) {
                            self.image = uiImage
                            didChangeImage(uiImage)
                        }
                    }
                } catch {
                    Log.error("Could not load image: \(error)")
                }

                self.photoPickerItem = nil
            }
        }
    }

    @ViewBuilder
    private var currentSection: some View {
        Section("Current") {
            VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                TextField("Share your mood, plans, etc.", text: $profile.status)
                    .textFieldStyle(.openEmail)
            }

            VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                VStack(alignment: .leading) {
                    OpenEmailTextFieldLabel(ProfileAttribute.about.displayTitle)
                    ProfileAttributeInfoText(.about)
                }

                OpenEmailTextEditor(text: $profile.about)
                    .frame(height: 120)
            }
        }
        .listRowSeparator(.hidden)
    }

    // MARK: - Helpers

    private func deleteImage() {
        image = nil
        didChangeImage(nil)
    }
}

#Preview {
    @Previewable @State var profile: Profile = .makeFake()
    GeneralProfileAttributesEditorView(profile: $profile, didChangeImage: { _ in })
}
