import SwiftUI
import OpenEmailCore
import Logging

struct ProfileView: View {
    @State private var viewModel: ProfileViewModel
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) var registeredEmailAddress: String?
    @Environment(\.openWindow) private var openWindow

    private let showActionButtons: Bool
    private let isContactRequest: Bool
    private let verticalLayout: Bool
    private let profileImageSize: CGFloat?
    @State private var showRemoveContactConfirmationAlert = false

    private let onClose: (() -> Void)?

    init(
        profile: Profile,
        showActionButtons: Bool = true,
        isContactRequest: Bool = false,
        verticalLayout: Bool = false,
        profileImageSize: CGFloat? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.showActionButtons = showActionButtons
        self.isContactRequest = isContactRequest
        self.verticalLayout = verticalLayout
        self.onClose = onClose
        self.profileImageSize = profileImageSize
        self.viewModel = ProfileViewModel(profile: profile)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .Spacing.large) {
            closeButton

            if !viewModel.isLoadingProfile {
                if !viewModel.isSelf, showActionButtons {
                    actionButtons
                        .padding(.horizontal, .Spacing.default)
                        .padding(.vertical, .Spacing.xSmall)
                }
                
                let canEditReceiveBroadcasts = !viewModel.isSelf && viewModel.isInContacts
                let receiveBroadcastsBinding = canEditReceiveBroadcasts && viewModel.receiveBroadcasts != nil ? Binding(
                    get: {
                        viewModel.receiveBroadcasts ?? true
                    },
                    set: { newValue in
                        Task {
                            await viewModel.updateReceiveBroadcasts(newValue)
                        }
                    }) : nil
                
                if verticalLayout {
                    ProfileAttributesView(
                        profile: $viewModel.profile,
                        receiveBroadcasts: receiveBroadcastsBinding,
                        hidesEmptyFields: true,
                        profileImageStyle: .shape()
                    )
                } else {
                    HStack(alignment: .top, spacing: .Spacing.default) {
                        ProfileImageView(
                            emailAddress: viewModel.profile.address.address,
                            shape: .roundedRectangle(cornerRadius: .CornerRadii.default),
                            size: profileImageSize ?? 288
                        )

                        ProfileAttributesView(
                            profile: $viewModel.profile,
                            receiveBroadcasts: receiveBroadcastsBinding,
                            hidesEmptyFields: true,
                            profileImageStyle: .none
                        )
                    }
                    .padding(.leading, .Spacing.default)
                    .padding(.top, .Spacing.xSmall)
                }
            } else {
                VStack {
                    if viewModel.isLoadingProfile {
                        ProgressView()
                    } else {
                        errorView
                    }
                }
                .padding(.Spacing.default)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.top, .Spacing.xSmall)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background{
            Color.themeViewBackground
                .if(verticalLayout) {
                    $0.shadow(color: .black.opacity(0.1), radius: 12, x: -4)
                }
        }
    }

    @ViewBuilder
    private var closeButton: some View {
        if verticalLayout, let onClose {
            HStack {
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .fontWeight(.medium)
                .foregroundStyle(.themeSecondary)
                .help("Close")
            }
            .padding(.bottom, -.Spacing.small)
            .padding(.horizontal, .Spacing.small)
        }
    }

    private var actionButtons: some View {
        HStack {}
//        HStack(spacing: .Spacing.xSmall) {
//            if viewModel.isInContacts {
//                AsyncButton {
//                    await viewModel.fetchMessages()
//                } label: {
//                    HStack(spacing: .Spacing.xxSmall) {
//                        Image(.downloadMessages)
//                            .resizable()
//                            .aspectRatio(contentMode: .fit)
//                            .frame(width: 18, height: 18)
//
//                        Text("Fetch messages")
//                    }
//                }
//            }
//
//            Button {
//                viewModel.refreshProfile()
//            } label: {
//                HStack(spacing: .Spacing.xxSmall) {
//                    Image(.reload)
//                        .resizable()
//                        .aspectRatio(contentMode: .fit)
//                        .frame(width: 18, height: 18)
//
//                    Text("Refresh")
//                }
//            }
//
//            if viewModel.isInContacts {
//                Button {
//                    showRemoveContactConfirmationAlert = true
//                } label: {
//                    Image(.delete)
//                        .resizable()
//                        .aspectRatio(contentMode: .fit)
//                }
//                .buttonStyle(ActionButtonStyle(isImageOnly: true, height: 32))
//                .help("Remove from contacts")
//                .alert("Are you sure you want to remove this contact?", isPresented: $showRemoveContactConfirmationAlert) {
//                    Button("Cancel", role: .cancel) {}
//                    AsyncButton("Remove", role: .destructive) {
//                        await removeUser()
//                    }
//                } message: {
//                    Text("This action cannot be undone.")
//                }
//            }
//
//            Spacer()
//
//            if viewModel.isInContacts {
//                Button {
//                    guard let registeredEmailAddress else { return }
//                    openWindow(id: WindowIDs.compose, value: ComposeAction.newMessage(id: UUID(), authorAddress: registeredEmailAddress, readerAddress: viewModel.emailAddress.address))
//                } label: {
//                    HStack(spacing: .Spacing.xxSmall) {
//                        Image(.createMessage)
//                        Text("Create message")
//                    }
//                }
//                .buttonStyle(ActionButtonStyle(height: 32, isProminent: true))
//            } else if !viewModel.isSelf {
//                AsyncButton {
//                    await addToContacts()
//                } label: {
//                    HStack(spacing: .Spacing.xxSmall) {
//                        Image(.addToContacts)
//                            .resizable()
//                            .aspectRatio(contentMode: .fit)
//                            .frame(width: 18, height: 18)
//
//                        Text("Add to Contacts")
//                    }
//                }
//            }
//        }
//        .buttonStyle(ActionButtonStyle(height: 32))
    }

    private var errorView: some View {
        VStack(spacing: .Spacing.default) {
            HStack(spacing: .Spacing.xxxSmall) {
                WarningIcon()
                Text(viewModel.errorText)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Retry") {
                    viewModel.refreshProfile()
                }
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
        profile: .init(address: .init("mickey@mouse.com")!, profileData: [:]),
        showActionButtons: true,
        isContactRequest: false
    )
    .frame(width: 700, height: 500)
}

#Preview("full profile, vertical") {
    let client = EmailClientMock()
    client.stubFetchedProfile = .makeFake()
    InjectedValues[\.client] = client

    return ProfileView(
        profile: .init(address: .init("mickey@mouse.com")!, profileData: [:]),
        showActionButtons: false,
        isContactRequest: false,
        verticalLayout: false,
        onClose: {}
    )
    .frame(width: 330, height: 600)
    .fixedSize()
}


#Preview("away") {
    let client = EmailClientMock()
    client.stubFetchedProfile = .makeFake(awayWarning: "Gone for vacation 🌴")
    InjectedValues[\.client] = client

    return ProfileView(
        profile: .init(address: .init("mickey@mouse.com")!, profileData: [:]),
        showActionButtons: true,
        isContactRequest: false
    )
    .frame(width: 700, height: 500)
}

#Preview("no name") {
    let client = EmailClientMock()
    client.stubFetchedProfile = .makeFake(name: nil)
    InjectedValues[\.client] = client

    return ProfileView(
        profile: .init(address: .init("mickey@mouse.com")!, profileData: [:]),
        showActionButtons: true,
        isContactRequest: false
    )
    .frame(width: 700, height: 500)
}

#Preview("no action buttons") {
    let client = EmailClientMock()
    client.stubFetchedProfile = .makeFake()
    InjectedValues[\.client] = client

    return ProfileView(
        profile: .init(address: .init("mickey@mouse.com")!, profileData: [:]),
        showActionButtons: false,
        isContactRequest: false
    )
    .frame(width: 700, height: 500)
}

#Preview("contact request") {
    let client = EmailClientMock()
    client.stubFetchedProfile = .makeFake()
    InjectedValues[\.client] = client

    return ProfileView(
        profile: .init(address: .init("mickey@mouse.com")!, profileData: [:]),
        showActionButtons: true,
        isContactRequest: true
    )
    .frame(width: 700, height: 500)
}

#endif
