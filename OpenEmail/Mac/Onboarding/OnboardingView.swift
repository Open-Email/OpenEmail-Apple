import SwiftUI

struct OnboardingView: View {
    @State private var currentPage: OnboardingPage = .initial
    @State private var emailAddress: String = ""

    var body: some View {
        Group {
            switch currentPage {
            case .initial:
                OnboardingInitialView(emailAddress: $emailAddress, onboardingPage: $currentPage)
            case .existingAccount:
                OnboardingExistingAccountView(emailAddress: emailAddress.lowercased(), onboardingPage: $currentPage)
            case .newAccount:
                OnboardingNewAccountView(onboardingPage: $currentPage)
            }
        }
    }
}

enum OnboardingPage {
    case initial
    case newAccount
    case existingAccount
}

#Preview {
    OnboardingView()
}
