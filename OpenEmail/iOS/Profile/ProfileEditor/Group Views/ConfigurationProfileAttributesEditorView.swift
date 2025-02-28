import SwiftUI
import OpenEmailModel
import OpenEmailCore

struct ConfigurationProfileAttributesEditorView: View {
    @Binding var profile: Profile

    var body: some View {
        List {
            Section {
                Toggle(isOn: $profile.publicAccess) {
                    VStack(alignment: .leading) {
                        Text(ProfileAttribute.publicAccess.displayTitle).font(.headline)
                        ProfileAttributeInfoText(.publicAccess)
                    }
                }

                Toggle(isOn: $profile.publicLinks) {
                    VStack(alignment: .leading) {
                        Text(ProfileAttribute.publicLinks.displayTitle).font(.headline)
                        ProfileAttributeInfoText(.publicLinks)
                    }
                }

                Toggle(isOn: $profile.lastSeenPublic) {
                    VStack(alignment: .leading) {
                        Text(ProfileAttribute.lastSeenPublic.displayTitle).font(.headline)
                        ProfileAttributeInfoText(.lastSeenPublic)
                    }
                }

                VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                    VStack(alignment: .leading) {
                        OpenEmailTextFieldLabel(ProfileAttribute.addressExpansion.displayTitle)
                        ProfileAttributeInfoText(.addressExpansion)
                    }

                    TextField("Address expansion", text: $profile.addressExpansion)
                        .textFieldStyle(.openEmail)
                }
                .padding(.top, .Spacing.default)
            }
            .toggleStyle(.switch)
            .tint(.accentColorMobile)
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
    }
}

#Preview {
    @Previewable @State var profile: Profile = .makeFake()
    ConfigurationProfileAttributesEditorView(profile: $profile)
}
