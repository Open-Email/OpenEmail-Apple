import SwiftUI
import OpenEmailCore

struct OnboardingInitialView: View {
    @Binding var emailAddress: String
    @Binding var onboardingPage: OnboardingPage

    @State private var viewModel = OnboardingInitialViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: .Spacing.large) {
            Image(.logo)
                .padding(.bottom, .Spacing.xSmall)

            VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                Text("Email of the future, today")
                    .font(.title)

                Text("Spam-free, phishing-free, private & secure by design.")
            }

            VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                Text("Email")
                    .font(.callout)
                    .textCase(.uppercase)
                    .fontWeight(.medium)

                TextField("", text: $emailAddress, prompt: Text("mail@open.email"))
                    .textFieldStyle(.openEmail)
                    .disabled(viewModel.isCheckingEmailAddress)
            }

            AsyncButton("Log In") {
                if await viewModel.registerExistingEmailAddress(emailAddress) {
                        onboardingPage = .existingAccount
                    }
                }
            .buttonStyle(OpenEmailButtonStyle(style: .primary))
            .keyboardShortcut(.defaultAction)
            .contentShape(RoundedRectangle(cornerRadius: .CornerRadii.default))
            .disabled(viewModel.isCheckingEmailAddress || !EmailAddress.isValid(emailAddress))

            VStack {
                Text("Don't have an OpenEmail address yet?")
                Button("Create one for free") {
                        onboardingPage = .newAccount
                    }
                .fontWeight(.semibold)
                .buttonStyle(.link)
                .foregroundStyle(.accent)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, .Spacing.xSmall)
        }
        .frame(maxHeight: .infinity)
        .padding(.Spacing.default)
        .padding(.bottom, .Spacing.xSmall)
        .blur(radius: viewModel.isCheckingEmailAddress ? 3 : 0)
        .overlay {
            if viewModel.isCheckingEmailAddress {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.background.opacity(0.75))
            }
        }
        .alert("OpenEmail not supported on this host.", isPresented: $viewModel.showsServiceNotSupportedError) {}
    }
}

#Preview {
    OnboardingInitialView(emailAddress: .constant(""), onboardingPage: .constant(.initial))
        .frame(width: 400)
}
