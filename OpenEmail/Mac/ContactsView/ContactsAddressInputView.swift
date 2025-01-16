import SwiftUI
import OpenEmailCore

struct ContactsAddressInputView: View {
    @State private var address: String = ""

    var onSubmit: (String) -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                Text("Contact Email")
                    .font(.callout)
                    .textCase(.uppercase)
                    .fontWeight(.medium)

                TextField("mail@open.email", text: $address)
                    .textFieldStyle(.openEmail)
            }

            HStack {
                Spacer()

                Button("Cancel", role: .cancel) {
                    onCancel()
                }

                Button("Add") {
                    onSubmit(address)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!EmailAddress.isValid(address))
            }
        }
        .padding()
        .frame(width: 400)
    }
}

#Preview {
    ContactsAddressInputView { _ in
    } onCancel: {
    }
}
