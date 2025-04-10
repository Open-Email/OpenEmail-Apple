import Foundation
import SwiftUI

struct SettingsView: View {
    @State private var showRemoveAccountConfirmation = false
    
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
                    .listRowSeparator(.hidden, edges: .top)

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
                .foregroundStyle(Color.themePrimary)

                Section {
                    Button(role: .destructive) {
                        showRemoveAccountConfirmation = true
                    } label: {
                        Label("Log Out", image: .logout)
                            .foregroundStyle(.red)
                    }
                    .listRowSeparator(.hidden, edges: .top)
                    .alert("Log Out?", isPresented: $showRemoveAccountConfirmation) {
                        Button("Log Out", role: .destructive) {
                            RemoveAccountUseCase().removeAccount()
                        }
                    } message: {
                        Text("All local data will be deleted. Log in again to restore data.")
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
                .listRowSeparator(.hidden, edges: .bottom)
            }
            .listStyle(.plain)
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
