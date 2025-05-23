import SwiftUI
import OpenEmailModel
import OpenEmailCore
import AppKit
import Logging

struct GeneralProfileAttributesEditorView: View {
    @Binding var profile: Profile?
    var didChangeImage: (NSImage?, Data?) -> Void

    @State private var showingImagePicker = false
    @State private var image: NSImage?

    var body: some View {
        ScrollView {
            VStack {
                profileImageView
                if let profile = Binding($profile) {
                    Text(profile.wrappedValue.address.address)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Form {
                    Section {
                        TextField(
                            "Name:",
                            text: Binding($profile)?.name ?? getEmptyBindingForField(""),
                        ).textFieldStyle(.openEmail)
                    }
                    
                    Section {
                        Toggle(
                            ProfileAttribute.away.displayTitle,
                            isOn: Binding($profile)?.away ?? getEmptyBindingForField(false)
                        )
                        .toggleStyle(.switch)
                        
                        if profile?[boolean: .away] == true {
                            TextField(
                                "Away warning",
                                text: Binding($profile)?.awayWarning ?? getEmptyBindingForField("")
                            )
                            .textFieldStyle(.openEmail)
                        }
                    }
                    currentSection
                }
                .formStyle(.grouped)
                .background(.regularMaterial)
                .navigationTitle("General")
                
            }.animation(.default, value: profile?.away)
            .padding(.Spacing.default)
            .frame(maxHeight: .infinity, alignment: .top)
        }
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

    private var profileImageView: some View {
        ProfileImageView(
            emailAddress: profile?.address.address,
            shape: .roundedRectangle(cornerRadius: .CornerRadii.small),
            size: .huge
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
        Section(header: Text("Current")) {
            TextField(
                "Status:",
                text: Binding($profile)?.status ?? getEmptyBindingForField(""),
                prompt: Text("Share your mood, plans, etc."),
            ).textFieldStyle(.openEmail)
            TextField(
                "About:",
                text: Binding($profile)?.about ?? getEmptyBindingForField(""),
                prompt: Text("About")
            )
            .textFieldStyle(.openEmail)
        }
    }

    // MARK: - Helpers

    private func deleteImage() {
        image = nil
        didChangeImage(nil, nil)
    }
}

#Preview {
    @Previewable @State var profile: Profile? = .makeFake()
    HStack {
        GeneralProfileAttributesEditorView(profile: $profile, didChangeImage: { _, _ in })
    }
    .frame(height: 800)
}
