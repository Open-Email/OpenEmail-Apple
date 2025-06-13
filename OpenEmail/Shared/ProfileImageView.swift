import SwiftUI
import OpenEmailCore
import Utils

enum ProfileImageShapeType {
    case circle
    case rectangle
    case roundedRectangle(cornerRadius: CGFloat)
}

enum ProfileImageSize {
    case small
    case medium
    case large
    case huge
    
    var size: CGFloat {
           switch self {
           case .small:  return 32.0
           case .medium: return 40.0
           case .large:  return 64.0
           case .huge:  return 250.0
           }
       }
}

struct ProfileImageView: View {
    private let emailAddress: String?
    @State private var name: String?
    @State private var image: Image?
    private let type: ProfileImageShapeType
    private let size: ProfileImageSize
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

    /// Initializer
    ///
    /// - Parameters:
    ///   - emailAddress: The email address of the user profile
    ///   - multipleUsersCount: If present, displays a count instead of an individual user's profile image
    ///   - name: The name of the user, used for abbreviation placeholder when there is no image
    ///   - shape: The shape of the profile image (circle or rounded rectangle)
    ///   - size: The bounding box size of the profile image (bounding box is always square)
    init(
        emailAddress: String?,
        multipleUsersCount: Int? = nil,
        name: String? = nil,
        shape: ProfileImageShapeType = .circle,
        size: ProfileImageSize,
    ) {
        self.type = shape
        self.size = size
        self.emailAddress = emailAddress
        self.name = name
        self.multipleUsersCount = multipleUsersCount
    }

    var body: some View {
        Group {
            switch type {
            case .circle:
                ZStack {
                    Circle()
                        .fill(.themeIconBackground)
                        .frame(width: size.size, height: size.size)
                        .overlay {
                            if colorScheme == .light {
                                Circle().stroke(Color.themeLineGray)
                            }
                        }

                    makeImage()
                }
                .frame(width: size.size, height: size.size)
                .clipShape(Circle())
                .shadow(color: .themeShadow, radius: 4, y: 2)
            case .rectangle:
                Color.clear
                    .background {
                        makeImage()
                    }
            case .roundedRectangle(let cornerRadius):
                makeImage()
                    .frame(width: size.size, height: size.size)
                    .background()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .shadow(color: .themeShadow, radius: 10, y: 2)
            }
        }
        .blur(radius: isLoading ? 4 : 0)
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
        if let image = image {
            image
                .resizable()
                .scaledToFill()
        } else {
            Image(.logoSmall)
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(.accent)
                .frame(maxWidth: 64, maxHeight: 64)
                .aspectRatio(contentMode: .fit)
                .padding( .Spacing.xxxSmall)
                .scaledToFit()
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
        ProfileImageView(
            emailAddress: "mickey@mouse.com",
            name: nil,
            size: .small
        )
        ProfileImageView(emailAddress: "mickey@mouse.com", name: "Mickey Mouse", size: .medium)
        ProfileImageView(emailAddress: nil, multipleUsersCount: 3, size: .large)
    }
    .padding()
}

#Preview("Placeholder rounded rect") {
    ProfileImageView(
        emailAddress: nil,
        name: nil,
        shape: .roundedRectangle(cornerRadius: .CornerRadii.small),
        size: .large
    )
    .padding()
}

#Preview("Rounded rect") {
    ProfileImageView(
        emailAddress: "mickey@mouse.com",
        name: "Mickey Mouse",
        shape: .roundedRectangle(cornerRadius: .CornerRadii.small),
        size: .large
    )
    .padding()
}

#Preview("Rounded rect large") {
    ProfileImageView(
        emailAddress: "mickey@mouse.com",
        name: "Mickey Mouse",
        shape: .roundedRectangle(cornerRadius: .CornerRadii.default),
        size: .large
    )
    .padding()
}

#Preview("Rounded rect placeholder large") {
    VStack {
        ProfileImageView(
            emailAddress: "mickey@mouse.com",
            name: nil,
            shape: .roundedRectangle(cornerRadius: .CornerRadii.default),
            size: .large
        )
    }
    .frame(width: 320, height: 500)
    .padding()
}

#Preview("Rect") {
    VStack {
        ProfileImageView(
            emailAddress: "mickey@mouse.com",
            name: "Mickey Mouse",
            shape: .rectangle,
            size: .large
        )
        .padding()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .ignoresSafeArea(edges: .top)
}
