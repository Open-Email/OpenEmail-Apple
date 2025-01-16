import SwiftUI
import Flow
import OpenEmailCore
import OpenEmailPersistence
import OpenEmailModel
import AppKit

@MainActor
struct ReadersView: View {
    enum ShowProfileType {
        case callback(onShowProfile: (String) -> Void)
        case popover

        fileprivate var onShowProfile: ((String) -> Void)? {
            switch self {
            case .callback(let onShowProfile):
                return onShowProfile
            case .popover:
                return nil
            }
        }
    }

    private static let zeroWidthSpace = "\u{200B}"

    private let isEditable: Bool
    @Binding private var readers: [EmailAddress]
    @Binding private var tickedReaders: [String]
    @Binding private var hasInvalidReader: Bool

    private let prefixLabel: String?
    @State private var inputText = zeroWidthSpace
    @State private var didFixCursorPositionAfterFocus: Bool = false
    @State private var inputEditingPosition: Int = 0
    @State private var selectedReaderIndexes: Set<Int> = []
    @State private var selectionCursor = -1
    @State private var selectionStartIndex = -1
    @State private var showAlreadyAddedAlert = false

    @State private var showSuggestions = false
    @State private var showLegacySuggestions = false
    @State private var allContacts: [Contact] = []
    @State private var suggestions: [Contact] = []

    @FocusState private var isInputFocused: Bool
    @FocusState private var isFocused: Bool

    // store which profiles have been shown to not show them again automatically
    @State private var profilesShown = Set<EmailAddress>()

    @Injected(\.contactsStore) private var contactsStore: ContactStoring
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?

    private let showProfileType: ShowProfileType

    init(
        isEditable: Bool,
        readers: Binding<[EmailAddress]>,
        tickedReaders: Binding<[String]>,
        hasInvalidReader: Binding<Bool>,
        prefixLabel: String?,
        showProfileType: ShowProfileType
    ) {
        self.isEditable = isEditable
        _readers = readers
        _tickedReaders = tickedReaders
        _hasInvalidReader = hasInvalidReader
        self.prefixLabel = prefixLabel
        self.showProfileType = showProfileType
    }

    var body: some View {
        // TODO: only display first 10 readers with option to expand to see all
        HFlow(itemSpacing: 4, rowSpacing: 2) {
            if let prefixLabel {
                Text(prefixLabel)
            }

            ForEach(Array(readers.enumerated()), id: \.offset) {
                index,
                reader in
                // don't show reader if it is myself, except when I am the only reader or when composing a message
                if reader.address != registeredEmailAddress || readers.count == 1 || isEditable {
                    ProfileTagView(
                        emailAddress: .constant(reader.address),
                        isSelected: selectedReaderIndexes.contains(index),
                        isTicked: tickedReaders.contains(reader.address),
                        configuration: .init(
                            automaticallyShowProfileIfNotInContacts: isEditable && !profilesShown.contains(reader),
                            canRemoveReader: isEditable,
                            showsActionButtons: !isEditable,
                            onShowProfile: showProfileType.onShowProfile
                        ),
                        onRemoveReader: {
                            readers.remove(at: index)
                            workaround_setReaders(readers)
                        }
                    )
                }
            }

            if isEditable {
                /*
                 The TextField's first character is an invisible space which helps with a more natural
                 editing experience. E.g. when deleting the current input with backspace and the invisible space
                 is deleted, we can load the previous tag's text into the TextField and continue editing there.
                 */

                TextField("", text: $inputText)
                    .focused($isInputFocused)
                    .textFieldStyle(.plain)
                    .frame(minWidth: 20)
                    .fixedSize() // This causes some visual glitches while typing. It is most probably a SwiftUI bug.
                    .modify { view in
                        if #available(macOS 15.0, *) {
                            view.textInputSuggestions {
                                ForEach(suggestions) { suggestion in
                                    Label {
                                        Text(suggestion.cachedName ?? suggestion.address)
                                            .padding(.Spacing.xSmall)
                                    } icon: {
                                        ProfileImageView(
                                            emailAddress: suggestion.address,
                                            name: suggestion.cachedName,
                                            size: 30
                                        )
                                    }
                                    .textInputCompletion(suggestion.address)
                                }
                            }
                        }
                    }
                    .onChange(of: inputText) {
                        if !readers.isEmpty && inputText.isEmpty {
                            let last = readers.removeLast()
                            inputText = ReadersView.zeroWidthSpace + last.address
                        }

                        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                        hasInvalidReader = !trimmed.isEmpty && !EmailAddress.isValid(trimmed)

                        updateSuggestions()

                        if #available(macOS 15.0, *) {
                            showSuggestions = inputText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 && !suggestions.isEmpty
                        } else {
                            showLegacySuggestions = inputText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 && !suggestions.isEmpty
                        }
                    }
                    .onSubmit {
                        addCurrentInput()
                    }
                    .onChange(of: isInputFocused) {
                        if !isInputFocused {
                            addCurrentInput()
                            didFixCursorPositionAfterFocus = false
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: NSTextView.didChangeSelectionNotification)) {
                        guard let textView = $0.object as? NSTextView else { return }
                        DispatchQueue.main.async {
                            guard isInputFocused else { return }

                            // delay fixing cursor position because isInputFocused is only set after this notification
                            fixInitialCursorPositionIfNeeded(textView: textView)

                            fixSelection(textView: textView)

                            inputEditingPosition = textView.selectedRange().location
                        }
                    }
                    .popover(isPresented: $showLegacySuggestions, attachmentAnchor: .point(.bottomLeading), arrowEdge: .bottom) {
                        ContactSuggestionsView(suggestions: suggestions) { suggestion in
                            inputText = suggestion.address
                            addCurrentInput()
                            showLegacySuggestions = false
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress(keys: [.space, ","]) { _ in 
            guard isEditable else { return .ignored }
            addCurrentInput()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            guard isEditable else { return .ignored }

            if isInputFocused {
                if inputEditingPosition == 1 && !readers.isEmpty {
                    selectedReaderIndexes = [readers.count - 1]
                    selectionCursor = readers.count - 1
                    selectionStartIndex = selectionCursor
                    isFocused = true
                    return .handled
                }
            } else {
                if selectLeftReader(addingToSelection: CGKeyCode.kVK_Shift.isPressed) {
                    return .handled
                } else {
                    return .ignored
                }
            }

            return .ignored
        }
        .onKeyPress(.rightArrow) {
            guard isEditable else { return .ignored }

            if !isInputFocused {
                if selectRightReader(addingToSelection: CGKeyCode.kVK_Shift.isPressed) {
                    return .handled
                } else {
                    isInputFocused = true
                    selectionCursor = -1
                    selectedReaderIndexes = []
                    return .handled
                }
            }

            return .ignored
        }
        .onKeyPress(keys: [.delete, .deleteForward, .init("\u{7F}")]) { _ in
            guard
                isEditable,
                isFocused,
                !isInputFocused,
                selectionCursor != -1
            else {
                return .ignored
            }

            var newReaders = readers

            let sortedIndexes = selectedReaderIndexes.sorted(by: >)
            for index in sortedIndexes {
                if index < newReaders.count {
                    newReaders.remove(at: index)
                }
            }

            workaround_setReaders(newReaders)

            selectedReaderIndexes = []
            selectionCursor = -1
            isInputFocused = true

            return .handled
        }
        .onHover { isHovering in
            guard isEditable else { return }

            DispatchQueue.main.async {
                if isHovering {
                    NSCursor.iBeam.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
        .onTapGesture{
            guard isEditable else { return }
            isInputFocused = true
        }
        .alert("Reader already added", isPresented: $showAlreadyAddedAlert) {}
        .onAppear {
            Task {
                allContacts = (try? await contactsStore.allContacts()) ?? []
                updateSuggestions()
            }
        }
    }

    // workaround for view color not updating correctly after removing a reader
    private func workaround_setReaders(_ newReaders: [EmailAddress]) {
        readers = []
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            readers = newReaders
        }
    }

    private func addCurrentInput() {
        showLegacySuggestions = false

        let address = inputText.trimmingCharacters(in: .whitespacesAndNewlines)

        if let emailAddress = EmailAddress(address) {
            if readers.contains(emailAddress) {
                showAlreadyAddedAlert = true
            } else {
                readers.append(emailAddress)
                inputText = ReadersView.zeroWidthSpace
            }
        } else {
            #if canImport(AppKit)
            if !address.isEmpty {
                NSSound.beep()
            }
            #endif
        }
    }

    private func fixInitialCursorPositionIfNeeded(textView: NSTextView) {
        guard isInputFocused, !didFixCursorPositionAfterFocus else { return }

        // Deselect all text when TextField gets focused. This will also move the cursor to the end.
        let range = NSRange(location: textView.string.count, length: 0)
        if textView.selectedRange() != range {
            textView.setSelectedRange(range)
            didFixCursorPositionAfterFocus = true
        }
    }

    private func fixSelection(textView: NSTextView) {
        guard isInputFocused else { return }

        var selectedRange = textView.selectedRange()
        // don't let the user select the invisible space prefix
        if selectedRange.location == 0 && textView.string.first == ReadersView.zeroWidthSpace.first {
            selectedRange.location = 1
            selectedRange.length = max(selectedRange.length - 1, 0)
            textView.setSelectedRange(selectedRange)
        }
    }

    private func selectLeftReader(addingToSelection: Bool) -> Bool {
        let newSelectionCursor = selectionCursor - 1
        if newSelectionCursor < 0 {
            // select first reader when pressing left arrow while at the left edge
            if selectedReaderIndexes.contains(0) && !addingToSelection {
                selectedReaderIndexes = [0]
            }
            return false
        }

        selectionCursor = newSelectionCursor
        if addingToSelection {
            selectedReaderIndexes.insert(newSelectionCursor)
            if newSelectionCursor >= selectionStartIndex {
                // deselect all items to the right of the cursor
                selectedReaderIndexes = selectedReaderIndexes.filter { $0 <= newSelectionCursor }
            }
        } else {
            selectedReaderIndexes = [newSelectionCursor]
            selectionStartIndex = selectionCursor
        }

        return true
    }

    private func selectRightReader(addingToSelection: Bool) -> Bool {
        let newSelectionCursor = selectionCursor + 1
        if newSelectionCursor >= readers.count {
            return false
        }

        selectionCursor = newSelectionCursor
        if addingToSelection {
            selectedReaderIndexes.insert(newSelectionCursor)
            if newSelectionCursor <= selectionStartIndex {
                // deselect all items to the left of the cursor
                selectedReaderIndexes = selectedReaderIndexes.filter { $0 >= newSelectionCursor }
            }
        } else {
            selectedReaderIndexes = [newSelectionCursor]
            selectionStartIndex = selectionCursor
        }

        return true
    }

    private func updateSuggestions() {
        let searchString = inputText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !searchString.isEmpty else {
            suggestions = []
            return
        }

        suggestions = allContacts.filter { contact in
            contact.address.localizedStandardContains(searchString) || (contact.cachedName ?? "").localizedStandardContains(searchString)
        }
    }
}

#Preview("1 reader") {
    VStack(alignment: .leading) {
        ReadersView(isEditable: false, readers: .constant([EmailAddress("mickey.mouse@disneymail.com")].compactMap { $0 }), tickedReaders: .constant([]), hasInvalidReader: .constant(false), prefixLabel: nil, showProfileType: .popover)
    }
    .padding()
    .frame(width: 500)
    .background(.themeViewBackground)
}

#Preview("10 readers") {
    VStack(alignment: .leading) {
        ReadersView(
            isEditable: false,
            readers: .constant([
                EmailAddress("mickey.mouse@disneymail.com"),
                EmailAddress("minnie.mouse@magicmail.com"),
                EmailAddress("donald.duck@quackmail.com"),
                EmailAddress("daisy.duck@flowerpowermail.com"),
                EmailAddress("goofy.goof@laughtermail.com"),
                EmailAddress("pluto.pup@starstruckmail.com"),
                EmailAddress("cinderella.princess@fairytalemail.com"),
                EmailAddress("buzz.lightyear@toinfinitymail.com"),
                EmailAddress("ariel.mermaid@undertheseamail.com"),
                EmailAddress("simba.lionking@savannahmail.com"),
            ].compactMap { $0 }),
            tickedReaders: .constant([
                "mickey.mouse@disneymail.com",
                "minnie.mouse@magicmail.com"
            ].compactMap { $0 }),
            hasInvalidReader: .constant(false),
            prefixLabel: nil,
            showProfileType: .popover)
    }
    .padding()
    .frame(width: 500)
    .background(.themeViewBackground)
}

#Preview("20 readers") {
    VStack(alignment: .leading) {
        ReadersView(
            isEditable: false,
            readers: .constant([
                EmailAddress("mickey.mouse@disneymail.com"),
                EmailAddress("minnie.mouse@magicmail.com"),
                EmailAddress("donald.duck@quackmail.com"),
                EmailAddress("daisy.duck@flowerpowermail.com"),
                EmailAddress("goofy.goof@laughtermail.com"),
                EmailAddress("pluto.pup@starstruckmail.com"),
                EmailAddress("cinderella.princess@fairytalemail.com"),
                EmailAddress("buzz.lightyear@toinfinitymail.com"),
                EmailAddress("ariel.mermaid@undertheseamail.com"),
                EmailAddress("simba.lionking@savannahmail.com"),
                EmailAddress("woody.cowboy@toystorymail.com"),
                EmailAddress("jessie.cowgirl@yeehawmail.com"),
                EmailAddress("aladdin.streetrat@agrabahmail.com"),
                EmailAddress("jasmine.princess@palacemail.com"),
                EmailAddress("pocahontas.naturelover@windmail.com"),
                EmailAddress("mulan.warrior@honoratemail.com"),
                EmailAddress("frozen.anna@snowqueenmail.com"),
                EmailAddress("elsa.icequeen@frozenmail.com"),
                EmailAddress("rapunzel.longhair@towermail.com"),
                EmailAddress("genie.freewisher@magiclampmail.com"),
            ].compactMap { $0 }),
            tickedReaders: .constant([
                "mickey.mouse@disneymail.com",
                "minnie.mouse@magicmail.com"
            ].compactMap { $0 }),
            hasInvalidReader: .constant(false),
            prefixLabel: nil,
            showProfileType: .popover)
    }
    .padding()
    .frame(width: 500)
    .background(.themeViewBackground)
}


public extension View {
    @ViewBuilder
    func modify(@ViewBuilder _ transform: (Self) -> (some View)?) -> some View {
        if let view = transform(self), !(view is EmptyView) {
            view
        } else {
            self
        }
    }
}
