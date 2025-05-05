import Foundation

public enum ProfileAttribute: String, CaseIterable, Codable, Sendable {
    case about = "About"
    case addressExpansion = "Address-Expansion"
    case away = "Away"
    case awayWarning = "Away-Warning"
    case birthday = "Birthday"
    case books = "Books"
    case department = "Department"
    case education = "Education"
    case encryptionKey = "Encryption-Key"
    case gender = "Gender"
    case interests = "Interests"
    case jobTitle = "Job-Title"
    case languages = "Languages"
    case lastSigningKey = "Last-Signing-Key"
    case lastSeenPublic = "Last-Seen-Public"
    case lastSeen = "Last-Seen"
    case location = "Location"
    case mailingAddress = "Mailing-Address"
    case movies = "Movies"
    case music = "Music"
    case name = "Name"
    case notes = "Notes"
    case organization = "Organization"
    case phone = "Phone"
    case placesLived = "Places-Lived"
    case publicAccess = "Public-Access"
    case publicLinks = "Public-Links"
    case relationshipStatus = "Relationship-Status"
    case signingKey = "Signing-Key"
    case sports = "Sports"
    case status = "Status"
    case streams = "Streams"
    case website = "Website"
    case work = "Work"
    case updated = "Updated"
}

public struct Link {
    public var address: EmailAddress
    public var link: String
    public var allowedBroadcasts: Bool
    
    public init(encryptedLink: String, localUser: LocalUser) throws {
        
        let parts = encryptedLink.split(separator: ",", maxSplits: 2)
        
        if parts.count == 2 {
            let linkStr = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let contactData = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let decryptedDataBytes = try? Crypto.decryptAnonymous(
                cipherText: contactData,
                privateKey: localUser.privateEncryptionKey,
                publicKey: localUser.publicEncryptionKey
            ), let decryptedData = String(bytes: decryptedDataBytes, encoding: .ascii) {
                
                self.link = linkStr
                let splitAtributes = decryptedData.split(separator: ";", maxSplits: 2)
                let attributesMap = Dictionary<String, String>(
                    uniqueKeysWithValues: splitAtributes.map {
                        let keyValue = $0.split(separator: "=")
                        if (keyValue.count == 2) {
                            return (
                                keyValue[0]
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                    .lowercased(),
                                String(keyValue[1]
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                    .lowercased())
                            )
                        } else {
                            return ("address", String($0))
                        }
                    })
                
                if (!attributesMap.keys.contains("address")) {
                    throw ParsingError.badLinkAttributesStructure
                }
                
                if let address = EmailAddress(attributesMap["address"]) {
                    self.address = address
                } else {
                    throw ParsingError.badLinkAttributesStructure
                }
                
                allowedBroadcasts = Bool(attributesMap["broadcasts"] != "no")
                
            } else {
                throw ParsingError.badLinkAttributesStructure
            }
           
        } else {
            throw ParsingError.badLinkAttributesStructure
        }
    }
}

public struct Profile: User, Codable, Equatable, Sendable, Identifiable {
    public var address: EmailAddress
    public var encryptionKeyId: String? = ""
    public var encryptionAlgorithm: String? = ""
    public var signingAlgorithm: String?
    public var id: String { address.address }
    public var attributes: [ProfileAttribute: String] = [:]
    // TODO: add all unrecognized attributes here
    public var customAttributes: [String: String] = [:]

    public init(address: EmailAddress, profileData: [ProfileAttribute: String]) {
        self.address = address
        self.attributes = profileData

        // TODO: Last signing key
        // We still need to implemenet periodical keys rotation. Once you rotate (generate new) keys, you won’t be able to fetch / decrypt messages
        // from senders which were "sent" to you according to your old keys. So that means old keys have to be kept in the app for at least max message duration time.
        if let signingkeyHeader = profileData[.signingKey] {
            let signingKeyAttrMap = Envelope.parseHeaderAttributes(header:  signingkeyHeader)
            if let keyAttr = signingKeyAttrMap["value"],
               let keyAlgorithm = signingKeyAttrMap["algorithm"],
               keyAlgorithm == Crypto.SIGNING_ALGORITHM {
                signingAlgorithm = keyAlgorithm
                attributes[.signingKey] = keyAttr
            }
        }
        if let enckeyHeader = profileData[.encryptionKey] {
            let encKeyAttrMap = Envelope.parseHeaderAttributes(header:  enckeyHeader)
            if
                let keyAttr = encKeyAttrMap["value"],
                let keyAlgorithm = encKeyAttrMap["algorithm"],
                let keyId = encKeyAttrMap["id"],
                keyAlgorithm == Crypto.ANONYMOUS_ENCRYPTION_CIPHER
            {
                attributes[.encryptionKey] = keyAttr
                encryptionAlgorithm = Crypto.ANONYMOUS_ENCRYPTION_CIPHER // Just one supported at the moment
                encryptionKeyId = keyId
            }
        }
    }

    public subscript(attribute: ProfileAttribute) -> String? {
        get {
            attributes[attribute]
        }

        set(newValue) {
            attributes[attribute] = newValue
        }
    }

    private enum BooleanValues {
        static let True = "Yes"
        static let False = "No"
    }

    public subscript(boolean attribute: ProfileAttribute) -> Bool? {
        get {
            guard let attr = attributes[attribute] else {
                // Only .away defaults to False
                return attribute != .away
            }
            return attr.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == BooleanValues.True.lowercased()
        }

        set(newValue) {
            if let newValue {
                attributes[attribute] = newValue ? BooleanValues.True : BooleanValues.False
            } else {
                attributes[attribute] = nil
            }
        }
    }

    public func serialize() -> Data? {
        var serializedAttributes: [String: String] = [:]

        // Iterate through all profile attributes
        for attribute in ProfileAttribute.allCases {
            switch attribute {
            case .updated:
                let currentDate = Date()
                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.timeZone = TimeZone(identifier: "UTC")
                serializedAttributes[attribute.rawValue] = dateFormatter.string(from: currentDate)

            case .signingKey:
                if let value = attributes[.signingKey], let signingAlgorithm {
                    serializedAttributes[ProfileAttribute.signingKey.rawValue] = "algorithm=\(signingAlgorithm); value=\(value)"
                }

            case .encryptionKey:
                if let value = attributes[.encryptionKey], let encryptionAlgorithm, let encryptionKeyId {
                    serializedAttributes[ProfileAttribute.encryptionKey.rawValue] = "id=\(encryptionKeyId); algorithm=\(encryptionAlgorithm); value=\(value)"
                }

            case .publicAccess, .publicLinks, .lastSeenPublic, .away:
                if let boolValue = self[boolean: attribute] {
                    serializedAttributes[attribute.rawValue] = boolValue ? BooleanValues.True : BooleanValues.False

                    // Only if Away is Yes, publish also AwayWarning
                    if 
                        attribute == ProfileAttribute.away,
                        boolValue,
                        let awayWarning = attributes[ProfileAttribute.awayWarning] 
                    {
                        serializedAttributes[ProfileAttribute.awayWarning.rawValue] = awayWarning
                    }
                }

            case .awayWarning:
                // Ignore
                continue

            default:
                if let value = attributes[attribute], !value.isEmpty {
                    serializedAttributes[attribute.rawValue] = value
                }
            }
        }

        var serializeString = "# Profile of \(address)\n"
        for (k, v) in serializedAttributes {
            serializeString += "\(k): \(v)\n"
        }
        serializeString += "# End of profile"
        return serializeString.data(using: .utf8)
    }
}

public extension Profile {
    var about: String {
        get { self[.about] ?? "" }
        set { self[.about] = newValue }
    }
    var addressExpansion: String {
        get { self[.addressExpansion] ?? "" }
        set { self[.addressExpansion] = newValue }
    }
    var away: Bool {
        get { self[boolean: .away] ?? false }
        set { self[boolean: .away] = newValue }
    }
    var awayWarning: String {
        get { self[.awayWarning] ?? "" }
        set { self[.awayWarning] = newValue }
    }
    var birthday: String {
        get { self[.birthday] ?? "" }
        set { self[.birthday] = newValue }
    }
    var books: String {
        get { self[.books] ?? "" }
        set { self[.books] = newValue }
    }
    var department: String {
        get { self[.department] ?? "" }
        set { self[.department] = newValue }
    }
    var education: String {
        get { self[.education] ?? "" }
        set { self[.education] = newValue }
    }
    var encryptionKey: String {
        get { self[.encryptionKey] ?? "" }
        set { self[.encryptionKey] = newValue }
    }
    var gender: String {
        get { self[.gender] ?? "" }
        set { self[.gender] = newValue }
    }
    var interests: String {
        get { self[.interests] ?? "" }
        set { self[.interests] = newValue }
    }
    var jobTitle: String {
        get { self[.jobTitle] ?? "" }
        set { self[.jobTitle] = newValue }
    }
    var languages: String {
        get { self[.languages] ?? "" }
        set { self[.languages] = newValue }
    }
    var lastSigningKey: String {
        get { self[.lastSigningKey] ?? "" }
        set { self[.lastSigningKey] = newValue }
    }
    var lastSeenPublic: Bool {
        get { self[boolean: .lastSeenPublic] ?? false }
        set { self[boolean: .lastSeenPublic] = newValue }
    }
    var lastSeen: String {
        get { self[.lastSeen] ?? "" }
        set { self[.lastSeen] = newValue }
    }
    var location: String {
        get { self[.location] ?? "" }
        set { self[.location] = newValue }
    }
    var mailingAddress: String {
        get { self[.mailingAddress] ?? "" }
        set { self[.mailingAddress] = newValue }
    }
    var movies: String {
        get { self[.movies] ?? "" }
        set { self[.movies] = newValue }
    }
    var music: String {
        get { self[.music] ?? "" }
        set { self[.music] = newValue }
    }
    var name: String {
        get { self[.name] ?? "" }
        set { self[.name] = newValue }
    }
    var notes: String {
        get { self[.notes] ?? "" }
        set { self[.notes] = newValue }
    }
    var organization: String {
        get { self[.organization] ?? "" }
        set { self[.organization] = newValue }
    }
    var phone: String {
        get { self[.phone] ?? "" }
        set { self[.phone] = newValue }
    }
    var placesLived: String {
        get { self[.placesLived] ?? "" }
        set { self[.placesLived] = newValue }
    }
    var publicAccess: Bool {
        get { self[boolean: .publicAccess] ?? false }
        set { self[boolean: .publicAccess] = newValue }
    }
    var publicLinks: Bool {
        get { self[boolean: .publicLinks] ?? false }
        set { self[boolean: .publicLinks] = newValue }
    }
    var relationshipStatus: String {
        get { self[.relationshipStatus] ?? "" }
        set { self[.relationshipStatus] = newValue }
    }
    var signingKey: String {
        get { self[.signingKey] ?? "" }
        set { self[.signingKey] = newValue }
    }
    var sports: String {
        get { self[.sports] ?? "" }
        set { self[.sports] = newValue }
    }
    var status: String {
        get { self[.status] ?? "" }
        set { self[.status] = newValue }
    }
    var streams: String {
        get { self[.streams] ?? "" }
        set { self[.streams] = newValue }
    }
    var website: String {
        get { self[.website] ?? "" }
        set { self[.website] = newValue }
    }
    var work: String {
        get { self[.work] ?? "" }
        set { self[.work] = newValue }
    }
    var updated: String {
        get { self[.updated] ?? "" }
        set { self[.updated] = newValue }
    }
}
