import SwiftUI
import OpenEmailModel
import OpenEmailCore

struct ConfigurationProfileAttributesEditorView: View {
    @Binding var profile: Profile?
    
    var body: some View {
        ScrollView {
            Form {
                getConfigurationToggleView(attribute: ProfileAttribute.publicAccess, isOn: Binding($profile)?.publicAccess)
                getConfigurationToggleView(attribute: ProfileAttribute.publicLinks, isOn: Binding($profile)?.publicLinks)
                getConfigurationToggleView(attribute: ProfileAttribute.lastSeenPublic, isOn: Binding($profile)?.lastSeenPublic)
                TextField(
                    "Address expansion:",
                    text: Binding($profile)?.addressExpansion ?? getEmptyBindingForField(
                        ""
                    ),
                    prompt: Text(ProfileAttribute.addressExpansion.info ?? "")
                )
                .textFieldStyle(.openEmail)
            }
            .toggleStyle(.switch)
            .formStyle(.grouped)
                .background(.regularMaterial)
                .navigationTitle("Configuration")
        }
    }
    
    private func getConfigurationToggleView(attribute: ProfileAttribute, isOn: Binding<Bool>?) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading) {
                Text(attribute.displayTitle)
                if let info = attribute.info {
                    Text(info)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .truncationMode(.tail)
                }
            }
            Spacer()
            Toggle("", isOn: isOn ?? getEmptyBindingForField(true))
        }
    }
}



#Preview {
    @Previewable @State var profile: Profile? = .makeFake()
    HStack {
        ConfigurationProfileAttributesEditorView(profile: $profile)
    }
    .frame(height: 800)
}
