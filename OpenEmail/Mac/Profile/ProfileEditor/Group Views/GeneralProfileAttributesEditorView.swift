import SwiftUI
import OpenEmailModel
import OpenEmailCore
import AppKit
import Logging

struct GeneralProfileAttributesEditorView: View {
    @Binding var profile: Profile
    var didChangeImage: (NSImage?, Data?) -> Void 

    @State private var showingImagePicker = false
    @State private var image: NSImage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .Spacing.default) {
                generalSection

                Divider()

                currentSection
            }
            .padding(.Spacing.default)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .background(.themeViewBackground)
        .fileImporter(isPresented: $showingImagePicker, allowedContentTypes: [.image]) { result in
            do {
                let fileUrl = try result.get()

                let isSecurityScoped = fileUrl.startAccessingSecurityScopedResource()

                defer {
                    if isSecurityScoped {
                        fileUrl.stopAccessingSecurityScopedResource()
                    }
                }

                guard let selectedImage = NSImage(contentsOf: fileUrl) else {
                    Log.error("Could not create image from \(fileUrl)")
                    return
                }

                guard let resizedImageData = selectedImage.resizeAndCrop(targetSize: PROFILE_IMAGE_SIZE) else {
                    Log.error("Could not resize image")
                    return
                }

                let resizedImage = NSImage(data: resizedImageData)
                didChangeImage(resizedImage, resizedImageData)
                self.image = resizedImage
            } catch {
                Log.error("Could not get image file url: \(error)")
            }
        }
    }

    @ViewBuilder
    private var generalSection: some View {
        Text("General").font(.title2)

        HStack(alignment: .top, spacing: .Spacing.large) {
            profileImageView

            VStack(alignment: .leading, spacing: .Spacing.small) {
                VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                    OpenEmailTextFieldLabel("Name")

                    TextField("Name", text: $profile.name, prompt: Text("Name"))
                        .textFieldStyle(.openEmail)
                }

                Text(profile.address.address)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                    Toggle(ProfileAttribute.away.displayTitle, isOn: $profile.away)
                        .toggleStyle(.switch)

                    if profile[boolean: .away] == true {
                        OpenEmailTextEditor(text: $profile.awayWarning)
                            .frame(height: 60)
                    }
                }
            }
        }
    }

    private var profileImageView: some View {
        ProfileImageView(
            emailAddress: profile.address.address,
            overrideImage: image?.swiftUIImage,
            shape: .roundedRectangle(cornerRadius: .CornerRadii.small),
            size: 288
        )
        .overlay(alignment: .topTrailing) {
            HStack(spacing: .Spacing.small) {
                Button {
                    showingImagePicker = true
                } label: {
                    Image(.editProfile)
                }

                Button {
                    deleteImage()
                } label: {
                    Image(.trash)
                }
            }
            .buttonStyle(ActionButtonStyle(isImageOnly: true, height: 32))
            .padding(.Spacing.xSmall)
        }
    }

    @ViewBuilder
    private var currentSection: some View {
        Text("Current").font(.title2)
            .padding(.bottom, .Spacing.xSmall)

        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
            OpenEmailTextFieldLabel("Status")
            TextField("Share your mood, plans, etc.", text: $profile.status)
                .textFieldStyle(.openEmail)
        }

        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
            HStack {
                OpenEmailTextFieldLabel(ProfileAttribute.about.displayTitle)

                if let info = ProfileAttribute.about.info {
                    InfoButton(text: info)
                }
            }

            OpenEmailTextEditor(text: $profile.about)
                .frame(height: 112)
        }
    }

    // MARK: - Helpers

    private func deleteImage() {
        image = nil
        didChangeImage(nil, nil)
    }
}

#Preview {
    @Previewable @State var profile: Profile = .makeFake()
    HStack {
        GeneralProfileAttributesEditorView(profile: $profile, didChangeImage: { _, _ in })
    }
    .frame(height: 800)
}
