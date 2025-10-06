//
//  QuickResponseView.swift
//  OpenEmail
//
//  Created by Antony Akimchenko on 20.09.25.
//
import SwiftUI
import OpenEmailCore
import OpenEmailModel
import Logging

struct QuickResponseView: View {
    
    @Binding private var viewModel: MessageThreadViewModel
    @Binding private var filePickerOpen: Bool
    @Injected(\.pendingMessageStore) private var pendingMessageStore
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?
    @Injected(\.syncService) private var syncService
    private let openComposingScreenAction: () async throws -> Void
    
    
    init(messageViewModel: Binding<MessageThreadViewModel>, filePickerOpen: Binding<Bool>, openComposingScreenAction: @escaping () async throws -> Void) {
        _viewModel = messageViewModel
        _filePickerOpen = filePickerOpen
        self.openComposingScreenAction = openComposingScreenAction
    }
    
    var body: some View {
        VStack(spacing: .zero) {
            if viewModel.attachedFileItems.isNotEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(viewModel.attachedFileItems) { attachment in
                            ZStack(
                                alignment: Alignment.topTrailing
                            ) {
                                VStack(spacing: .Spacing.xxSmall) {
                                    attachment.icon.swiftUIImage
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 48, height: 48)
                                    
                                    Text(attachment.name ?? "")
                                        .font(.footnote)
                                }
                                
                                Button {
                                    if let index = viewModel.attachedFileItems
                                        .firstIndex(where: { $0.id.absoluteString == attachment.id.absoluteString }) {
                                        viewModel.attachedFileItems.remove(at: index)
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                    
                                }.buttonStyle(.borderless)
                            }
                        }
                    }.padding(.horizontal, .Spacing.xxSmall)
                }.padding(.vertical, .Spacing.xxSmall)
            }
            
            HStack {
                TextField("Subject:", text: $viewModel.editSubject)
                    .font(.title3)
                    .textFieldStyle(.plain)
                
                AsyncButton {
                    do {
                        try await pendingMessageStore
                            .storePendingMessage(
                                PendingMessage(
                                    id: UUID().uuidString,
                                    authoredOn: Date(),
                                    readers: viewModel.messageThread?.readers
                                        .filter { $0 != registeredEmailAddress } ?? [],
                                    draftAttachmentUrls: viewModel.attachedFileItems.map { $0.url },
                                    subject: viewModel.editSubject.trimmingCharacters(in: .whitespacesAndNewlines),
                                    subjectId: viewModel.messageThread?.subjectId ?? "",
                                    body: viewModel.editBody.trimmingCharacters(in: .whitespacesAndNewlines),
                                    isBroadcast: false
                                )
                            )
                    } catch {
                        Log.error("Could not save pending message")
                    }
                    
                    viewModel.clear()
                    
                    Task.detached(priority: .userInitiated) {
                        await syncService.synchronize()
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                }.buttonStyle(.borderless)
                    .foregroundColor(.accentColor)
                    .disabled(
                        viewModel.editSubject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        viewModel.editBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
            }.padding(.horizontal, .Spacing.xSmall)
                .padding(.vertical, .Spacing.xxSmall)
            
            RoundedRectangle(cornerRadius: .CornerRadii.default)
                .frame(height: 1)
            
                .foregroundColor(.actionButtonOutline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, .Spacing.xSmall)
            
            HStack {
                TextField("Body:", text: $viewModel.editBody, axis: .vertical)
                    .font(.body)
                    .lineLimit(nil)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.leading)
                
                AsyncButton {
                    do {
                        try await openComposingScreenAction()
                    } catch {
                        Log.error("Could not open compose screen: \(error)")
                    }
                } label: {
                    Text(".md")
                }.buttonStyle(.borderless)
                
                Button {
                    filePickerOpen = true
                } label: {
                    Image(systemName: "paperclip")
                    
                }.buttonStyle(.borderless)
            }.padding(.horizontal, .Spacing.xSmall)
                .padding(.vertical, .Spacing.xxSmall)
        }
        .clipShape(RoundedRectangle(cornerRadius: .CornerRadii.default))
    }
}
