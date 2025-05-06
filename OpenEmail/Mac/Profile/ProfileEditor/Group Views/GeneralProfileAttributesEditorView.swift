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
                generalSection
            }
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

    @ViewBuilder
    private var generalSection: some View {
        HStack(alignment: .top, spacing: .Spacing.large) {
            profileImageView

            VStack(alignment: .leading, spacing: .Spacing.small) {
                HStack {
                    OpenEmailTextFieldLabel("Name:")

                    TextField(
                        "Name",
                        text: Binding($profile)?.name ?? Binding<String>(
                            get: {""
                            },
                            set: {_ in }),
                    ).textFieldStyle(.openEmail)
                    
                }
                
                if let profile = Binding($profile) {
                    Text(profile.wrappedValue.address.address)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                
                VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                    Toggle(
                        ProfileAttribute.away.displayTitle,
                        isOn: Binding($profile)?.away ?? Binding<Bool>(
                            get: {false
                            },
                            set: {_ in })
                    )
                    .toggleStyle(.switch)

                    if profile?[boolean: .away] == true {
                        TextField(
                            "Away warning",
                            text: Binding($profile)?.awayWarning ?? Binding<String>(
                                get: {""
                                },
                                set: {_ in })
                        )
                        .textFieldStyle(.openEmail)
                    }
                }
                currentSection
            }.animation(.default, value: profile?.away)
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
        Text("Current").font(.title2)
            .padding(.top, .Spacing.xSmall)

        HStack {
            OpenEmailTextFieldLabel("Status:")
            TextField(
                "Share your mood, plans, etc.",
                text: Binding($profile)?.status ?? Binding<String>(
                    get: {""
                    },
                    set: {_ in })
            )
                .textFieldStyle(.openEmail)
        }

        HStack {
            OpenEmailTextFieldLabel("About:")
            TextField(
                "About",
                text: Binding($profile)?.about ?? Binding<String>(
                    get: {""
                    },
                    set: {_ in })
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
