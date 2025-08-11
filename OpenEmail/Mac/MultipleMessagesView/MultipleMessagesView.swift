import SwiftUI
import OpenEmailPersistence
import OpenEmailModel
import Logging
import OpenEmailCore

struct MultipleMessagesView: View {
    @Environment(NavigationState.self) private var navigationState

    @Injected(\.messagesStore) private var messagesStore
    @State private var showingDeleteConfirmationAlert = false
    @Injected(\.client) private var client
    
    var body: some View {
        VStack {
            Text("\(navigationState.selectedMessageIDs.count) messages selected").font(.headline)
            actionButtons()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    @ViewBuilder
    private func actionButtons() -> some View {
        VStack {
            Button {
                if navigationState.selectedScope == .trash {
                    showingDeleteConfirmationAlert = true
                } else {
                    Task {
                        await markMessagesAsDeleted(true)
                        navigationState.clearSelection()
                    }
                }
            } label: {
                Image(systemName: "trash")

                if navigationState.selectedScope == .trash {
                    Text("Permanently Delete")
                } else {
                    Text("Move to Trash")
                }
            }
            .alert("Are you sure you want to delete these messages?", isPresented: $showingDeleteConfirmationAlert) {
                Button("Cancel", role: .cancel) {}
                AsyncButton("Delete", role: .destructive) {
                    if navigationState.selectedScope == .trash {
                        await withTaskGroup { group in
                            for messageId in navigationState.selectedMessageIDs {
                                group.addTask {
                                    do {
                                        try await self.messagesStore.deleteMessage(id: messageId)
                                    } catch {
                                        Log.error("Could not delete messages: \(error)")
                                    }
                                }
                            }
                            await group.waitForAll()
                        }
                    } else {
                        guard let currentUser = LocalUser.current else {
                            return
                        }
                        var updatedMessages = [Message]()
                        await withTaskGroup { group in
                            for message in navigationState.selectedMessageIDs {
                                
                                group.addTask {
                                    do {
                                        if await navigationState.selectedScope == .messages {
                                            try? await self.client
                                                .recallAuthoredMessage(
                                                    localUser: currentUser,
                                                    messageId: message
                                                )
                                        }
                                        if var localMessage = try await messagesStore.message(id: message) {
                                            localMessage.deletedAt = Date()
                                            updatedMessages.append(localMessage)
                                        }
                                        
                                        
                                    } catch {
                                        Log.error("Could not mark message as deleted: \(error)")
                                    }
                                }
                            }
                            await group.waitForAll()
                        }
                        
                        do {
                            try await messagesStore.storeMessages(updatedMessages)
                        } catch {
                            Log.error("Could not store updated messages: \(error)")
                        }
                    }
                }
            } message: {
                Text("This action cannot be undone.")
            }

            if navigationState.selectedScope == .trash {
                Button {
                    Task {
                        await markMessagesAsDeleted(false)
                        navigationState.clearSelection()
                    }
                } label: {
                    Image(systemName: "trash.slash")
                    Text("Undelete")
                }
            }
        }
        .buttonStyle(.bordered)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    private func markMessagesAsDeleted(_ deleted: Bool) async {
        do {
            var messages = [Message]()
            for messageID in navigationState.selectedMessageIDs {
                if var message = try await messagesStore.message(id: messageID) {
                    message.deletedAt = deleted ? .now : nil
                    messages.append(message)
                }
            }

            try await messagesStore.storeMessages(messages)
        } catch {
            Log.error("Could not mark message as deleted: \(error)")
        }
    }
}

#Preview {
    MultipleMessagesView()
        .frame(width: 500, height: 600)
        .environment(NavigationState())
}
