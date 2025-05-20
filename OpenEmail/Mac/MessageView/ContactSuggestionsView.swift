import SwiftUI
import OpenEmailPersistence
import OpenEmailModel
import Logging

fileprivate let rowHeight: CGFloat = 56

struct ContactSuggestionsView: View {
    private let suggestions: [Contact]
    private var onSelectSuggestion: ((Contact) -> Void)?
    private static let maxVisibleRows = 10

    init(suggestions: [Contact], onSelectSuggestion: @escaping (Contact) -> Void) {
        self.suggestions = suggestions
        self.onSelectSuggestion = onSelectSuggestion
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(suggestions) { suggestion in
                    SuggestionRowView(contact: suggestion)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelectSuggestion?(suggestion)
                        }
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .fixedSize(horizontal: true, vertical: false)
        .frame(height: rowHeight * CGFloat(min(Self.maxVisibleRows, suggestions.count)))
        .padding(.Spacing.small)
    }
}

private struct SuggestionRowView: View {
    @State var contact: Contact
    @State private var isHovering: Bool = false

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: .Spacing.xxxSmall, style: .continuous)
                .foregroundColor(isHovering ? .accentColor : .clear)

            HStack(spacing: 0) {
                ProfileImageView(
                    emailAddress: contact.address,
                    name: contact.cachedName,
                    size: .medium
                )
                .padding(.horizontal, .Spacing.xxxSmall)

                Text(text)
                    .multilineTextAlignment(.leading)
                    .padding(.trailing, .Spacing.xxxSmall)
            }
        }
        .frame(height: rowHeight)
        .contentShape(Rectangle())
        .onHover {
            isHovering = $0
        }
    }

    private var text: String {
        if let name = contact.cachedName {
            return "\(name) – \(contact.address)"
        } else {
            return contact.address
        }
    }
}

#Preview {
    ContactSuggestionsView(suggestions: [
        .init(id: "1", addedOn: .now, address: "hello@open.email"),
        .init(id: "2", addedOn: .now, address: "hello2@open.email"),
        .init(id: "3", addedOn: .now, address: "hello3@open.email"),
    ], onSelectSuggestion: { _ in })
    .fixedSize()
}
