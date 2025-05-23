import SwiftUI
import Logging
import OpenEmailCore

struct ContactListItemView: View {
    private let item: ContactListItem

    init(item: ContactListItem) {
        self.item = item
    }

    var body: some View {
        HStack {
            ProfileImageView(emailAddress: item.email, size: .medium)

            VStack(alignment: .leading, spacing: .zero) {
                Text(item.title)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .font(.headline)
                    .padding(.bottom, 3)

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                        .truncationMode(.tail)
                        .font(.subheadline)
                }
            }

            if item.isContactRequest {
                Spacer()
                Text("request")
                    .textCase(.uppercase)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(.vertical, .Spacing.xxxSmall)
                    .padding(.horizontal, .Spacing.xxSmall)
                    .background {
                        RoundedRectangle(cornerRadius: .CornerRadii.small)
                            .fill(.accent)
                    }
            }
        }
        .swipeActions(edge: .trailing) {
            AsyncButton("Delete") {
                if let address = EmailAddress(item.email) {
                    do {
                        try await DeleteContactUseCase()
                            .deleteContact(emailAddress: address)
                    } catch {
                        Log.error("Could not delete contact \(address.address): \(error)")
                    }
                }
            }
            .tint(.red)
        }
        .padding(.vertical, .Spacing.xSmall)
        .padding(.horizontal, .Spacing.xxSmall)
    }
}

#Preview {
    @Previewable @State var selection: Set<String> = []
    NavigationStack {
        List {
            ContactListItemView(item: .init(title: "Mickey Mouse", subtitle: "mickey@mouse.com", email: "mickey@mouse.com", isContactRequest: true))

            ContactListItemView(item: .init(title: "Mickey Mouse", subtitle: "mickey@mouse.com", email: "mickey@mouse.com", isContactRequest: false))

            ContactListItemView(item: .init(title: "Mickey Mouse", subtitle: "mickey@mouse.com", email: "mickey@mouse.com", isContactRequest: false))
        }
        .listStyle(.automatic)
        .navigationTitle("Contacts")
        .frame(width: 350)
    }
}
