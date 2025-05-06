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
        HStack(alignment: .top, spacing: 0) {
            Circle()
                .fill(message.isRead ? Color.clear :  Color.accentColor)
                .frame(width: 8, height: 8)
                .padding(EdgeInsets(
                    top: .Spacing.xxxSmall,
                    leading: .Spacing.xxxSmall,
                    bottom: .Spacing.xxxSmall,
                    trailing: .Spacing.xSmall,
                    
                ))
            
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    if message.isBroadcast {
                        Group {
                            Image(.scopeBroadcasts)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 11)
                                .padding(.bottom, 3)
                            Text("Broadcast")
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .font(.headline)
                                .padding(.bottom, 3)
                        }
                    } else {
                        Text(scope == .outbox ? formattedReadersLine : profileNames[message.author] ?? message.author)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .font(.headline)
                            .padding(.bottom, 3)
                    }
                   
                    
                    Spacer()
                    
                    if let boxLabel = getLabel(scope: scope) {
                        Text(boxLabel)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                            .truncationMode(.tail)
                            .font(.subheadline)
                    }
                    
                    Text(message.formattedAuthoredOnDate)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                
                HStack {
                    Text(message.displayedSubject)
                        .lineLimit(1)
                        .font(.subheadline)
                        .truncationMode(.tail)
                        .padding(.bottom, 3)
                    
                    Spacer()
                    if message.hasFiles || !message.draftAttachmentUrls.isEmpty {
                        Image(systemName: "paperclip")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.secondary)
                            .frame(width:11)
                    }
                }
                
                Text(message.body?.cleaned ?? "")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .lineLimit(3)
                    .truncationMode(.tail)
                
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
}

func getLabel(scope: SidebarScope) -> String? {
    var boxLabel: String? {
        switch scope {
        case .inbox: "Inbox"
        case .drafts: "Draft"
        case .outbox: "Sent"
        case .broadcasts: "Broadcast"
        case .trash: "Trash"
        case .contacts: nil
        }
    }
    return boxLabel
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
