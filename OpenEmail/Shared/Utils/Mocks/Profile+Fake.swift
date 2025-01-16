import Foundation
import OpenEmailCore

extension Profile {
    static func makeFake(
        name: String? = "Mickey Mouse",
        about: String? = "🐭✨ The OG cartoon icon! 🌟✨ Debuted in 1928's \"Steamboat Willie,\" I've been spreading joy with my iconic red shorts and signature ears ever since 🎉",
        awayWarning: String? = nil
    ) -> Profile {
        Profile(
            address: EmailAddress("mickey@mouse.com")!,
            profileData: [
                .name: name ?? "",
                .about: about ?? "",
                .away: awayWarning == nil ? "" : "Yes",
                .awayWarning: awayWarning ?? "",
                .interests: "Cheese, Mini Mouse",
                .movies: "Bambi, Dumbo, Fantasia",
                .lastSeenPublic: "Yes"
            ]
        )
    }
}
