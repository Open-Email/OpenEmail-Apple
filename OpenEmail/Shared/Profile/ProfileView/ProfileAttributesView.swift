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

    @Binding private var profile: Profile?
    private let receiveBroadcasts: Binding<Bool>?
    private let isEditable: Bool
    private let hidesEmptyFields: Bool
    private let profileImageStyle: ProfileImageStyle
    @ViewBuilder private var actionButtonRow: () -> ActionButtonRow

    init(
        profile: Binding<Profile?>,
        receiveBroadcasts: Binding<Bool>?,
        isEditable: Bool,
        hidesEmptyFields: Bool = false,
        profileImageStyle: ProfileImageStyle,
        actionButtonRow: @escaping () -> ActionButtonRow = { EmptyView() }
    ) {
        _profile = profile
        self.receiveBroadcasts = receiveBroadcasts
        self.isEditable = isEditable
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
        if let profile {
            List {
                Section {
                    profileImage(profile: profile)

                    // name and address
                    VStack(alignment: .leading, spacing: .Spacing.xxxSmall) {
                        awayMessage
                            .padding(.bottom, .Spacing.default)

                        if let name = profile[.name], !name.isEmpty {
                            Text(name).font(.title)
                                .textSelection(.enabled)
                        }
                        Text(profile.address.address).font(.title2)
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, .Spacing.xSmall)
                    .listRowSeparator(.hidden)
                }

                // broadcasts
                if let receiveBroadcasts {
                    Section {
                        VStack(alignment: .leading, spacing: .Spacing.default) {
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

                ForEach(profile.groupedAttributes) { group in
                    if shouldDisplayGroup(group) {
                        Section {
                            ForEach(group.attributes, id: \.self) { attribute in
                                if shouldDisplayAttribute(attribute) {
                                    component(for: attribute)
                                        .listRowSeparator(.hidden)
                                }
                            }
                        } header: {
                            Text(group.groupType.displayName)
                                .font(.title2)
                                .foregroundStyle(.primary)
                                .padding(.top, .Spacing.xSmall)
                        }
                    }
                }
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
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func profileImage(profile: Profile) -> some View {
        switch profileImageStyle {
        case .none:
            EmptyView()
        case .fullWidthHeader(let height):
            ProfileImageView(
                emailAddress: profile.address.address,
                shape: .rectangle,
                size: height,
                placeholder: {
                    Text($0)
                        .foregroundStyle(.white)
                        .font(.system(size: 30))
                        .fontWeight(.semibold)
                }
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

        case let .shape(type, size):
            ProfileImageView(
                emailAddress: profile.address.address,
                shape: type,
                size: size
            )
            .padding(.top, -.Spacing.xxxSmall)
            .padding(.bottom, .Spacing.default)
        }
    }

    @ViewBuilder
    private func component(for attribute: ProfileAttribute) -> some View {
        switch attribute.attributeType {
        case .text(let multiline): textField(for: attribute, isMultiline: multiline)
        case .boolean:
            if isEditable {
                toggleField(for: attribute, defaultValue: attribute != .away)
            } else {
                booleanSign(for: attribute, defaultValue: attribute != .away)
            }
        case .date(let relative):
            if isEditable {
                // TODO: add date picker if we ever have an editable date
                textField(for: attribute)
            } else {
                dateTextField(for: attribute, isRelative: relative)
            }
        }
    }

    private func textField(for attribute: ProfileAttribute, isMultiline: Bool = false) -> some View {
        LabeledContent {
            if isEditable {
                TextField("", text: stringBinding(for: attribute), prompt: nil, axis: isMultiline ? .vertical : .horizontal)
                    .background()
            } else {
                Text(profile?[attribute] ?? "")
                    .textSelection(.enabled)
                    .foregroundStyle(.primary)
            }
        } label: {
            HStack(spacing: .Spacing.xSmall) {
                if let info = attribute.info {
                    InfoButton(text: info)
                }

                Text("\(attribute.displayTitle):")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func dateTextField(for attribute: ProfileAttribute, isRelative: Bool) -> some View {
        LabeledContent {
            if isEditable {
                TextField("", text: dateStringBinding(for: attribute, isRelative: isRelative), prompt: nil)
            } else {
                Text(dateString(for: attribute, isRelative: isRelative))
                    .foregroundStyle(.primary)
            }
        } label: {
            HStack(spacing: .Spacing.xSmall) {
                if let info = attribute.info {
                    InfoButton(text: info)
                }

                Text("\(attribute.displayTitle):")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func toggleField(for attribute: ProfileAttribute, defaultValue: Bool = true) -> some View {
        LabeledContent {
            Toggle("", isOn: toggleBinding(for: attribute, defaultValue: defaultValue))
                .toggleStyle(.switch)
                .disabled(!isEditable)
        } label: {
            HStack(spacing: .Spacing.xSmall) {
                if let info = attribute.info {
                    InfoButton(text: info)
                }

                Text("\(attribute.displayTitle):")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var awayMessage: some View {
        if profile?[boolean: .away] == true {
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
                            .foregroundStyle(.themeBlue)
                    }

                if let awayWarning = profile?[.awayWarning] {
                    Text(awayWarning)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, .Spacing.xSmall)
            .padding(.horizontal, .Spacing.xSmall)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: .CornerRadii.default)
                    .fill(.themeBackground)
            }
        }
    }

    // MARK: - Bindings

    private func toggleBinding(for attribute: ProfileAttribute, defaultValue: Bool) -> Binding<Bool> {
        Binding<Bool>(
            get: {
                return profile?[boolean: attribute] ?? defaultValue
            },
            set: {
                profile?[boolean: attribute] = $0
            })
    }

    private func stringBinding(for attribute: ProfileAttribute) -> Binding<String> {
        return Binding(
            get: {
                return profile?[attribute] ?? ""
            },
            set: {
                profile?[attribute] = $0.isEmpty ? nil : $0
            })
    }

    private func dateBinding(for attribute: ProfileAttribute) -> Binding<Date?> {
        return Binding(
            get: {
                if let dateString = profile?[attribute] {
                    return parseISO8601Date(dateString)
                } else {
                    return nil
                }
            },
            set: {
                if let date = $0 {
                    let dateString = ISO8601DateFormatter.backendDateFormatter.string(from: date)
                    profile?[attribute] = dateString
                } else {
                    profile?[attribute] = nil
                }
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
            let dateString = profile?[attribute],
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
            let value = profile?[boolean: attribute] ?? defaultValue
            Image(systemName: value ? "checkmark" : "xmark")
                .foregroundStyle(.themeBlue)
        } label: {
            HStack(spacing: .Spacing.xSmall) {
                if let info = attribute.info {
                    InfoButton(text: info)
                }

                Text("\(attribute.displayTitle):")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func shouldDisplayGroup(_ group: ProfileAttributesGroup) -> Bool {
        guard let profile else { return false }

        if profile.isGroupEmpty(group: group) {
            return !hidesEmptyFields
        }

        if group.attributes.contains(.away) {
            return false
        }

        return true
    }

    private func shouldDisplayAttribute(_ attribute: ProfileAttribute) -> Bool {
        guard let profile else { return false }

        if attribute == .lastSeen {
            return !isEditable
        }

        return profile[attribute] != nil || !hidesEmptyFields
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
        isEditable: true,
        profileImageStyle: .none
    )
}

#Preview("not editable") {
    #if os(macOS)
    ProfileAttributesView(
        profile: .constant(.makeFake(awayWarning: "Away")),
        receiveBroadcasts: .constant(false),
        isEditable: false,
        hidesEmptyFields: true,
        profileImageStyle: .shape()
    )
    .frame(width: 320, height: 500)
    #else
    ProfileAttributesView(
        profile: .constant(.makeFake(awayWarning: "Away")),
        receiveBroadcasts: .constant(false),
        isEditable: false,
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
