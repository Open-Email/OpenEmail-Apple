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

    private var formattedReadersLine: String {
        let readers = messageThread.readers

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
                .fill(messageThread.isRead ? Color.clear :  Color.accentColor)
                .frame(width: 8, height: 8)
                .padding(EdgeInsets(
                    top: .Spacing.xxxSmall,
                    leading: .Spacing.xxxSmall,
                    bottom: .Spacing.xxxSmall,
                    trailing: .Spacing.xSmall,
                ))
            
            VStack(alignment: .leading, spacing: 0) {
                Text(messageThread.topic)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .font(.headline)
                
                HStack {
                    
                    Spacer()
                    if messageThread.hasFiles {
                        Image(systemName: "paperclip")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.secondary)
                            .frame(width:11)
                    }
                }.padding(.top, .Spacing.xSmall)
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

