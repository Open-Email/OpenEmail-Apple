import SwiftUI
import OpenEmailModel
import OpenEmailCore

struct ContactsProfileAttributesEditorView: View {
    @Binding var profile: Profile

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .Spacing.default) {
                Text("Contacts").font(.title2)

                Grid(horizontalSpacing: .Spacing.large, verticalSpacing: .Spacing.large) {
                    GridRow {
                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            OpenEmailTextFieldLabel(ProfileAttribute.website.displayTitle)
                            TextField("Enter your website", text: $profile.website)
                                .textFieldStyle(.openEmail)
                        }

                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            OpenEmailTextFieldLabel(ProfileAttribute.location.displayTitle)
                            TextField("Enter your location", text: $profile.location)
                                .textFieldStyle(.openEmail)
                        }
                    }

                    GridRow {
                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            OpenEmailTextFieldLabel(ProfileAttribute.mailingAddress.displayTitle)
                            TextField("Enter your mailing address", text: $profile.mailingAddress)
                                .textFieldStyle(.openEmail)
                        }

                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            OpenEmailTextFieldLabel(ProfileAttribute.phone.displayTitle)
                            TextField("Enter your phone number", text: $profile.phone)
                                .textFieldStyle(.openEmail)
                        }
                    }

                    GridRow {
                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            OpenEmailTextFieldLabel(ProfileAttribute.streams.displayTitle)
                            TextField("Enter your streams", text: $profile.streams)
                                .textFieldStyle(.openEmail)
                        }
                        .gridCellColumns(2)
                    }
                }
            }
            .padding(.Spacing.default)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .background(.themeViewBackground)
    }
}

#Preview {
    @Previewable @State var profile: Profile = .makeFake()
    HStack {
        ContactsProfileAttributesEditorView(profile: $profile)
    }
    .frame(height: 800)
}
