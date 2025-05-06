import SwiftUI
import OpenEmailModel
import OpenEmailCore

struct ContactsProfileAttributesEditorView: View {
    @Binding var profile: Profile?
    
    var body: some View {
        ScrollView {
            Grid(horizontalSpacing: .Spacing.large, verticalSpacing: .Spacing.large) {
                GridRow {
                    VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                        OpenEmailTextFieldLabel(ProfileAttribute.website.displayTitle)
                        TextField("Enter your website", text: Binding($profile)?.website ?? Binding<String>(
                            get: {""
                            },
                            set: {_ in }))
                        .textFieldStyle(.openEmail)
                    }
                    
                    VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                        OpenEmailTextFieldLabel(ProfileAttribute.location.displayTitle)
                        TextField("Enter your location", text: Binding($profile)?.location ?? Binding<String>(
                            get: {""
                            },
                            set: {_ in }))
                        .textFieldStyle(.openEmail)
                    }
                }
                
                GridRow {
                    VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                        OpenEmailTextFieldLabel(ProfileAttribute.mailingAddress.displayTitle)
                        TextField("Enter your mailing address", text: Binding($profile)?.mailingAddress ?? Binding<String>(
                            get: {""
                            },
                            set: {_ in }))
                        .textFieldStyle(.openEmail)
                    }
                    
                    VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                        OpenEmailTextFieldLabel(ProfileAttribute.phone.displayTitle)
                        TextField("Enter your phone number", text: Binding($profile)?.phone ?? Binding<String>(
                            get: {""
                            },
                            set: {_ in }))
                        .textFieldStyle(.openEmail)
                    }
                }
                
                GridRow {
                    HStack {
                        OpenEmailTextFieldLabel("Streams:")
                        TextField("Enter topics", text: Binding($profile)?.streams ?? Binding<String>(
                            get: {""
                            },
                            set: {_ in }))
                        .textFieldStyle(.openEmail)
                    }
                    .gridCellColumns(2)
                }
            }.padding(.Spacing.default)
                .frame(maxHeight: .infinity, alignment: .top)
            
        }
    }
}

#Preview {
    @Previewable @State var profile: Profile? = .makeFake()
    HStack {
        ContactsProfileAttributesEditorView(profile: $profile)
    }
    .frame(height: 800)
}
