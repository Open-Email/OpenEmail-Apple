import SwiftUI
import OpenEmailModel
import OpenEmailCore

struct InterestsProfileAttributesEditorView: View {
    @Binding var profile: Profile?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .Spacing.default) {
                Text("Interests").font(.title2)
                
                Grid(horizontalSpacing: .Spacing.large, verticalSpacing: .Spacing.large) {
                    GridRow {
                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            OpenEmailTextFieldLabel(ProfileAttribute.interests.displayTitle)
                            TextField("Enter your interests", text: Binding($profile)?.interests ?? Binding<String>(
                                get: {""
                                },
                                set: {_ in }))
                            .textFieldStyle(.openEmail)
                        }
                        .gridCellColumns(2)
                    }
                    
                    GridRow {
                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            OpenEmailTextFieldLabel(ProfileAttribute.books.displayTitle)
                            TextField("Enter your favorite books", text: Binding($profile)?.books ?? Binding<String>(
                                get: {""
                                },
                                set: {_ in }))
                            .textFieldStyle(.openEmail)
                        }
                        
                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            OpenEmailTextFieldLabel(ProfileAttribute.movies.displayTitle)
                            TextField("Enter your favorite movies", text: Binding($profile)?.movies ?? Binding<String>(
                                get: {""
                                },
                                set: {_ in }))
                            .textFieldStyle(.openEmail)
                        }
                    }
                    
                    GridRow {
                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            OpenEmailTextFieldLabel(ProfileAttribute.music.displayTitle)
                            TextField("Enter your favorite music", text: Binding($profile)?.music ?? Binding<String>(
                                get: {""
                                },
                                set: {_ in }))
                            .textFieldStyle(.openEmail)
                        }
                        
                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            OpenEmailTextFieldLabel(ProfileAttribute.sports.displayTitle)
                            TextField("Enter your favorite kinds of sports", text: Binding($profile)?.sports ?? Binding<String>(
                                get: {""
                                },
                                set: {_ in }))
                            .textFieldStyle(.openEmail)
                        }
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
    @Previewable @State var profile: Profile? = .makeFake()
    HStack {
        InterestsProfileAttributesEditorView(profile: $profile)
    }
    .frame(height: 800)
}
