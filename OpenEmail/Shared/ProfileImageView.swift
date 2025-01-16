import SwiftUI
import OpenEmailCore
import Utils

struct ProfileImageView: View {
    private let emailAddress: String?
    @State private var name: String?
    @State private var image: Image?
    private let overrideImage: Image?
    private let type: ShapeType
    private let size: CGFloat
    private let multipleUsersCount: Int?

    @State private var isLoading = false

    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?
    @Environment(\.colorScheme) private var colorScheme

    @Injected(\.client) private var client

    private var placeholderText: String {
        if let multipleUsersCount {
            return "\(multipleUsersCount)R"
        } else {
            return name?.placeholderText ?? emailAddress?.placeholderText ?? "?"
        }
    }

    enum ShapeType {
        case circle
        case roundedRectangle(cornerRadius: CGFloat)
    }
    
    /// Initializer
    ///
    /// - Parameters:
    ///   - emailAddress: The email address of the user profile
    ///   - multipleUsersCount: If present, displays a count instead of an individual user's profile image
    ///   - name: The name of the user, used for abbreviation placeholder when there is no image
    ///   - overrideImage: If present, this is used as the image instead of the actual profile image
    ///   - shape: The shape of the profile image (circle or rounded rectangle)
    ///   - size: The bounding box size of the profile image (bounding box is always square)
    init(
        emailAddress: String?,
        multipleUsersCount: Int? = nil,
        name: String? = nil,
        overrideImage: Image? = nil,
        shape: ShapeType = .circle,
        size: CGFloat = 40
    ) {
        self.type = shape
        self.size = size
        self.emailAddress = emailAddress
        self.name = name
        self.overrideImage = overrideImage
        self.multipleUsersCount = multipleUsersCount
    }

    var body: some View {
        VStack {
            switch type {
            case .circle:
                ZStack {
                    Circle()
                        .fill(.themeIconBackground)
                        .frame(width: size, height: size)
                        .overlay {
                            if colorScheme == .light {
                                Circle().stroke(Color.themeLineGray)
                            }
                        }

                    makeImage()
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
                .blur(radius: isLoading ? 4 : 0)
                .shadow(color: .themeShadow, radius: 4, y: 2)
            case .roundedRectangle(let cornerRadius):
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.themeSecondary)
                        .frame(width: size, height: size)

                    makeImage()
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .blur(radius: isLoading ? 4 : 0)
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .onChange(of: emailAddress) {
            reloadImage()
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileImageUpdated).receive(on: DispatchQueue.main)) { _ in
            if registeredEmailAddress == emailAddress {
                reloadImage()
            }
        }
        .onAppear {
            reloadImage()
        }
    }

    private func reloadImage() {
        guard
            multipleUsersCount == nil,
            overrideImage == nil,
            let emailAddressStr = emailAddress,
            let emailAddress = EmailAddress(emailAddressStr)
        else {
            image = nil
            return
        }

        isLoading = true
        Task {
            if let imageData = try? await client.fetchProfileImage(address: emailAddress, force: false) {
                image = OEImage(data: imageData)?.swiftUIImage
            } else {
                image = nil
            }

            isLoading = false
        }
    }

    @ViewBuilder
    private func makeImage() -> some View {
        if let image = overrideImage ?? image {
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
        } else {
            Text(placeholderText)
                .foregroundStyle(.primary)
                .font(.system(size: 14))
                .fontWeight(.semibold)
        }
    }
}

private extension String {
    private var firstAsString: String? {
        guard let first else { return nil }
        return String(first)
    }

    var placeholderText: String? {
        var placeholder: String?

        let components = self
            .components(separatedBy: " ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if components.count == 1 {
            placeholder = components[0].firstAsString
        } else if components.count > 1 {
            placeholder = [components.first?.firstAsString, components.last?.firstAsString]
                .compactMap { $0 }
                .joined()
        }

        return placeholder?.uppercased()
    }
}

#Preview("Circle") {
    VStack {
        ProfileImageView(emailAddress: "mickey@mouse.com", name: nil)
        ProfileImageView(emailAddress: "mickey@mouse.com", name: "Mickey Mouse")
        ProfileImageView(emailAddress: "mickey@mouse.com", name: "Mickey Mouse", overrideImage: Image("sample-profile-1"))
        ProfileImageView(emailAddress: nil, multipleUsersCount: 3)
    }
    .padding()
}

#Preview("Placeholder rounded rect") {
    ProfileImageView(
        emailAddress: nil,
        name: nil,
        shape: .roundedRectangle(cornerRadius: .CornerRadii.small)
    )
    .padding()
}

#Preview("Rounded rect") {
    ProfileImageView(
        emailAddress: "mickey@mouse.com",
        name: "Mickey Mouse",
        overrideImage: Image("sample-profile-1"),
        shape: .roundedRectangle(cornerRadius: .CornerRadii.small)
    )
    .padding()
}

#Preview("Rounded rect large") {
    ProfileImageView(
        emailAddress: "mickey@mouse.com",
        name: "Mickey Mouse",
        overrideImage: Image("sample-profile-1"),
        shape: .roundedRectangle(cornerRadius: .CornerRadii.default),
        size: 288
    )
    .padding()
}

#Preview("Rounded rect placeholder large") {
    ProfileImageView(
        emailAddress: "mickey@mouse.com",
        name: nil,
        shape: .roundedRectangle(cornerRadius: .CornerRadii.default),
        size: 288
    )
    .padding()
}
