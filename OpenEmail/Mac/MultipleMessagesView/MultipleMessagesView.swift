import SwiftUI
import OpenEmailPersistence
import OpenEmailModel
import Logging

struct MultipleMessagesView: View {
    @Environment(NavigationState.self) private var navigationState

    @Injected(\.messagesStore) private var messagesStore
    @State private var showingDeleteConfirmationAlert = false
    
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
                        navigationState.selectedMessageIDs = []
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
                Button("Delete", role: .destructive) {
                    Task {
                        do {
                            for messageID in navigationState.selectedMessageIDs {
                                if let message = try await messagesStore.message(id: messageID) {
                                    try await message.permentlyDelete(messageStore: messagesStore)
                                }
                            }
                            navigationState.selectedMessageIDs.removeAll()
                        } catch {
                            Log.error("Could not delete message: \(error)")
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
                        navigationState.selectedMessageIDs.removeAll()
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
