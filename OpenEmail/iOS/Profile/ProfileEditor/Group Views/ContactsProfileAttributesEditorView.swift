import SwiftUI
import OpenEmailModel
import OpenEmailCore

struct ContactsProfileAttributesEditorView: View {
    @Binding var profile: Profile

    var body: some View {
        List {
            Section {
                TextField("Website", text: $profile.website)
                TextField("Location", text: $profile.location)
                TextField("Mailing address", text: $profile.mailingAddress)
                TextField("Phone number", text: $profile.phone)
                TextField("Streams", text: $profile.streams)
            }
            .textFieldStyle(.openEmail)
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
    }
}

#Preview {
    @Previewable @State var profile: Profile = .makeFake()
    ContactsProfileAttributesEditorView(profile: $profile)
}
