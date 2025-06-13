import SwiftUI
import OpenEmailModel
import OpenEmailCore
import Inspect
import Utils
import Logging

struct ProfileAttributesView: View {

    @Binding private var profile: Profile
    private let receiveBroadcasts: Binding<Bool>
    private let showBroadcasts: Bool

    init(
        profile: Binding<Profile>,
        showBroadcasts: Bool = true,
        receiveBroadcasts: Binding<Bool>,
    ) {
        _profile = profile
        self.showBroadcasts = showBroadcasts
        self.receiveBroadcasts = receiveBroadcasts
    }

#if canImport(UIKit)
    private let labeledContentStyle = VerticalLabeledContentStyle()
#else
    private let labeledContentStyle = AutomaticLabeledContentStyle()
#endif

    var body: some View {
        VStack(alignment: .leading) {
            // name and address
            awayMessage
                .padding(.bottom, .Spacing.default)
            
            if let name = profile[.name], !name.isEmpty {
                Text(name).font(.title2)
                    .textSelection(.enabled)
            }
            Text(profile.address.address).font(.headline)
                .textSelection(.enabled)
                .foregroundStyle(.secondary)
            
            // broadcasts
            if showBroadcasts {
                VStack(alignment: .leading, spacing: .Spacing.small) {
                    Divider()
                    Toggle(isOn: receiveBroadcasts) {
                        HStack(spacing: .Spacing.xSmall) {
                            Image(.scopeBroadcasts)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                            Text("Receive Broadcasts")
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(.accentColor)
                    Divider()
                }
                .padding(.vertical, .Spacing.xxxSmall)
            }
            
            ForEach(Profile.groupedAttributes) { group in
                if shouldDisplayGroup(group) {
                    Section {
                        ForEach(group.attributes, id: \.self) { attribute in
                            if shouldDisplayAttribute(attribute) {
                                component(for: attribute)
                                    .listRowSeparator(.hidden)
                            }
                        }
                    } header: {
                        if (group.groupType.shouldShowInPreview) {
                            Text(group.groupType.displayName)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                                .padding(.top, .Spacing.xSmall)
                        } else {
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func component(for attribute: ProfileAttribute) -> some View {
        switch attribute.attributeType {
        case .text(let multiline): textField(for: attribute, isMultiline: multiline)
        case .boolean: EmptyView()
        case .date(let relative):
            dateTextField(for: attribute, isRelative: relative)
        }
    }

    private func textField(for attribute: ProfileAttribute, isMultiline: Bool = false) -> some View {
        LabeledContent {
            Text(profile[attribute] ?? "")
                .font(.body)
                .textSelection(.enabled)
                .foregroundStyle(.primary)
        } label: {
            HStack(spacing: .Spacing.xSmall) {
                if let info = attribute.info {
                    InfoButton(text: info)
                }

                Text("\(attribute.displayTitle):")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func dateTextField(for attribute: ProfileAttribute, isRelative: Bool) -> some View {
        LabeledContent {
            Text(dateString(for: attribute, isRelative: isRelative))
                .font(.body)
                .foregroundStyle(.primary)
        } label: {
            HStack(spacing: .Spacing.xSmall) {
                if let info = attribute.info {
                    InfoButton(text: info)
                }

                Text("\(attribute.displayTitle):")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var awayMessage: some View {
        if profile[boolean: .away] == true {
            HStack(alignment: .firstTextBaseline, spacing: .Spacing.xSmall) {
                Text("away")
                    .textCase(.uppercase)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 4)
                    .background {
                        RoundedRectangle(cornerRadius: .CornerRadii.small)
                            .foregroundStyle(.accent)
                    }

                if let awayWarning = profile[.awayWarning] {
                    Text(awayWarning)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func dateString(for attribute: ProfileAttribute, isRelative: Bool) -> String {
        if
            let dateString = profile[attribute],
            let date = ISO8601DateFormatter.backendDateFormatter.date(from: dateString)
        {
            if isRelative {
                return RelativeDateTimeFormatter.default.localizedString(for: date, relativeTo: .now)
            } else {
                return DateFormatter.timeAndDateFormatter.string(from: date)
            }
        } else {
            return ""
        }
    }

    // MARK: - Helpers

    private func shouldDisplayGroup(_ group: ProfileAttributesGroup) -> Bool {

        if profile.isGroupEmpty(group: group) {
            return false
        }

        if group.attributes.contains(.away) {
            return false
        }

        return true
    }

    private func shouldDisplayAttribute(_ attribute: ProfileAttribute) -> Bool {
        return profile[attribute] != nil && profile[attribute]!.isNotEmpty
    }
}

struct InfoButton: View {
    let text: String

    @State private var isShowingPopover = false

    var body: some View {
        Button {
            isShowingPopover = true
        } label: {
            Image(.info)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingPopover) {
            Text(text).padding()
                .foregroundStyle(.primary)
#if canImport(UIKit)
                .multilineTextAlignment(.leading)
                .frame(width: 300)
                .presentationCompactAdaptation(.popover)
#endif
        }
    }
}

#Preview("editable") {
    ProfileAttributesView(
        profile: .constant(.makeFake()),
        
        receiveBroadcasts: Binding<Bool>(
            get: {
                true
            },
            set: { _ in }
        ),
    )
}

#Preview("not editable") {
    #if os(macOS)
    ProfileAttributesView(
        profile: .constant(.makeFake(awayWarning: "Away")),
        receiveBroadcasts: .constant(false),
    )
    .frame(width: 320, height: 500)
    #else
    ProfileAttributesView(
        profile: .constant(.makeFake(awayWarning: "Away")),
        receiveBroadcasts: .constant(false),
    )
    #endif
}

private struct VerticalLabeledContentStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading) {
            HStack(alignment: .firstTextBaseline) {
                configuration.label
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            configuration.content
        }
    }
}
