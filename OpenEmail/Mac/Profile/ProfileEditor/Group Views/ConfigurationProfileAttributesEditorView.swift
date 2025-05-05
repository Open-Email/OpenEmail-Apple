import SwiftUI
import OpenEmailModel
import OpenEmailCore

struct ConfigurationProfileAttributesEditorView: View {
    @Binding var profile: Profile?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .Spacing.default) {
                Text("Configuration").font(.title2)
                
                HStack {
                    Toggle("", isOn: Binding($profile)?.publicAccess ?? Binding<Bool>(
                        get: { true
                        },
                        set: {_ in }))
                    Text(ProfileAttribute.publicAccess.displayTitle)
                    
                    if let info = ProfileAttribute.publicAccess.info {
                        InfoButton(text: info)
                    }
                }
                HStack {
                    Toggle("", isOn: Binding($profile)?.publicLinks ?? Binding<Bool>(
                        get: { true },
                        set: {_ in }))
                    Text(ProfileAttribute.publicLinks.displayTitle)
                    
                    if let info = ProfileAttribute.publicLinks.info {
                        InfoButton(text: info)
                    }
                }
                HStack {
                    Toggle("", isOn: Binding($profile)?.lastSeenPublic ?? Binding<Bool>(
                        get: { true },
                        set: {_ in }))
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
}

#Preview {
    @Previewable @State var profile: Profile? = .makeFake()
    HStack {
        ConfigurationProfileAttributesEditorView(profile: $profile)
    }
    .frame(height: 800)
}
