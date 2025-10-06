//
//  MessageViewHolder.swift
//  OpenEmail
//
//  Created by Antony Akimchenko on 15.09.25.
//
import SwiftUI
import OpenEmailCore
import OpenEmailModel
import MarkdownUI

struct MessageViewHolder: View {
    let viewModel: MessageThreadViewModel
    
    let subject: String
    let authoredOn: String
    let authorAddress: String
    let messageBody: String
    let attachments: [Attachment]?
    
    var body: some View {
        VStack(alignment: .leading, spacing: .Spacing.large) {
            MessageHeader(
                subject: subject,
                authoredOn: authoredOn,
                authorAddress: authorAddress
            )
            
            RoundedRectangle(cornerRadius: .CornerRadii.default)
                .frame(height: 1)
                .foregroundColor(.actionButtonOutline)
                .frame(maxWidth: .infinity)
            
            MessageBody(messageBody: messageBody)
            
            if attachments != nil && attachments?.isNotEmpty == true {
                AttachmentsListView(attachments!)
            }
        }
        .padding(.all, .Spacing.default)
        .clipShape(RoundedRectangle(cornerRadius: .CornerRadii.default))
        .overlay(
            RoundedRectangle(cornerRadius: .CornerRadii.default)
                .stroke(.actionButtonOutline, lineWidth: 1)
        )
    }
}

struct MessageBody: View {
    let messageBody: String
    
    var body: some View {
        Markdown(messageBody)
            .markdownTheme(.basic.blockquote { configuration in
                let rawMarkdown = configuration.content.renderMarkdown()
                
                let maxDepth = rawMarkdown
                    .components(separatedBy: "\n")
                    .map { line -> Int in
                        var level = 0
                        for char in line {
                            if char == " " {
                                continue
                            }
                            if (char != ">") {
                                break
                            } else {
                                level += 1
                            }
                        }
                        return level
                    }.max() ?? 0
                
                let depth = max(maxDepth, 1)
                
                let barColor: Color = if depth % 3 == 0 {
                    .red
                } else if depth % 2 == 0 {
                    .green
                } else {
                    .accent
                }
                
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(barColor)
                        .relativeFrame(width: .em(0.2))
                    
                    configuration.label
                        .relativePadding(.horizontal, length: .em(1))
                }
                .fixedSize(horizontal: false, vertical: true)
            })
            .textSelection(.enabled)
    }
}

struct MessageHeader: View {
    @Injected(\.client) var client: Client
    @Environment(NavigationState.self) private var navigationState
    @State var author: Profile?
    @State var readers: [Profile] = []
    
    let subject: String
    let authoredOn: String
    let authorAddress: String
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: .Spacing.xSmall) {
                Text(subject)
                    .font(.title3)
                    .textSelection(.enabled)
                    .bold()
                
                Spacer()
                
                Text(authoredOn)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
            
            HStack(spacing: .Spacing.xxSmall) {
                ProfileImageView(emailAddress: authorAddress, size: .medium)
                
                VStack(alignment: .leading, spacing: .Spacing.xxSmall) {
                    if let author = author {
                        ProfileTagView(
                            profile: author,
                            isSelected: false,
                            automaticallyShowProfileIfNotInContacts: false,
                            canRemoveReader: false,
                            showsActionButtons: true,
                        ).id(author.address)
                    }
                }
            }
        }
        .task {
            if let address = EmailAddress(authorAddress) {
                author = try? await client.fetchProfile(address: address, force: false)
            }
        }
    }
}
