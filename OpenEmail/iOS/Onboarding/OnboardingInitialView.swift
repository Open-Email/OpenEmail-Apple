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

    var body: some View {
        NavigationStack(path: $presentedPages) {
            VStack {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.accent)
                    .frame(maxHeight: 100)
                    .padding(.top)

                Text("OpenEmail")
                    .font(.largeTitle)
                    .padding(.top)
                    .bold()
                Text("Email of the future, today.")
                    .font(.headline)
                    .padding(.top, 10)
                Text("Spam-free, phishing-free, private & secure by design.")
                    .multilineTextAlignment(.center)

                VStack {
                    TextField("", text: $emailAddress, prompt: Text("OpenEmail address"))
                        .keyboardType(.emailAddress)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .font(.title2)
                        .disabled(viewModel.isCheckingEmailAddress)

                    AsyncButton {
                        if await viewModel.registerExistingEmailAddress(emailAddress) {
                            presentedPages.append(.existingAccount)
                        }
                    } label: {
                        Label("Sign In", systemImage: "chevron.right")
                            .bold()
                            .foregroundStyle(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 15)
                            .background {
                                RoundedRectangle(cornerRadius: 5, style: .circular)
                                    .foregroundColor(.accentColor)
                            }
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                    .contentShape(RoundedRectangle(cornerRadius: 5))
                    .disabled(viewModel.isCheckingEmailAddress || !EmailAddress.isValid(emailAddress))
                }
                .padding(.top)

                Spacer()

                Text("Don't have an OpenEmail address yet?")
                Button("Get one for free instantly") {
                    presentedPages.append(.newAccount)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.accent)
            }
            .padding(20)
            .blur(radius: viewModel.isCheckingEmailAddress ? 3 : 0)
            .overlay {
                if viewModel.isCheckingEmailAddress {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.background.opacity(0.75))
                }
            }
            .alert("OpenEmail not supported on this host.", isPresented: $viewModel.showsServiceNotSupportedError) {}
            .navigationDestination(for: OnboardingPage.self) { page in
                switch page {
                case .existingAccount:
                    OnboardingExistingAccountView(emailAddress: emailAddress)
                case .newAccount:
                    OnboardingNewAccountView()
                }
            }
        }
    }
}

#Preview {
    OnboardingInitialView()
}
