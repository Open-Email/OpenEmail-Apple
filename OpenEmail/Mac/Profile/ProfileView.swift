import SwiftUI
import OpenEmailCore
import Logging

struct ProfileView: View {
    @State private var viewModel: ProfileViewModel
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) var registeredEmailAddress: String?
    @Environment(\.openWindow) private var openWindow

    @State private var showRemoveContactConfirmationAlert = false

    init(
        profile: Profile
    ) {
        self.viewModel = ProfileViewModel(profile: profile)
    }
    var body: some View {
        
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
        
        HStack(alignment: .top, spacing: .Spacing.default) {
            ProfileImageView(
                emailAddress: viewModel.profile.address.address,
                shape: .roundedRectangle(cornerRadius: .CornerRadii.default),
                size: .huge
            )
            .padding(EdgeInsets(
                top: .Spacing.default,
                leading: .Spacing.default,
                bottom: 0,
                trailing: 0,
            ))
            ProfileAttributesView(
                profile: $viewModel.profile,
                receiveBroadcasts: receiveBroadcastsBinding,
                hidesEmptyFields: true,
                profileImageStyle: .none
            ).frame(idealWidth: 300)
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
    )
    .frame(width: 700, height: 500)
}

#Preview("full profile, vertical") {
    let client = EmailClientMock()
    client.stubFetchedProfile = .makeFake()
    InjectedValues[\.client] = client

    return ProfileView(
        profile: .init(address: .init("mickey@mouse.com")!, profileData: [:]),
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
    )
    .frame(width: 700, height: 500)
}

#Preview("no name") {
    let client = EmailClientMock()
    client.stubFetchedProfile = .makeFake(name: nil)
    InjectedValues[\.client] = client

    return ProfileView(
        profile: .init(address: .init("mickey@mouse.com")!, profileData: [:]),
    )
    .frame(width: 700, height: 500)
}

#Preview("no action buttons") {
    let client = EmailClientMock()
    client.stubFetchedProfile = .makeFake()
    InjectedValues[\.client] = client

    return ProfileView(
        profile: .init(address: .init("mickey@mouse.com")!, profileData: [:]),
    )
    .frame(width: 700, height: 500)
}

#Preview("contact request") {
    let client = EmailClientMock()
    client.stubFetchedProfile = .makeFake()
    InjectedValues[\.client] = client

    return ProfileView(
        profile: .init(address: .init("mickey@mouse.com")!, profileData: [:]),
    )
    .frame(width: 700, height: 500)
}

#endif
