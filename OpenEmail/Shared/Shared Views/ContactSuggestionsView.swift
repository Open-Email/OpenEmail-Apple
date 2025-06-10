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
        .frame(height: rowHeight * CGFloat(min(Self.maxVisibleRows, suggestions.count)))
        .padding(.Spacing.small)
    }
}

private struct SuggestionRowView: View {
    @State var contact: Contact
    @State private var isHovering: Bool = false

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(
                cornerRadius: .CornerRadii.default,
                style: .continuous
            )
                .foregroundColor(isHovering ? .accentColor : .clear)

            HStack(spacing: .Spacing.xSmall) {
                ProfileImageView(
                    emailAddress: contact.address,
                    name: contact.cachedName,
                    size: .medium
                )

                Text(text)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(isHovering ? .white: .primary)
            }.padding(.Spacing.xSmall)
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
