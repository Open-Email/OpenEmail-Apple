import Foundation
import SwiftUI
import Logging
import OpenEmailCore

struct SettingsView: View {
    @State private var showLogoutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        GeneralSettingsView()
                            .navigationTitle("General")
                    } label: {
                        Label("General", image: .settings)
                    }

                    NavigationLink {
                        TrustedDomainsSettingsView()
                    } label: {
                        Label("Trusted Domains", systemImage: "globe")
                    }

                    NavigationLink {
                        KeysSettingsView()
                    } label: {
                        Label("Keys", image: .key)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showLogoutConfirmation = true
                    } label: {
                        Label("Log Out", image: .logout)
                            .foregroundStyle(.red)
                    }
                    .alert("Log Out?", isPresented: $showLogoutConfirmation) {
                        Button("Log Out", role: .destructive) {
                            LogoutUseCase().logout()
                        }
                    } message: {
                        Text("All local data will be deleted. Log in again to restore data.")
                    }
                    Button(role: .destructive) {
                        showDeleteAccountConfirmation = true
                    } label: {
                        Label("Delete Account", image: .delete)
                            .foregroundStyle(.red)
                    }
                    .alert("Delete Account?", isPresented: $showDeleteAccountConfirmation) {
                        AsyncButton("Delete Account", role: .destructive) {
                            do {
                                try await DeleteAccountUseCase().deleteAccount()
                            } catch {
                                Log.error("Could not delete account:", context: error)
                            }
                        }
                    } message: {
                        Text("All remote data on server will be permanently deleted.")
                    }
                } header: {
                    Text("Account")
                } footer: {
                    VStack {
                        Text(Bundle.main.appName).fontWeight(.semibold)
                        Text("Version ") + Text(Bundle.main.appVersionLong) + Text(" (") + Text(Bundle.main.appBuild) + Text(")")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, .Spacing.xLarge)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
