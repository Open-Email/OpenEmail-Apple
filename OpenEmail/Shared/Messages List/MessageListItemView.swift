import SwiftUI
import OpenEmailModel
import OpenEmailCore
import Utils

struct MessageListItemView: View {
    private let message: Message
    private let scope: SidebarScope

    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?

    @Injected(\.contactsStore) private var contactsStore

    @State private var profileNames: [String: String] = [:]

    init(message: Message, scope: SidebarScope) {
        self.message = message
        self.scope = scope
    }

    private func readerName(emailAddress: String) -> String {
        profileNames[emailAddress] ?? emailAddress
    }

    private var formattedReadersLine: String {
        let readers = message.readers

        switch readers.count {
        case 0:
            return "–"
        case 1:
            return readerName(emailAddress: readers[0])
        case 2:
            return "\(readerName(emailAddress: readers[0])) & \(readerName(emailAddress: readers[1]))"
        default:
            return "\(readerName(emailAddress: readers[0])) and \(readers.count - 1) others"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: .Spacing.small) {
            if scope == .outbox {
                if message.readers.count > 1 {
                    ProfileImageView(emailAddress: nil, multipleUsersCount: message.readers.count)
                } else {
                    ProfileImageView(emailAddress: message.readers.first)
                }
            } else {
                ProfileImageView(emailAddress: message.author)
                    .overlay(alignment: .topLeading) {
                        if !message.isRead {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 12, height: 12)
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 0) {
                Group {
                    if scope != .outbox {
                        Text(profileNames[message.author] ?? message.author)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .font(.system(size: 16))
                            .fontWeight(.semibold)
                    } else {
                        if message.isBroadcast {
                            HStack(spacing: 2) {
                                Image(systemName: "dot.radiowaves.left.and.right")
                                Text("Broadcast".uppercased())
                                    .bold()
                            }
                        } else {
                            Text(formattedReadersLine)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .font(.system(size: 16))
                                .fontWeight(.semibold)
                        }
                    }
                }
                .padding(.bottom, .Spacing.xSmall)

                Text(message.displayedSubject)
                    .lineLimit(1)
                    .bold()
                    .truncationMode(.tail)
                    .padding(.bottom, .Spacing.xxSmall)

                Text(message.body?.cleaned ?? "")
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)

                if message.hasFiles || !message.draftAttachmentUrls.isEmpty {
                    HStack(spacing: .Spacing.xxxSmall) {
                        Image(.attachment)

                        let count: Int = {
                            message.isDraft ? message.draftAttachmentUrls.count : message.attachments.count
                        }()
                        Text("^[\(count) attached files](inflect: true)")
                    }
                    .foregroundStyle(.secondary)
                    .padding(.top, .Spacing.default)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(message.formattedAuthoredOnDate)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            #if os(iOS)
                .font(.subheadline)
            #endif
        }
        .task {
            // fetch cached profile names
            if scope == .outbox {
                // readers
                message.readers.forEach { reader in
                    Task {
                        profileNames[reader] = (try? await contactsStore.contact(address: reader))?.cachedName
                    }
                }
            } else {
                // author
                profileNames[message.author] = (try? await contactsStore.contact(address: message.author))?.cachedName
            }
        }
    }
}

#Preview {
    @Previewable @State var selection: Set<String> = []
    NavigationStack {
        List(selection: $selection) {
            MessageListItemView(message: .makeRandom(isRead: true), scope: .inbox).tag("1")
            MessageListItemView(message: .makeRandom(), scope: .inbox).tag("2")
            MessageListItemView(message: .makeRandom(), scope: .inbox).tag("3")
        }
        .listStyle(.plain)
        .navigationTitle("Inbox")
    }
}

#Preview("outbox") {
    @Previewable @State var selection: Set<String> = []
    NavigationStack {
        List {
            MessageListItemView(message: .makeRandom(isRead: true), scope: .outbox).tag("1")
            MessageListItemView(message: .makeRandom(isRead: true), scope: .outbox).tag("2")
            MessageListItemView(message: .makeRandom(isRead: true), scope: .outbox).tag("3")
        }
        .listStyle(.plain)
        .navigationTitle("Outbox")
    }
}
