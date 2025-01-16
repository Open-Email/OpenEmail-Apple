import SwiftUI
import Combine
import OpenEmailCore
import OpenEmailModel
import OpenEmailPersistence

struct ContentView: View {
    @Environment(NavigationState.self) private var navigationState
    @Environment(\.openWindow) private var openWindow
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?

    private let contactRequestsController = ContactRequestsController()
    @Injected(\.syncService) private var syncService

    @State private var hasContactRequests = false

    @State private var scope: SidebarScope = .inbox
    @State private var fetchButtonRotation = 0.0
    @State private var searchText: String = ""

    @State private var selectedMessageProfileAddress: EmailAddress?
    @State private var selectedContactListItem: ContactListItem?
    @State private var selectedProfileViewModel: ProfileViewModel?

    private let contactsOrNotificationsUpdatedPublisher = Publishers.Merge(
        NotificationCenter.default.publisher(for: .didUpdateContacts),
        NotificationCenter.default.publisher(for: .didUpdateNotifications)
    ).eraseToAnyPublisher()

    var body: some View {
        NavigationSplitView {
            let width: CGFloat = .sidebarWidth + .Spacing.default
            SidebarView()
                .navigationSplitViewColumnWidth(min: width, ideal: width, max: width)
        } content: {
            Group {
                if scope == .contacts {
                    ContactsListView(selectedContactListItem: $selectedContactListItem)
                } else {
                    MessagesListView()
                }
            }
            .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 500)
        } detail: {
            Group {
                if scope == .contacts {
                    contactsDetailView
                } else {
                    messagesDetailView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.themeViewBackground)
            .navigationSplitViewColumnWidth(min: 300, ideal: 400)
            .toolbar {
                detailsToolbarContent()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(contactsOrNotificationsUpdatedPublisher) { _ in
            Task {
                await updateContactRequests()
            }
        }
        .task {
            await updateContactRequests()
            await triggerSync()
        }
        .onChange(of: registeredEmailAddress) {
            Task {
                await triggerSync()
            }
        }
        .onChange(of: navigationState.selectedScope) {
            scope = navigationState.selectedScope
            selectedProfileViewModel = nil
            selectedContactListItem = nil
        }
        .onChange(of: selectedMessageProfileAddress) {
            if let selectedMessageProfileAddress {
                selectedProfileViewModel = ProfileViewModel(emailAddress: selectedMessageProfileAddress)
            } else {
                selectedProfileViewModel = nil
            }
        }
        .onChange(of: selectedContactListItem) {
            if let selectedContactListItem, let emailAddress = EmailAddress(selectedContactListItem.email) {
                selectedProfileViewModel = ProfileViewModel(emailAddress: emailAddress)
            } else {
                selectedProfileViewModel = nil
            }
        }
    }

    @ToolbarContentBuilder
    private func detailsToolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                guard let registeredEmailAddress else { return }
                openWindow(id: WindowIDs.compose, value: ComposeAction.newMessage(id: UUID(), authorAddress: registeredEmailAddress, readerAddress: nil))
            } label: {
                HStack {
                    Image(.compose)
                        .resizable()
                        .aspectRatio(contentMode: .fit)

                    Text("Create Message")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.accent)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }

        ToolbarItem {
            Spacer()
        }

        ToolbarItem {
            HStack(spacing: 2) {
                AsyncButton(actionOptions: [.disableButton]) {
                    await triggerSync()
                } label: {
                    SyncProgressView()
                }

                Text("Next sync in \((syncService.nextSyncDate ?? .distantFuture).formattedNextSyncDate)")
                    .fontWeight(.medium)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 5)
            .disabled(syncService.isSyncing)
        }

        ToolbarItem(placement: .confirmationAction) {
            ProfileButton()
        }
    }

    @ViewBuilder
    private var messagesDetailView: some View {
        if navigationState.selectedMessageIDs.count > 1 {
            MultipleMessagesView()
        } else {
            MessageView(
                messageID: navigationState.selectedMessageIDs.first,
                selectedProfileViewModel: selectedProfileViewModel,
                selectedMessageProfileAddress: $selectedMessageProfileAddress
            )
        }
    }

    @ViewBuilder
    private var contactsDetailView: some View {
        if let selectedProfileViewModel, let selectedContactListItem {
            ProfileView(viewModel: selectedProfileViewModel, isContactRequest: selectedContactListItem.isContactRequest)
                .frame(minWidth: 600)
        } else {
            Text("No selection")
                .bold()
                .foregroundStyle(.tertiary)
        }
    }

    private func updateContactRequests() async {
            hasContactRequests = await contactRequestsController.hasContactRequests
        }

    private func triggerSync() async {
        await syncService.synchronize()
    }
}

struct SyncProgressView: View {
    @State private var rotation: CGFloat = 0
    @Injected(\.syncService) private var syncService

    var body: some View {
        Group {
            if syncService.isSyncing {
        Image(systemName: "arrow.triangle.2.circlepath")
            .rotationEffect(.degrees(rotation))
            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: rotation)
            } else {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
        }
            .onChange(of: syncService.isSyncing) {
                rotation = syncService.isSyncing ? 360 : 0
            }
    }
}

private extension Date {
    var formattedNextSyncDate: String {
        let minutes = Int(timeIntervalSinceNow.asMinutes)
        if minutes >= 60 {
            let hours = Int(timeIntervalSinceNow.asHours)
            return "\(hours) hours"
        } else {
            return "\(minutes) min"
        }
    }
}

private struct ProfileButton: View {
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?
    @AppStorage(UserDefaultsKeys.profileName) private var profileName: String?

    @Environment(\.openWindow) private var openWindow

    @State private var isHovering = false
    @State private var isPressed = false

    var body: some View {
        Button {
            openWindow(id: WindowIDs.profileEditor)
        } label: {
            HStack(spacing: .Spacing.small) {
                ProfileImageView(emailAddress: registeredEmailAddress, size: 26)
                VStack(alignment: .leading, spacing: 0) {
                    Text(profileName ?? "No Name").bold()
                        .foregroundStyle(.primary)
                    Text(registeredEmailAddress ?? "").font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(4)
            .background {
                if isHovering {
                    RoundedRectangle(cornerRadius: .CornerRadii.small)
                        .foregroundStyle(.tertiary)
                }
            }
            .animation(.default, value: isHovering)
            .onHover {
                isHovering = $0
                if !isHovering {
                    isPressed = false
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .environment(NavigationState())
        .frame(minWidth: 800, minHeight: 600)
        .navigationTitle("")
}
