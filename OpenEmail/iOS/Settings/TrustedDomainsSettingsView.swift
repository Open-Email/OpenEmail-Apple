import SwiftUI
import OpenEmailCore

struct TrustedDomainsSettingsView: View {
    @Environment(\.editMode) private var editMode
    @AppStorage(UserDefaultsKeys.trustedDomains) private var trustedDomains: [String] = []
    @FocusState private var isNewDomainFocused

    @State private var editedDomain: String = ""

    var body: some View {
        let isInEditingMode = editMode?.wrappedValue.isEditing == true

        Group {
            if !isInEditingMode && trustedDomains.isEmpty {
                emptyView
            } else {
                List {
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
                .listStyle(.insetGrouped)
                .animation(.default, value: trustedDomains)
            }
        }
        .navigationTitle("Trusted Domains")
        .navigationBarTitleDisplayMode(.inline)
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
        newDomains.remove(at: trustedDomains.endIndex - 1)

        if !cleanedDomain.isEmpty {
            newDomains.append(cleanedDomain)
        }

        trustedDomains = newDomains
        editedDomain = ""
    }

    @ViewBuilder
    private var emptyView: some View {
        Text("No trusted domains yet")
            .foregroundStyle(.secondary)
            .bold()
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
