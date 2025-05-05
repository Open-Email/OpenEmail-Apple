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
    let onClick: ((Profile) -> Void)?

    init(
        profile: Profile,
        isSelected: Bool,
        isTicked: Bool = false,
        onRemoveReader: (() -> Void)? = nil,
        automaticallyShowProfileIfNotInContacts: Bool,
        canRemoveReader: Bool,
        showsActionButtons: Bool,
        onShowProfile: ((Profile) -> Void)? = nil
    ) {
        profileViewModel = ProfileViewModel(profile: profile)
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
                        profileViewModel.profile.name.truncated(to: 30)
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
                    profile: profileViewModel.profile,
                    onDismiss: {
                        showContactPopover = false
                    },
                    onRemoveReader: self.onRemoveReader,
                    showsActionButtons: showsActionButtons,
                    canRemoveReader: canRemoveReader
                )
            }
            
            let seenRecently: Bool = if let date = ISO8601DateFormatter.backendDateFormatter.date(
                                            from: profileViewModel.profile.lastSeen
                                        ) {
                abs(date.timeIntervalSinceNow.asHours) < 1.0
            } else {
                false
            }
            
            let away: Bool = profileViewModel.profile.away
            
            if (seenRecently || away) {
                Circle()
                    .fill(away ? .themeRed : .themeGreen)
                    .frame(width: 8, height: 8)
            }
        }
    }

    private func showProfile() {
        if let onShowProfile = onClick {
            onShowProfile(profileViewModel.profile)
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
        profile: Profile,
        onDismiss: @escaping (() -> Void),
        onRemoveReader: (() -> Void)? = nil,
        showsActionButtons: Bool,
        canRemoveReader: Bool
    ) {
        self.profileViewModel = ProfileViewModel(profile: profile)
        self.onRemoveReader = onRemoveReader
        self.onDismiss = onDismiss
        self.showsActionButtons = showsActionButtons
        self.canRemoveReader = canRemoveReader
    }
    
    var body: some View {
        
        let indicateThatNotInOthersContacts: Bool = profileViewModel.isInOtherContacts == false
        
        VStack {
            ProfileView(
                profile: profileViewModel.profile,
            )
            .frame(
                minHeight: ProfileImageSize.huge.size + 2 * .Spacing.default
            )

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
                    }
                }
            }
        }
    }
}

#if DEBUG

#Preview {
    VStack {
        ProfileTagView(
            profile: Profile(
                address: EmailAddress("mickey@mouse.com")!,
                profileData: [:]
            ),
            isSelected: false,
            isTicked: false,
            onRemoveReader: nil,
            automaticallyShowProfileIfNotInContacts: false,
            canRemoveReader: false,
            showsActionButtons: true
        )
        
        ProfileTagView(profile: Profile(
            address: EmailAddress("mickey@mouse.com")!,
            profileData: [:]
        ), isSelected: true, isTicked: true, onRemoveReader: nil, automaticallyShowProfileIfNotInContacts: false, canRemoveReader: false, showsActionButtons: true)
    }
    .padding()
    .background(.themeViewBackground)
}

#endif
