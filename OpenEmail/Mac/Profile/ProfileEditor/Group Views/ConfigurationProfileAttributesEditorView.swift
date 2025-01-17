import SwiftUI
import OpenEmailModel
import OpenEmailCore

struct ConfigurationProfileAttributesEditorView: View {
    @Binding var profile: Profile

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .Spacing.default) {
                Text("Configuration").font(.title2)

                HStack {
                    Toggle("", isOn: $profile.publicAccess)
                    Text(ProfileAttribute.publicAccess.displayTitle)

                    if let info = ProfileAttribute.publicAccess.info {
                        InfoButton(text: info)
                    }
                }
                HStack {
                    Toggle("", isOn: $profile.publicLinks)
                    Text(ProfileAttribute.publicLinks.displayTitle)

                    if let info = ProfileAttribute.publicLinks.info {
                        InfoButton(text: info)
                    }
                }
                HStack {
                    Toggle("", isOn: $profile.lastSeenPublic)
                    Text(ProfileAttribute.lastSeenPublic.displayTitle)

                    if let info = ProfileAttribute.lastSeenPublic.info {
                        InfoButton(text: info)
                    }
                }

                VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                    HStack {
                        OpenEmailTextFieldLabel(ProfileAttribute.addressExpansion.displayTitle)
                        if let info = ProfileAttribute.addressExpansion.info {
                            InfoButton(text: info)
                        }
                    }

                    TextField("Enter address expansion", text: $profile.addressExpansion)
                        .textFieldStyle(.openEmail)
                }
                .padding(.top, .Spacing.default)
            }
            .toggleStyle(.switch)
            .padding(.Spacing.default)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .background(.themeViewBackground)
    }
}

#Preview {
    @Previewable @State var profile: Profile = .makeFake()
    HStack {
        ConfigurationProfileAttributesEditorView(profile: $profile)
    }
    .frame(height: 800)
}
