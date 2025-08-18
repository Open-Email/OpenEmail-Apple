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
        SyncService.shared.setupPublishers()
    }

    private var hasCompletedOnboarding: Bool {
        registeredEmailAddress != nil
    }

    var body: some Scene {
        Window("Message Viewer", id: WindowIDs.main) {
            if hasCompletedOnboarding {
                ContentView()
                    .frame( maxWidth: .infinity, maxHeight: .infinity)
                    .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                        closeAllWindowOnTerminate()
                    }
            } else {
                OnboardingView()
                    .fixedSize(horizontal: true, vertical: true)
            }
        }
        .defaultSize(width: 1000, height: 800)
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
            SidebarCommands()  
        }

        WindowGroup("Create new Message", id: WindowIDs.compose, for: ComposeAction.self) { action in
            ComposeMessageView(action: action.wrappedValue ?? .newMessage(id: UUID(), authorAddress: registeredEmailAddress!, readerAddress: nil))
        }
        .keyboardShortcut("n", modifiers: .command)

        Window("Profile Editor", id: WindowIDs.profileEditor) {
            ProfileEditorView()
        }
        .windowResizability(.contentSize)
        .handlesExternalEvents(matching: [WindowIDs.profileEditor])
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(UnifiedWindowToolbarStyle()) 
        .commands {
            CommandMenu("Profile") {
                Button("Edit Profile…") {
                    openWindow(id: WindowIDs.profileEditor)
                }
                .keyboardShortcut("P", modifiers: [.command, .option])
            }
        }
        
        Window("Contacts", id: WindowIDs.contacts) {
            ContactsListView().environment(navigationState)
        }

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
    }

    private func closeAllWindowOnTerminate() {
        dismissWindow(id: WindowIDs.compose)
        dismissWindow(id: WindowIDs.profileEditor)
        dismissWindow(id: WindowIDs.log)
    }
}
