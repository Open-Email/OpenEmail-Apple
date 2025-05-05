import SwiftUI
import OpenEmailModel
import OpenEmailCore

struct ConfigurationProfileAttributesEditorView: View {
    @Binding var profile: Profile?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .Spacing.default) {
                Text("Configuration").font(.title2)
                
                getConfigurationToggleView(attribute: ProfileAttribute.publicAccess, isOn: Binding($profile)?.publicAccess)
                getConfigurationToggleView(attribute: ProfileAttribute.publicLinks, isOn: Binding($profile)?.publicLinks)
                getConfigurationToggleView(attribute: ProfileAttribute.lastSeenPublic, isOn: Binding($profile)?.lastSeenPublic)
                
                VStack(alignment: .leading) {
                    Text(ProfileAttribute.addressExpansion.displayTitle)
                    if let info = ProfileAttribute.addressExpansion.info {
                        Text(info)
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                            .truncationMode(.tail)
                    }
                    
                    TextField("Enter addresses", text: Binding($profile)?.addressExpansion ?? Binding<String>(
                        get: {""
                        },
                        set: {_ in }))
                    .textFieldStyle(.openEmail)
                }
                .padding(.top, .Spacing.default)
            }
            .toggleStyle(.switch)
            .padding(.Spacing.default)
            .frame(maxHeight: .infinity, alignment: .top)
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
            Toggle("", isOn: isOn ?? Binding<Bool>(
                get: { true
                },
                set: {_ in }))
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
