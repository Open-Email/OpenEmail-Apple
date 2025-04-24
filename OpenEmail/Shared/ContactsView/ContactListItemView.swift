import SwiftUI

struct ContactListItemView: View {
    private let item: ContactListItem

    init(item: ContactListItem) {
        self.item = item
    }

    var body: some View {
        HStack(spacing: .Spacing.small) {
            ProfileImageView(emailAddress: item.email)

            VStack(alignment: .leading, spacing: .Spacing.xxxSmall) {
                Text(item.title)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .font(.system(size: 16))
                    .fontWeight(.semibold)

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                }
            }

            if item.isContactRequest {
                Spacer()
                Text("request")
                    .textCase(.uppercase)
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                    .padding(.vertical, .Spacing.xxxSmall)
                    .padding(.horizontal, .Spacing.xxSmall)
                    .background {
                        RoundedRectangle(cornerRadius: .CornerRadii.small)
                            .fill(.themeBlue)
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .listStyle(.plain)
        .navigationTitle("Contacts")
        .frame(width: 350)
    }
}
