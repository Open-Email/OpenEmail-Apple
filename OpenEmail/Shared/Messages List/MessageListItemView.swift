import SwiftUI
import OpenEmailModel
import OpenEmailCore
import Utils
import Logging

struct MessageListItemView: View {
    private let messageThread: MessageThread
    private let scope: SidebarScope

    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?

    @Injected(\.contactsStore) private var contactsStore

    @State private var profileNames: [String: String] = [:]

    init(messageThread: MessageThread, scope: SidebarScope) {
        self.messageThread = messageThread
        self.scope = scope
    }

    private func readerName(emailAddress: String) -> String {
        profileNames[emailAddress] ?? emailAddress
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Circle()
                .fill(messageThread.isRead ? Color.clear :  Color.accentColor)
                .frame(width: 8, height: 8)
                .padding(EdgeInsets(
                    top: .Spacing.xxxSmall,
                    leading: .Spacing.xxxSmall,
                    bottom: .Spacing.xxxSmall,
                    trailing: .Spacing.xSmall,
                ))
            
            VStack(alignment: .leading) {
                HStack {
                    Text(messageThread.topic)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .font(.title3)
                    if messageThread.hasFiles {
                        Spacer()
                        Image(systemName: "paperclip")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.secondary)
                            .frame(width:11)
                    }
                }
                
                Text(messageThread.messages.last?.body ?? "")
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .font(.callout)
                
                MultiReadersView(readers: messageThread.readers)
                
            }
            .task {
                // fetch cached profile names
                do {
                    for reader in messageThread.readers {
                        let cachedReader = (try await contactsStore.contact(address: reader))
                        profileNames[reader] = cachedReader?.cachedName
                    }
                } catch {
                    Log.error("Couldn't fetch contacts: \(error)")
                }
            }
        }
    }
}

func getLabel(scope: SidebarScope) -> String? {
    var boxLabel: String? {
        switch scope {
        case .messages: "Messages"
        case .drafts: "Draft"
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
            MessageListItemView(messageThread: .makeRandom(isRead: true), scope: .messages).tag("1")
            MessageListItemView(
                messageThread: .makeRandomBroadcast(),
                scope: .messages
            )
                .tag("2")
            MessageListItemView(messageThread: .makeRandom(), scope: .messages).tag("3")
        }
        .listStyle(.plain)
        .navigationTitle("Inbox")
    }
}

