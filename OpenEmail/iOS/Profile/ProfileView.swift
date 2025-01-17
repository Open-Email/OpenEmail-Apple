import SwiftUI
import OpenEmailCore
import Logging

struct ProfileView: View {
    @State private var viewModel: ProfileViewModel
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) var registeredEmailAddress: String?

    private let showActionButtons: Bool
    private let isContactRequest: Bool
    @State private var showRemoveContactConfirmationAlert = false

    init(
        emailAddress: EmailAddress,
        showActionButtons: Bool = true,
        isContactRequest: Bool = false,
        onProfileLoaded: ((Profile?, Error?) -> Void)? = nil
    ) {
        self.showActionButtons = showActionButtons
        self.isContactRequest = isContactRequest
        viewModel = ProfileViewModel(emailAddress: emailAddress, onProfileLoaded: onProfileLoaded)
    }

    var body: some View {
        if viewModel.isLoadingProfile {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
        } else {
            if !viewModel.isLoadingProfile && viewModel.profile != nil {
                VStack(spacing: 0) {
                    header

                    let canEditReceiveBroadcasts = !viewModel.isSelf && viewModel.isInContacts
                    ProfileAttributesView(
                        profile: $viewModel.profile,
                        receiveBroadcasts: canEditReceiveBroadcasts ? $viewModel.receiveBroadcasts : nil,
                        isEditable: false,
                        hidesEmptyFields: true,
                        showsProfileImage: false,
                        footerSection: actionButtons
                    )
                }
            } else {
                errorView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            }
        }
    }

    @ViewBuilder
    private func actionButtons() -> some View {
        if !viewModel.isSelf, showActionButtons {
            Button {
                viewModel.refreshProfile()
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Refresh profile")
                }
            }

            if viewModel.isInContacts {
                AsyncButton() {
                    await viewModel.fetchMessages()
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.to.line")
                        Text("Fetch messages from this user")
                    }
                }

                Button {
                    guard let registeredEmailAddress else { return }
                    // TODO: compose
                    //                openWindow(id: WindowIDs.compose, value: ComposeAction.newMessage(id: UUID(), authorAddress: registeredEmailAddress, readerAddress: viewModel.emailAddress.address))
                } label: {
                    HStack {
                        Image(systemName: "square.and.pencil")
                        Text("Send message")
                    }
                }

                Button(role: .destructive) {
                    showRemoveContactConfirmationAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Remove from contacts")
                    }
                }
                .alert("Are you sure you want to remove this contact?", isPresented: $showRemoveContactConfirmationAlert) {
                    Button("Cancel", role: .cancel) {}
                    AsyncButton("Remove", role: .destructive) {
                        await removeUser()
                    }
                } message: {
                    Text("This action cannot be undone.")
                }
            } else {
                AsyncButton(actionOptions: [.disableButton]) {
                    await addToContacts()
                } label: {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.plus")
                        Text("Add to contacts")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var errorView: some View {
        VStack {
            HStack(spacing: 4) {
                WarningIcon()
                Text(viewModel.errorText)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Retry") {
                    viewModel.refreshProfile()
                }
                .buttonStyle(PushButtonStyle())

                if viewModel.isInContacts && !viewModel.isSelf {
                    AsyncButton("Remove User", role: .destructive) {
                        await removeUser()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(spacing: 0) {
            VStack {
                ProfileImageView(
                    emailAddress: viewModel.emailAddress.address,
                    size: 100
                )

                VStack {
                    if let name = viewModel.profile?[.name], !name.isEmpty {
                        Text(name).font(.title2)
                            .textSelection(.enabled)
                    }
                    Text(viewModel.emailAddress.address).font(.title3)
                        .textSelection(.enabled)

                    awayMessage
                }
                .foregroundStyle(.white)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.accent)

            headerText
        }
    }

    @ViewBuilder
    private var awayMessage: some View {
        if viewModel.profile?[boolean: .away] == true {
            HStack(alignment: .firstTextBaseline) {
                Text("away")
                    .font(.caption.bold())
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .background {
                        RoundedRectangle(cornerRadius: 4)
                            .foregroundStyle(.accent)
                    }

                if let awayWarning = viewModel.profile?[.awayWarning] {
                    Text(awayWarning)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
            }
            .padding(10)
            .background(.quinary)
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
    }

    @ViewBuilder
    private var headerText: some View {
        // TODO
        EmptyView()

//        if let headerText = viewModel.headerText {
//            if isContactRequest {
//                contactRequestHeaderBar(text: headerText)
//            } else {
//                HStack(spacing: 4) {
//                    Spacer()
//                    Image(systemName: "info.circle.fill")
//                        .resizable()
//                        .symbolRenderingMode(.palette)
//                        .foregroundStyle(.white, .blue)
//                        .frame(width: 16, height: 16)
//                    Text(headerText)
//                    Spacer()
//                }
//                .padding(.vertical, 10)
//                .background(.quinary)
//            }
//        }
    }

    @ViewBuilder
    private func contactRequestHeaderBar(text: String) -> some View {
        HStack {
            Text(text)
            Spacer()
            AsyncButton("Add") {
                await addToContacts()
            }
            .buttonStyle(PushButtonStyle())
        }
        .padding(10)
        .background(.yellow)
        .environment(\.colorScheme, .light)
    }

    private func removeUser() async {
        do {
            try await viewModel.removeFromContacts()
        } catch {
            // TODO: show error
            Log.error("Could not remove contact:", context: error)
        }
    }

    private func addToContacts() async {
        do {
            try await viewModel.addToContacts()
        } catch {
            // TODO: show error
            Log.error("Could not add contact:", context: error)
        }
    }
}

#if DEBUG

#Preview("full profile") {
    let client = EmailClientMock()
    client.stubFetchedProfile = .makeFake()
    InjectedValues[\.client] = client

    return ProfileView(
        emailAddress: .init("mickey@mouse.com")!,
        showActionButtons: true,
        isContactRequest: false,
        onProfileLoaded: nil
    )
}

#Preview("away") {
    let client = EmailClientMock()
    client.stubFetchedProfile = .makeFake(awayWarning: "Gone for vacation 🌴")
    InjectedValues[\.client] = client

    return ProfileView(
        emailAddress: .init("mickey@mouse.com")!,
        showActionButtons: true,
        isContactRequest: false,
        onProfileLoaded: nil
    )
}

#Preview("no name") {
    let client = EmailClientMock()
    client.stubFetchedProfile = .makeFake(name: nil)
    InjectedValues[\.client] = client

    return ProfileView(
        emailAddress: .init("mickey@mouse.com")!,
        showActionButtons: true,
        isContactRequest: false,
        onProfileLoaded: nil
    )
}

#Preview("no action buttons") {
    let client = EmailClientMock()
    client.stubFetchedProfile = .makeFake()
    InjectedValues[\.client] = client

    return ProfileView(
        emailAddress: .init("mickey@mouse.com")!,
        showActionButtons: false,
        isContactRequest: false,
        onProfileLoaded: nil
    )
}

#endif
