import SwiftUI
import OpenEmailModel
import OpenEmailCore
import Inspect
import Utils

struct ProfileAttributesView<ActionButtonRow: View>: View {
    enum ProfileImageStyle {
        case none
        case fullWidthHeader(height: CGFloat)
        case shape(
            type: ProfileImageShapeType = .roundedRectangle(cornerRadius: .CornerRadii.default),
            size: CGFloat = 288
        )

        var shouldIgnoreSafeArea: Bool {
            switch self {
            case .fullWidthHeader: true
            default: false
            }
        }
    }

    @Binding private var profile: Profile
    private let receiveBroadcasts: Binding<Bool>?
    private let hidesEmptyFields: Bool
    private let profileImageStyle: ProfileImageStyle
    @ViewBuilder private var actionButtonRow: () -> ActionButtonRow

    init(
        profile: Binding<Profile>,
        receiveBroadcasts: Binding<Bool>?,
        hidesEmptyFields: Bool = false,
        profileImageStyle: ProfileImageStyle,
        actionButtonRow: @escaping () -> ActionButtonRow = { EmptyView() }
    ) {
        _profile = profile
        self.receiveBroadcasts = receiveBroadcasts
        self.hidesEmptyFields = hidesEmptyFields
        self.profileImageStyle = profileImageStyle
        self.actionButtonRow = actionButtonRow
    }

#if canImport(UIKit)
    private let labeledContentStyle = VerticalLabeledContentStyle()
#else
    private let labeledContentStyle = AutomaticLabeledContentStyle()
#endif

    var body: some View {
        List {
            VStack(alignment: .leading) {
                Section {
                    profileImage(profile: profile)

                    // name and address
                    VStack(alignment: .leading, spacing: .Spacing.xxxSmall) {
                        awayMessage
                            .padding(.bottom, .Spacing.default)

                        if let name = profile[.name], !name.isEmpty {
                            Text(name).font(.title2)
                                .textSelection(.enabled)
                        }
                        Text(profile.address.address).font(.headline)
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                    }
                    .listRowSeparator(.hidden)
                }

                // broadcasts
                if let receiveBroadcasts {
                    Section {
                        VStack(alignment: .leading, spacing: .Spacing.small) {
                            Divider()
                            Toggle(isOn: receiveBroadcasts) {
                                HStack(spacing: .Spacing.xSmall) {
                                    Image(.scopeBroadcasts)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 16, height: 16)
                                    Text("Broadcast")
                                }
                            }
                            .toggleStyle(.switch)
                            .tint(.accentColor)
                            Divider()
                        }
                        .padding(.vertical, .Spacing.xxxSmall)
                        #if os(macOS)
                        .listRowInsets(.init())
                        #endif
                        .listRowSeparator(.hidden)
                    }
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
            }.padding(EdgeInsets(
                top: .Spacing.default,
                leading: 0,
                bottom: .Spacing.default,
                trailing: .Spacing.default,
            ))
        }
#if os(macOS)
        .inspect { tableView in
            tableView.floatsGroupRows = false
        }
#endif
        .listStyle(.plain)
#if os(iOS)
        .if(profileImageStyle.shouldIgnoreSafeArea) {
            $0.ignoresSafeArea(.container, edges: .top)
        }
#endif
        .scrollContentBackground(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }

    @ViewBuilder
    private func profileImage(profile: Profile) -> some View {
        switch profileImageStyle {
        case .none:
            EmptyView()
        case .fullWidthHeader(_):
            ProfileImageView(
                emailAddress: profile.address.address,
                shape: .rectangle,
                size: .large
            )
            .background(.accent.gradient)
#if os(iOS)
            // account for additional padding
            .padding(.horizontal, -20)
            .padding(.top, -11)
            .overlay(alignment: .bottom) {
                actionButtonRow()
                    .padding(.vertical, .Spacing.default)
            }
#endif

        case let .shape(type, _):
            ProfileImageView(
                emailAddress: profile.address.address,
                shape: type,
                size: .large
            )
        }
    }

    @ViewBuilder
    private func component(for attribute: ProfileAttribute) -> some View {
        switch attribute.attributeType {
        case .text(let multiline): textField(for: attribute, isMultiline: multiline)
        case .boolean:
            booleanSign(for: attribute, defaultValue: attribute != .away)
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

    // MARK: - Bindings

    private func toggleBinding(for attribute: ProfileAttribute, defaultValue: Bool) -> Binding<Bool> {
        return Binding<Bool>(
            get: {
                return profile[boolean: attribute] ?? defaultValue
            },
            set: {
                profile[boolean: attribute] = $0
            })
    }

    private func stringBinding(for attribute: ProfileAttribute) -> Binding<String> {
        return Binding(
            get: {
                return profile[attribute] ?? ""
            },
            set: {
                profile[attribute] = $0.isEmpty ? nil : $0
            })
    }

    private func dateStringBinding(for attribute: ProfileAttribute, isRelative: Bool) -> Binding<String> {
        return Binding(
            get: {
                dateString(for: attribute, isRelative: isRelative)
            },
            set: { _ in
                // do nothing
            })
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

    private func booleanSign(for attribute: ProfileAttribute, defaultValue: Bool) -> some View {
        LabeledContent {
            let value = profile[boolean: attribute] ?? defaultValue
            Image(systemName: value ? "checkmark" : "xmark")
                .foregroundStyle(.accent)
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

    private func shouldDisplayGroup(_ group: ProfileAttributesGroup) -> Bool {

        if profile.isGroupEmpty(group: group) {
            return !hidesEmptyFields
        }

        if group.attributes.contains(.away) {
            return false
        }

        return true
    }

    private func shouldDisplayAttribute(_ attribute: ProfileAttribute) -> Bool {

        return (
            profile[attribute] != nil && profile[attribute]!.isNotEmpty
        ) || !hidesEmptyFields
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
        receiveBroadcasts: nil,
        profileImageStyle: .none
    )
}

#Preview("not editable") {
    #if os(macOS)
    ProfileAttributesView(
        profile: .constant(.makeFake(awayWarning: "Away")),
        receiveBroadcasts: .constant(false),
        hidesEmptyFields: true,
        profileImageStyle: .shape(),
    )
    .frame(width: 320, height: 500)
    #else
    ProfileAttributesView(
        profile: .constant(.makeFake(awayWarning: "Away")),
        receiveBroadcasts: .constant(false),
        hidesEmptyFields: true,
        profileImageStyle: .fullWidthHeader(height: 500),
        actionButtonRow: {
            HStack {
                ProfileActionButton(title: "Refresh", icon: .refresh, action: {})
                ProfileActionButton(title: "Fetch", icon: .downloadMessages, action: {})
                ProfileActionButton(title: "Message", icon: .compose, action: {})
                ProfileActionButton(title: "Delete", icon: .delete, role: .destructive, action: {})
            }
        }
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
