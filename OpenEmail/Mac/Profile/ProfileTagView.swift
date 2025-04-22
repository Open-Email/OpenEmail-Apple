import SwiftUI
import OpenEmailCore
import OpenEmailPersistence
import Logging

struct ProfileTagView: View {
    
    @Environment(\.isEnabled) var isEnabled: Bool
    @AppStorage(UserDefaultsKeys.profileName) var profileName: String?
    @State var profileViewModel: ProfileViewModel

    private let isTicked: Bool
    @State private var showContactPopover = false

    @Injected(\.client) private var client
    @Injected(\.contactsStore) private var contactsStore: ContactStoring

    let isSelected: Bool
    let onRemoveReader: (() -> Void)?
    let automaticallyShowProfileIfNotInContacts: Bool
    let canRemoveReader: Bool
    let showsActionButtons: Bool
    let onClick: ((String) -> Void)?

    init(
        emailAddress: EmailAddress,
        isSelected: Bool,
        isTicked: Bool = false,
        onRemoveReader: (() -> Void)? = nil,
        automaticallyShowProfileIfNotInContacts: Bool,
        canRemoveReader: Bool,
        showsActionButtons: Bool,
        onShowProfile: ((String) -> Void)? = nil
    ) {
        profileViewModel = ProfileViewModel(
            emailAddress: emailAddress,
        )
        self.isSelected = isSelected
        self.isTicked = isTicked
        self.onRemoveReader = onRemoveReader
        self.automaticallyShowProfileIfNotInContacts = automaticallyShowProfileIfNotInContacts
        self.canRemoveReader = canRemoveReader
        self.showsActionButtons = showsActionButtons
        self.onClick = onShowProfile
    }

    private var foregroundColor: Color {
        if isSelected {
            return .white
        } else {
            return .primary
        }
    }

    var body: some View {
        ZStack(alignment: Alignment.topTrailing) {
            HStack(spacing: .Spacing.xxxSmall) {
                if profileViewModel.isInContacts {
                    Image(.readerInContacts)
                } else {
                    Image(.readerNotInContacts)
                }

                if profileViewModel.isSelf {
                    Text("me")
                } else {
                    Text(
                        profileViewModel.profile?.name
                            .truncated(
                                to: 30
                            ) ?? profileViewModel.emailAddress.address
                    )
                }

                if isTicked {
                    Image(systemName: "checkmark")
                        .controlSize(.mini)
                        .bold()
                }
            }
            .lineLimit(1)
            .padding(.vertical, .Spacing.xxxSmall)
            .padding(.horizontal, .Spacing.xSmall)
            .foregroundStyle(foregroundColor)
            .background(Capsule().fill(.themeBadgeBackground))
            .help(profileViewModel.isInContacts ? "Reader is in my contacts" : "Reader is not in my contacts")
            .onTapGesture {
                guard isEnabled else { return }
                showProfile()
            }
            .popover(isPresented: $showContactPopover) {
                ProfilePopover(
                    profileViewModel: profileViewModel,
                    onDismiss: {
                        showContactPopover = false
                    },
                    onRemoveReader: self.onRemoveReader,
                    showsActionButtons: showsActionButtons,
                    canRemoveReader: canRemoveReader
                )
            }
            
            let seenRecently: Bool = if let lastSeen = profileViewModel.profile?.lastSeen,
                                        let date = ISO8601DateFormatter.backendDateFormatter.date(
                                            from: lastSeen
                                        ) {
                abs(date.timeIntervalSinceNow.asHours) < 1.0
            } else {
                false
            }
            
            let away: Bool = profileViewModel.profile?.away ?? false
            
            if (seenRecently || away) {
                Circle()
                    .fill(away ? .themeRed : .themeGreen)
                    .frame(width: 8, height: 8)
            }
            
        }
        
    }

    private func showProfile() {
        if let onShowProfile = onClick {
            onShowProfile(profileViewModel.emailAddress.address)
        } else {
            showContactPopover = true
        }
    }

}

struct ProfilePopover: View {
    
    
    let profileViewModel: ProfileViewModel
    let onRemoveReader: (() -> Void)?
    let onDismiss: (() -> Void)
    let showsActionButtons: Bool
    let canRemoveReader: Bool
    
    init(
        profileViewModel: ProfileViewModel,
        onDismiss: @escaping (() -> Void),
        onRemoveReader: (() -> Void)? = nil,
        showsActionButtons: Bool,
        canRemoveReader: Bool
    ) {
        self.profileViewModel = profileViewModel
        self.onRemoveReader = onRemoveReader
        self.onDismiss = onDismiss
        self.showsActionButtons = showsActionButtons
        self.canRemoveReader = canRemoveReader
    }
    
    var body: some View {
        
        let hasLoadedProfile = profileViewModel.profile != nil
        let indicateThatNotInOthersContacts: Bool = profileViewModel.isInOtherContacts == false
        
        VStack {
            ProfileView(
                viewModel: profileViewModel,
                showActionButtons: showsActionButtons,
                verticalLayout: false,
                profileImageSize: 200
            )
            .frame(idealWidth: 500, minHeight: 250)

            if canRemoveReader && (
                !profileViewModel.isInContacts || indicateThatNotInOthersContacts
            ) {
                HStack {
                    Spacer()
                    Button("Remove Reader") {
                        onRemoveReader?()
                        onDismiss()
                        
                    }

                    if !profileViewModel.isSelf && !profileViewModel.isInContacts {
                        AsyncButton("Add Contact") {
                            do {
                                try await profileViewModel.addToContacts()
                                onDismiss()
                            } catch {
                                Log.error("Could not add to contacts keys:", context: error)
                            }
                            
                        }
                        .disabled(!hasLoadedProfile)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .background(.themeViewBackground)
    }
    
}

#if DEBUG

#Preview {
    VStack {
        ProfileTagView(emailAddress: EmailAddress("mickey@mouse.com")!, isSelected: false, isTicked: false,onRemoveReader: nil, automaticallyShowProfileIfNotInContacts: false, canRemoveReader: false, showsActionButtons: true)
        
        ProfileTagView(emailAddress: EmailAddress("mickey@mouse.com")!, isSelected: true, isTicked: true, onRemoveReader: nil, automaticallyShowProfileIfNotInContacts: false, canRemoveReader: false, showsActionButtons: true)
    }
    .padding()
    .background(.themeViewBackground)
}

#endif
