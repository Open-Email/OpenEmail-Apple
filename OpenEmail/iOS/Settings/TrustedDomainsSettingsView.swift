import SwiftUI
import OpenEmailCore

struct TrustedDomainsSettingsView: View {
    @Environment(\.editMode) private var editMode
    @AppStorage(UserDefaultsKeys.trustedDomains) private var trustedDomains: [String] = []
    @FocusState private var isNewDomainFocused

    @State private var editedDomain: String = ""

    var body: some View {
        let isInEditingMode = editMode?.wrappedValue.isEditing == true

        List {
            if !isInEditingMode && trustedDomains.isEmpty {
                EmptyListView(icon: nil, text: "No trusted domains yet")
                    .listRowSeparator(.hidden)
            } else {
                ForEach($trustedDomains, id: \.self) { domain in
                    if isInEditingMode, domain.wrappedValue == "" {
                        TextField("", text: $editedDomain, prompt: Text("domain"))
                            .textInputAutocapitalization(.never)
                            .textContentType(.URL)
                            .keyboardType(.URL)
                            .focused($isNewDomainFocused)
                    } else {
                        Text(domain.wrappedValue)
                    }
                }
                .onDelete { indexSet in
                    trustedDomains.remove(atOffsets: indexSet)
                }

                if isInEditingMode {
                    addButton
                }
            }
        }
        .listStyle(.grouped)
        .scrollContentBackground(.hidden)
        .animation(.default, value: trustedDomains)
        .navigationTitle("Trusted Domains")
        .toolbar { EditButton() }
        .onChange(of: editMode?.wrappedValue) { old, new in
            if old?.isEditing == true && new?.isEditing == false {
                endEditingDomain()
            }
        }
    }

    private func endEditingDomain() {
        let cleanedDomain = editedDomain.trimmingCharacters(in: .whitespacesAndNewlines)
        var newDomains = trustedDomains

        if cleanedDomain.isNotEmpty {
            newDomains.removeLast()
            newDomains.append(cleanedDomain)
        }

        trustedDomains = newDomains
        editedDomain = ""
    }

    @ViewBuilder
    private var addButton: some View {
        Button {
            if isNewDomainFocused {
                endEditingDomain()
            }

            trustedDomains.append("")
            isNewDomainFocused = true
        } label: {
            Label {
                Text("Add domain")
                    .offset(x: -2)
            } icon: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.green)
            }
            .offset(x: -2)
        }
        .foregroundStyle(.primary)
    }

    private func makeBinding(for index: Int) -> Binding<String> {
        Binding {
            trustedDomains[index]
        } set: {
            trustedDomains[index] = $0
        }
    }
}

#Preview {
    NavigationStack {
        TrustedDomainsSettingsView()
    }
}
