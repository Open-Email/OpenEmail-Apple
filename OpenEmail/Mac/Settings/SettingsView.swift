import SwiftUI

enum SettingsSection: Hashable {
    case general
    case trustedDomains
    case keys
}

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(SettingsSection.general)

            TrustedDomainsSettingsView()
                .tabItem {
                    Label("Trusted Domains", systemImage: "globe")
                }
                .tag(SettingsSection.trustedDomains)

            KeysSettingsView()
                .tabItem {
                    Label("Keys", systemImage: "key.horizontal.fill")
                }
                .tag(SettingsSection.keys)
        }
        .padding()
        .frame(width: 600)
    }
}

#Preview {
    SettingsView()
        .environment(NavigationState())
}
