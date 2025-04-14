import SwiftUI
import Logging
import OpenEmailPersistence
import OpenEmailCore

struct GeneralSettingsView: View {
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) var registeredEmailAddress: String?
    @AppStorage(UserDefaultsKeys.notificationFetchingInterval) var notificationFetchingInterval: Int = -1
    @AppStorage(UserDefaultsKeys.automaticTrashDeletionDays) var automaticTrashDeletionDays: Int = -1
    @AppStorage(UserDefaultsKeys.attachmentsDownloadThresholdInMegaByte) var attachmentsDownloadThresholdInMegaByte: Int = 10

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dismissWindow) private var dismissWindow

    #if canImport(AppKit)
    @Environment(NavigationState.self) var navigationState
    @State private var showLogoutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    #endif

    private let availableNotificationFetchingIntervals = [-1, 1, 5, 15, 30, 60]
    private let availableAutomaticTrashDeletionDays = [-1, 1, 7, 14, 30]

    var body: some View {
        Form {
            Section("Sync") {
                Picker("Check notifications every", selection: $notificationFetchingInterval) {
                    ForEach(0..<availableNotificationFetchingIntervals.count, id: \.self) { index in
                        let interval = availableNotificationFetchingIntervals[index]
                        Text(titleForNotificationFetchingInterval(interval))
                            .tag(interval)
                    }
                }
            }

            Section("Messages") {
                Picker("Empty trash after", selection: $automaticTrashDeletionDays) {
                    ForEach(0..<availableAutomaticTrashDeletionDays.count, id: \.self) { index in
                        let interval = availableAutomaticTrashDeletionDays[index]
                        Text(titleForautomaticTrashDeletionDays(interval))
                            .tag(interval)
                    }
                }

                let attachmentSizes = [1, 5, 10, 25, 50, 100]
                Picker("Automatically download attachments smaller than", selection: $attachmentsDownloadThresholdInMegaByte) {
                    ForEach(attachmentSizes, id: \.self) {
                        Text($0.formattedAsMegaBytes)
                    }
                }
            }
#if canImport(AppKit)
            if registeredEmailAddress != nil {
                Section("Account") {
                    HStack {
                        Button("Log Out") {
                            showLogoutConfirmation = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .alert("Log Out?", isPresented: $showLogoutConfirmation) {
                            AsyncButton("Log Out", role: .destructive) {
                                await logout()
                            }
                        } message: {
                            Text("All local data will be deleted. Log in again to restore data.")
                        }
                        
                        Button("Delete Account") {
                            showDeleteAccountConfirmation = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .alert("Delete Account?", isPresented: $showDeleteAccountConfirmation) {
                            AsyncButton("Delete Account", role: .destructive) {
                                await deleteAccount()
                            }
                        } message: {
                            Text("All remote data on server will be permanently deleted.")
                        }
                    }
                    
                }
                
            }
#endif
        }
        .formStyle(.grouped)
        .scrollBounceBehavior(.basedOnSize)
    }

#if canImport(AppKit)
    private func logout() async {
        // close all compose and contact windows
        await MainActor.run {
            dismiss()
            dismissWindow(id: WindowIDs.compose)
            dismissWindow(id: WindowIDs.profileEditor)
        }

        navigationState.selectedMessageIDs.removeAll()
        RemoveAccountUseCase().removeAccount()
    }
    private func deleteAccount() async {
        do {
            try await DeleteAccountUseCase().deleteAccount()
            await logout()
        } catch {
            Log.error("Could not delete account:", context: error)
        }
        
    }
#endif

    private func titleForNotificationFetchingInterval(_ interval: Int) -> String {
        switch interval {
        case -1: return "manual"
        case 1: return "\(interval) minute"
        default: return "\(interval) minutes"
        }
    }

    private func titleForautomaticTrashDeletionDays(_ interval: Int) -> String {
        switch interval {
        case -1: return "never"
        case 1: return "\(interval) day"
        default: return "\(interval) days"
        }
    }
}

#Preview {
    GeneralSettingsView()
    #if canImport(AppKit)
        .environment(NavigationState())
    #endif
}
