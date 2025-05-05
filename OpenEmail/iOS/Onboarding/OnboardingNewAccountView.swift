import SwiftUI
import OpenEmailCore

struct OnboardingNewAccountView: View {
    @Bindable private var viewModel = OnboardingNewAccountViewModel()
    @FocusState private var keyboardShown: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                OnboardingHeaderView()

                VStack(alignment: .leading, spacing: .Spacing.large) {
                    VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                        Text("Up & Running in Seconds")
                            .font(.title2)
                        Text("Get a free email address on one of our domains")
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: .Spacing.large) {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: .Spacing.default) {
                                TextField("user name", text: $viewModel.localPart, prompt: Text("User name"))
                                    .textFieldStyle(.openEmail)
                                    .textContentType(.username)
                                    .textInputAutocapitalization(.never)
                                    .labelsHidden()
                                    .focused($keyboardShown)

                                ZStack {
                                    Capsule()
                                        .fill(.themeViewBackground)
                                    Picker(selection: $viewModel.selectedDomainIndex) {
                                        ForEach(0..<viewModel.availableDomains.count, id: \.self) { index in
                                            Text(viewModel.availableDomains[index])
                                        }
                                    } label: {
                                    }
                                }
                                .frame(height: .Spacing.xxxLarge)
                            }

                            nameAvailabilityMessage()
                        }

                        VStack(alignment: .leading, spacing: 0) {
                            TextField("Full name", text: $viewModel.fullName)
                                .textFieldStyle(.openEmail)
                                .textContentType(.name)
                                .focused($keyboardShown)

                            Text("*You can complete it later")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, .Spacing.default)

                            fullNameValidationMessage()
                        }
                    }

                    AsyncButton {
                        await viewModel.register()
                    } label: {
                        Text("Sign Up")
                            .padding(.horizontal)
                    }
                    .buttonStyle(OpenEmailButtonStyle(style: .primary))
                    .keyboardShortcut(.defaultAction)
                    .disabled(!viewModel.isValidEmail)
                    .padding(.vertical, .Spacing.xLarge)

                    VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                        Text("By continuing you agree to the Terms of Service").bold()
                        Text("Users are prohibited from engaging in abusive behavior or any illegal activities while using our service, because while we're all for freedom, we draw the line at breaking the law or being a jerk.")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .padding([.leading, .trailing, .bottom], .Spacing.default)
                .contentShape(Rectangle())
                .onTapGesture(count: keyboardShown ? 1 : .max, perform: { // if keyboard shown use single tap to close it, otherwise set .max to not interfere with other stuff
                    keyboardShown = false
                })
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .scrollBounceBehavior(.basedOnSize)
        .ignoresSafeArea(edges: .top)
        .blur(radius: viewModel.showProgressIndicator ? 3 : 0)
        .overlay {
            if viewModel.showProgressIndicator {
                VStack(spacing: .Spacing.default) {
                    ProgressView()
                    Text(viewModel.registrationStatus.statusText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background.opacity(0.75))
            }
        }
        .alert($viewModel.alertConfiguration)
        .animation(.default, value: viewModel.emailAvailabilityMessage)
    }

    @ViewBuilder
    private func nameAvailabilityMessage() -> some View {
        let emailAvailabilityMessage = viewModel.emailAvailabilityMessage

        if !emailAvailabilityMessage.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: emailAvailabilityMessage.imageName)
                Text(emailAvailabilityMessage.text)
            }
            .foregroundStyle(emailAvailabilityMessage.color)
            .font(.caption)
            .padding(.leading, .Spacing.default)
            .padding(.vertical, .Spacing.xxxSmall)
        }
    }

    @ViewBuilder
    private func fullNameValidationMessage() -> some View {
        if !viewModel.isValidName {
            HStack(spacing: .Spacing.xxxSmall) {
                Image(systemName: "x.circle.fill")
                Text("Name must be at least 1 character long")
            }
            .foregroundStyle(.red)
            .font(.caption)
            .padding(.leading, .Spacing.default)
            .padding(.vertical, .Spacing.xxxSmall)
        }
    }
}

#Preview {
    Group {
        OnboardingNewAccountView()
    }
}
