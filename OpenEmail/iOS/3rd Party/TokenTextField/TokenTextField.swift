// based on https://github.com/JayantBadlani/TokenTextField_SwiftUI

import SwiftUI

typealias TokenValidation = (_ token: String) -> Bool

protocol TokenTextFieldToken: Identifiable, Equatable, Hashable {
    var value: String { get set }
    var isSelected: Bool { get set }
    var convertedToToken: Bool { get set }
    var isValid: Bool? { get set }
    var color: Color { get }
    var displayName: String? { get }

    static func empty(isSelected: Bool) -> Self
}

struct TokenTextField<T: TokenTextFieldToken>: View {
    @Binding var tokens: [T]

    var horizontalSpacingBetweenItem: CGFloat = 4
    var verticalSpacingBetweenItem: CGFloat = 10
    var validateToken: TokenValidation?

    var onSelectToken: (T) -> Void = { _ in }
    var onTokenAdded: (T) -> Void = { _ in }

    var body: some View {
        TokenLayout(
            alignment: .leading,
            horizontalSpacingBetweenItem: horizontalSpacingBetweenItem,
            verticalSpacingBetweenItem: verticalSpacingBetweenItem
        ) {
            ForEach(tokens.indices, id: \.self) { index in
                TokenView(
                    token: $tokens[index],
                    allTokens: $tokens,
                    validateToken: validateToken,
                    onTap: onSelectToken,
                    onConvertToken: onTokenAdded
                )
                .onChange(of: tokens[index].value) { _, newValue in
                    handleTokenChange(index: index, newValue: newValue)
                }
                .id(tokens[index].id)
            }
        }
        .padding(.vertical, 4)
        .background()
        .onTapGesture {
            updateSelectedToken()
        }
        .onAppear {
            handleInitialToken()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            handleKeyboardWillHide()
        }
    }
    
    private func updateSelectedToken() {
        if !tokens.isEmpty {
            tokens.indices.forEach { index in
                if tokens[index].isSelected {
                    tokens[index].isSelected = false
                }
            }
            if !tokens[tokens.indices.last!].convertedToToken  {
                tokens[tokens.indices.last!].isSelected = true
            }
            else {
                appendEmptyToken(isSelected: true)
            }
        }
    }
    
    private func handleTokenChange(index: Int, newValue: String) {
        guard !newValue.isEmpty else {
            return
        }

        if let lastCharacter = newValue.last, ",; ".contains(lastCharacter) {
            tokens[index].value.removeLast()
            if !tokens[index].value.isEmpty {
                appendEmptyToken(isSelected: true)
            }
        }
    }
    
    private func handleInitialToken() {
        if tokens.isEmpty {
            appendEmptyToken(isSelected: false)
        }
        else if let lastToken = tokens.last, lastToken.convertedToToken {
            appendEmptyToken(isSelected: false)
        }
    }
    
    private func handleKeyboardWillHide() {
        if let lastToken = tokens.last, !lastToken.value.isEmpty {
            appendEmptyToken(isSelected: true)
        }
    }
    
    private func appendEmptyToken(isSelected: Bool) {
        DispatchQueue.main.async {
            tokens.indices.forEach { index in
                if !tokens[index].convertedToToken && !(tokens[index].value.isEmpty) {
                    tokens[index].convertedToToken = true
                }
                if tokens[index].isSelected {
                    tokens[index].isSelected = false
                }
            }
            tokens.append(T.empty(isSelected: isSelected))
        }
    }
}

private struct TokenView<T: TokenTextFieldToken>: View {
    @Binding var token: T
    @Binding var allTokens: [T]
    @FocusState private var isFocused: Bool
    @State private var isEditable: Bool = false

    var validateToken: TokenValidation?
    var onTap: (T) -> Void
    var onConvertToken: (T) -> Void

    private var backgroundColor: Color {
        if isEditable {
            return .clear
        }

        let baseColor = token.color

        if isFocused {
            return baseColor
        } else {
            return baseColor.opacity(0.2)
        }
    }

    var body: some View {
        BackSpaceListenerTextField(
            token: $token,
            onBackPressed: { handleBackspacePressed() },
            onTap: { handleTokenTap() },
            isEditable: $isEditable
        )
        .focused($isFocused)
        .padding(.vertical, 3)
        .padding(.horizontal, 5)
        .background {
            RoundedRectangle(cornerRadius: 5)
                .foregroundColor(backgroundColor)
        }
        .frame(height: 21)
        .onChange(of: isFocused) { _, newValue in
            handleFocusChange()
        }
        .onChange(of: allTokens) { _, newValue in
            handleTokenFocusChange(newValue: newValue)
        }
        .onChange(of: token.isSelected) { _, newValue in
            isEditable = !token.convertedToToken
        }
        .onChange(of: token.value) {
            token.isValid = validateToken?(token.value)
        }
        .onChange(of: token.convertedToToken) {
            if token.convertedToToken {
                onConvertToken(token)
            }
        }
        .onAppear() {
            isFocused = token.isSelected
            isEditable = !token.convertedToToken
        }
    }
    
    private func handleTokenTap() {
        allTokens.indices.forEach { allTokens[$0].isSelected = false }
        token.isSelected = true
        isFocused = token.isSelected

        if token.isSelected && token.convertedToToken {
            onTap(token)
        }
    }
    
    private func handleBackspacePressed() {
        DispatchQueue.main.async {
            if let selectedTokenIndex = allTokens.firstIndex(where: { $0.isSelected }),
               allTokens.count > 0 {
                if token.value.isEmpty || (token.isSelected && token.convertedToToken) {
                    allTokens.remove(at: selectedTokenIndex)

                    if !allTokens.isEmpty {
                        allTokens[allTokens.indices.last!].isSelected = true
                    }
                }
            }

            if allTokens.isEmpty {
                appendEmptyToken(isSelected: true)
                isEditable = true
            }
        }
    }

    private func appendEmptyToken(isSelected: Bool) {
        DispatchQueue.main.async {
            allTokens.indices.forEach { index in
                if !allTokens[index].convertedToToken && !(allTokens[index].value.isEmpty) {
                    allTokens[index].convertedToToken = true
                }
                if allTokens[index].isSelected {
                    allTokens[index].isSelected = false
                }
            }
            allTokens.append(T.empty(isSelected: isSelected))
        }
    }
    
    private func handleFocusChange() {
        token.isSelected = isFocused
        
        if allTokens.allSatisfy({ !$0.isSelected }), let lastToken = allTokens.last, lastToken.convertedToToken == true {
            appendEmptyToken(isSelected: false)
        }
        else if allTokens.allSatisfy({ !$0.isSelected }), let lastToken = allTokens.last, lastToken.convertedToToken == false, !lastToken.value.isEmpty {
            allTokens[allTokens.indices.last!].convertedToToken = true
        }
    }
    
    private func handleTokenFocusChange(newValue: [T]) {
        if newValue.last?.id == token.id && (newValue.last?.isSelected ?? false) && !isFocused {
            isFocused = true
        }
    }
}

private struct BackSpaceListenerTextField<T: TokenTextFieldToken>: UIViewRepresentable {
    @Binding var token: T
    var onBackPressed: () -> ()
    var onTap: () -> ()
    @Binding var isEditable: Bool
    @State var isFocused: Bool = false

    func makeCoordinator() -> Coordinator {
        return Coordinator(text: $token.value, isEditable: $isEditable, onBackPressed: onBackPressed, onTap: onTap)
    }

    func makeUIView(context: Context) -> CustomTextField {
        let textField = CustomTextField()
        textField.delegate = context.coordinator
        textField.onBackPressed = onBackPressed
        textField.keyboardType = .emailAddress
        textField.placeholder = "     "
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.backgroundColor = .clear
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textChange(textField:)), for: .editingChanged)
        return textField
    }
    
    func updateUIView(_ uiView: CustomTextField, context: Context) {
        if (uiView.text?.count ?? 0) > 0 {
            uiView.placeholder = ""
        }
        else {
            uiView.placeholder = "     " // to initially give width to textfield
        }

        let text = token.displayName ?? token.value

        if !isEditable {
            uiView.text = text
            uiView.tintColor = token.isSelected ? .clear : .tintColor
            uiView.textColor = token.isSelected ? .white : .black
        } else {
            uiView.text = text
            uiView.tintColor = .tintColor
            uiView.textColor = .black
        }
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: CustomTextField, context: Context) -> CGSize? {
        return uiView.intrinsicContentSize
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        @Binding var isEditable: Bool
        var onBackPressed: () -> ()
        var onTap: () -> ()

        init(text: Binding<String>, isEditable: Binding<Bool>, onBackPressed: @escaping () -> (), onTap: @escaping () -> ()) {
            self._text = text
            self._isEditable = isEditable
            self.onBackPressed = onBackPressed
            self.onTap = onTap
        }

        @objc func textChange(textField: UITextField) {
            DispatchQueue.main.async { [weak self] in
                self?.text = textField.text ?? ""
            }
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            if !isEditable {
                if string.isEmpty {
                    onBackPressed()
                    return false
                } else {
                    return false
                }
            }
            return true
        }

        func textField(_ textField: UITextField, editMenuForCharactersIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
            onTap()
            return UIMenu()
        }
    }
    
    class CustomTextField: UITextField {
        open var onBackPressed: (() -> ())?
        var canEdit: Bool = true

        override func deleteBackward() {
            if canEdit {
                super.deleteBackward()
                onBackPressed?()
            } else {
                // Handle deletion of the entire token
                onBackPressed?()
            }
        }
        
        override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
            return false
        }
    }
}
