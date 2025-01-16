import SwiftUI
import OpenEmailModel
import OpenEmailCore

struct ContactsProfileAttributesEditorView: View {
    @Binding var profile: Profile

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .Spacing.default) {
                Text("Personal").font(.title2)

                Grid(horizontalSpacing: .Spacing.large, verticalSpacing: .Spacing.large) {
                    GridRow {
                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            Text(ProfileAttribute.website.displayTitle)
                                .font(.callout)
                                .textCase(.uppercase)
                                .fontWeight(.medium)

                            TextField("Enter your website", text: $profile.website)
                                .textFieldStyle(.openEmail)
                        }

                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            Text(ProfileAttribute.location.displayTitle)
                                .font(.callout)
                                .textCase(.uppercase)
                                .fontWeight(.medium)

                            TextField("Enter your location", text: $profile.location)
                                .textFieldStyle(.openEmail)
                        }
                    }

                    GridRow {
                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            Text(ProfileAttribute.mailingAddress.displayTitle)
                                .font(.callout)
                                .textCase(.uppercase)
                                .fontWeight(.medium)

                            TextField("Enter your mailing address", text: $profile.mailingAddress)
                                .textFieldStyle(.openEmail)
                        }

                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            Text(ProfileAttribute.phone.displayTitle)
                                .font(.callout)
                                .textCase(.uppercase)
                                .fontWeight(.medium)

                            TextField("Enter your phone number", text: $profile.phone)
                                .textFieldStyle(.openEmail)
                        }
                    }

                    GridRow {
                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            Text(ProfileAttribute.streams.displayTitle)
                                .font(.callout)
                                .textCase(.uppercase)
                                .fontWeight(.medium)

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
