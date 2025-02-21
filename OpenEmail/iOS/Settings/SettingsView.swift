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
                        Label("General", systemImage: "gear")
                    }

                    NavigationLink {
                        TrustedDomainsSettingsView()
                    } label: {
                        Label("Trusted Domains", systemImage: "globe")
                    }

                    NavigationLink {
                        KeysSettingsView()
                    } label: {
                        Label("Keys", systemImage: "key.horizontal.fill")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showRemoveAccountConfirmation = true
                    } label: {
                        Label("Log Out", image: .logout)
                            .foregroundStyle(.red)
                    }
                    .alert("Remove Account?", isPresented: $showRemoveAccountConfirmation) {
                        Button("Remove Account", role: .destructive) {
                            RemoveAccountUseCase().removeAccount()
                        }
                    } message: {
                        Text("All local data will be deleted. Log in again to restore data.")
                    }
                }
            }
            .listStyle(.grouped)
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
