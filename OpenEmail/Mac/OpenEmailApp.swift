import SwiftUI
import Logging
import OpenEmailCore

@main
struct OpenEmailApp: App {
    @State private var navigationState = NavigationState()

    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

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
        Window("Message Viewer", id: WindowIDs.main) {
            if hasCompletedOnboarding {
                ContentView()
                    .frame(minWidth: 1100, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity)
                    .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                        closeAllWindowOnTerminate()
                    }
            } else {
                OnboardingView()
                    .fixedSize(horizontal: true, vertical: true)
            }
        }
        .environment(navigationState)
        .windowToolbarStyle(.unified(showsTitle: false))
        .windowResizability(hasCompletedOnboarding ? .automatic : .contentSize)
        .commands {
            CommandGroup(replacing: .singleWindowList) {
                Button("Message Viewer") {
                    openWindow(id: WindowIDs.main)
                }
                .keyboardShortcut(.init("0", modifiers: .command))
            }
        }

        WindowGroup("Create a new message", id: WindowIDs.compose, for: ComposeAction.self) { action in
            ComposeMessageView(viewModel: ComposeMessageViewModel(action: action.wrappedValue ?? .newMessage(id: UUID(), authorAddress: registeredEmailAddress!, readerAddress: nil)))
        }
        .keyboardShortcut("n", modifiers: .command)

        Window("ProfileEditor", id: WindowIDs.profileEditor) {
            ProfileEditorView()
                .frame(minWidth: 400, maxWidth: 1000)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
                .environment(navigationState)
        }
        .windowResizability(.contentSize)

        Window("Log", id: WindowIDs.log) {
            LogView()
                .frame(minWidth: 400, minHeight: 300)
        }
        .windowResizability(.contentSize)

        #if DEBUG
        Window("Debug", id: WindowIDs.debug) {
            DebugView()
                .environment(navigationState)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.topLeading)
        #endif
    }

    private func closeAllWindowOnTerminate() {
        dismissWindow(id: WindowIDs.compose)
        dismissWindow(id: WindowIDs.profileEditor)
        dismissWindow(id: WindowIDs.log)
    }
}
