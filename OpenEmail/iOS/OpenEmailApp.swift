import SwiftUI
import Logging
import OpenEmailCore

@main
struct OpenEmailApp: App {
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?

    private let localUserUpdateService = LocalUserUpdateService()
    private let trashPurginService = TrashPurgingService()

    init() {
        Log.start()
        UserDefaults.standard.registerDefaults()
    }

    private var hasCompletedOnboarding: Bool {
        registeredEmailAddress != nil
    }

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingInitialView()
            }
        }
    }
}
