import SwiftUI
import OpenEmailCore

struct OnboardingInitialView: View {
    private enum OnboardingPage: Int {
        case newAccount
        case existingAccount
    }

    @State private var viewModel = OnboardingInitialViewModel()
    @State private var presentedPages: [OnboardingPage] = []
    @State private var emailAddress: String = ""
    @FocusState private var keyboardShown: Bool

    var body: some View {
        NavigationStack(path: $presentedPages) {
            ScrollView {
                VStack(spacing: 0) {
                    OnboardingHeaderView()

                    VStack(alignment: .leading, spacing: .Spacing.large) {
                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            Text("Let’s make the future today")
                                .font(.title2)

                            Text("Spam-free, phishing-free, private & secure by design")
                                .foregroundStyle(.secondary)
                        }

                        VStack(spacing: .Spacing.xxxxLarge) {
                            TextField("Email Address", text: $emailAddress, prompt: Text("email address"))
                                .keyboardType(.emailAddress)
                                .textFieldStyle(.openEmail)
                                .textContentType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .disabled(viewModel.isCheckingEmailAddress)
                                .focused($keyboardShown)

                            AsyncButton(actionOptions: [.showProgressView]) {
                                if await viewModel.registerExistingEmailAddress(emailAddress) {
                                    presentedPages.append(.existingAccount)
                                }
                            } label: {
                                Text("Log In")
                            }
                            .buttonStyle(OpenEmailButtonStyle(style: .primary))
                            .keyboardShortcut(.defaultAction)
                            .disabled(viewModel.isCheckingEmailAddress || !EmailAddress.isValid(emailAddress))
                        }

                        Spacer()

                        VStack(spacing: .Spacing.default) {
                            Text("Don’t have an OpenEmail address yet?")
                                .foregroundStyle(.secondary)
                                .font(.callout)

                            Button("Create one for free") {
                                presentedPages.append(.newAccount)
                            }
                            .buttonStyle(OpenEmailButtonStyle(style: .secondary))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, .Spacing.xLarge)
                    }
                    .padding([.leading, .trailing, .bottom], .Spacing.default)
                    .contentShape(Rectangle())
                    .onTapGesture(count: keyboardShown ? 1 : .max, perform: { // if keyboard shown use single tap to close it, otherwise set .max to not interfere with other stuff
                        keyboardShown = false
                    })
                }
                .alert("OpenEmail is not supported on this host.", isPresented: $viewModel.showsServiceNotSupportedError) {}
                .navigationDestination(for: OnboardingPage.self) { page in
                    switch page {
                    case .existingAccount:
                        OnboardingExistingAccountView(emailAddress: emailAddress)
                    case .newAccount:
                        OnboardingNewAccountView()
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .ignoresSafeArea(edges: .top)
            .navigationTitle("")
        }
    }
}

#Preview {
    OnboardingInitialView()
}
