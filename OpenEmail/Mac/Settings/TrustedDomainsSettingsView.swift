import SwiftUI
import OpenEmailCore

struct TrustedDomainsSettingsView: View {
    @AppStorage(UserDefaultsKeys.trustedDomains) private var trustedDomains: [String] = []
    @State private var selectedDomainIndex: Int?
    @FocusState private var focusedField: Int?

    var body: some View {
        GroupBox {
            VStack(spacing: 0) {
                List(selection: $selectedDomainIndex) {
                    ForEach(0..<trustedDomains.count, id: \.self) { index in
                        TextField("", text: makeBinding(for: index))
                            .labelsHidden()
                            .tag(index)
                            .focused($focusedField, equals: index)
                    }
                }
                .listStyle(.plain)
                .frame(minHeight: 100)
                .padding([.leading, .top, .trailing], -4)

                toolbar
            }
        } label: {
            Text("Contacts from trusted domains will automatically be added.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(minHeight: 320)
        .fixedSize()
    }

    private func makeBinding(for index: Int) -> Binding<String> {
        Binding {
            trustedDomains[index]
        } set: {
            trustedDomains[index] = $0
        }
    }

    @ViewBuilder
    private var toolbar: some View {
        Rectangle()
            .fill(.separator)
            .frame(height: 1)
            .padding(.horizontal, -4)

        HStack(spacing: 0) {
            ListToolbarButton(systemImageName: "plus") {
                trustedDomains.append("new domain")
                focusedField = nil
                selectedDomainIndex = nil

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    selectedDomainIndex = trustedDomains.endIndex.advanced(by: -1)
                    focusedField = selectedDomainIndex
                }
            }

            Divider()
                .padding(.vertical, 4)

            ListToolbarButton(systemImageName: "minus") {
                guard let selectedDomainIndex else { return }

                focusedField = nil
                self.selectedDomainIndex = nil
                trustedDomains.remove(at: selectedDomainIndex)
            }
            .disabled(selectedDomainIndex == nil)

            Spacer()
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding([.horizontal, .bottom], -4)
    }
}

private struct ListToolbarButton: View {
    @Environment(\.isEnabled) var isEnabled

    let systemImageName: String
    let action: () -> Void

    init(systemImageName: String, action: @escaping () -> Void) {
        self.systemImageName = systemImageName
        self.action = action
    }

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: systemImageName)
                .fontWeight(.semibold)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.borderless)
        .buttonBorderShape(.roundedRectangle(radius: 0))
        .labelStyle(.iconOnly)
        .foregroundStyle(isEnabled ? .secondary : .tertiary)
        .controlSize(.small)
    }
}

#Preview {
    TrustedDomainsSettingsView()
}
