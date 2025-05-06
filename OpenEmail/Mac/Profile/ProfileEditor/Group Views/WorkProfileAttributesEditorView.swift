import SwiftUI
import OpenEmailModel
import OpenEmailCore

struct WorkProfileAttributesEditorView: View {
    @Binding var profile: Profile?
    
    var body: some View {
        ScrollView {
            Grid(horizontalSpacing: .Spacing.large, verticalSpacing: .Spacing.large) {
                GridRow {
                    VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                        OpenEmailTextFieldLabel(ProfileAttribute.work.displayTitle)
                        TextField("Enter your work", text: Binding($profile)?.work ?? Binding<String>(
                            get: {""
                            },
                            set: {_ in }))
                        .textFieldStyle(.openEmail)
                    }
                    
                    VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                        HStack {
                            OpenEmailTextFieldLabel(ProfileAttribute.organization.displayTitle)
                            if let info = ProfileAttribute.organization.info {
                                InfoButton(text: info)
                            }
                        }
                        
                        TextField("Enter your organization", text: Binding($profile)?.organization ?? Binding<String>(
                            get: {""
                            },
                            set: {_ in }))
                        .textFieldStyle(.openEmail)
                    }
                }
                
                GridRow {
                    VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                        OpenEmailTextFieldLabel(ProfileAttribute.department.displayTitle)
                        TextField("Enter your department", text: Binding($profile)?.department ?? Binding<String>(
                            get: {""
                            },
                            set: {_ in }))
                        .textFieldStyle(.openEmail)
                    }
                    
                    VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                        HStack {
                            OpenEmailTextFieldLabel(ProfileAttribute.jobTitle.displayTitle)
                            
                            if let info = ProfileAttribute.jobTitle.info {
                                InfoButton(text: info)
                            }
                        }
                        
                        TextField("Enter your job title", text: Binding($profile)?.jobTitle ?? Binding<String>(
                            get: {""
                            },
                            set: {_ in }))
                        .textFieldStyle(.openEmail)
                    }
                }
            }.padding(.Spacing.default)
                .frame(maxHeight: .infinity, alignment: .top)
            
        }
    }
}

#Preview {
    @Previewable @State var profile: Profile? = .makeFake()
    WorkProfileAttributesEditorView(profile: $profile)
}
