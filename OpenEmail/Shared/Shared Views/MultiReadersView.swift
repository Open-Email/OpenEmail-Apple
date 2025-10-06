//
//  MultiReadersView.swift
//  OpenEmail
//
//  Created by Antony Akimchenko on 12.08.25.
//

import SwiftUI
import OpenEmailModel
import OpenEmailCore
import Flow

struct MultiReadersView: View {
    
    let readers: [String]
    @State var expanded: Bool = false
    @State var selectedPopoverProfile: Profile? = nil
    @Injected(\.client) private var client
    
    var body: some View {
        HFlow(
            itemSpacing: expanded ? .Spacing.xSmall : (
                -ProfileImageSize.small.size / 2.0
            ),
            rowSpacing: .Spacing.xxxSmall
        ) {
            ForEach(readers, id: \.self) { reader in
                ProfileImageView(emailAddress: reader, size: .small)
                    .onTapGesture {
                        if !expanded {
                            withAnimation(.easeOut(duration: 0.5)) {
                                expanded.toggle()
                            }
                        } else {
                            Task {
                                if let emailAddress = EmailAddress(reader) {
                                    selectedPopoverProfile = try? await client.fetchProfile(address: emailAddress, force: false)
                                }
                            }
                        }
                    }
            }
        }.popover(isPresented: Binding<Bool>(
            get: {
                selectedPopoverProfile != nil
            },
            set: {
                if !$0 {
                    selectedPopoverProfile = nil
                }
            }
        )) {
            ProfilePopover(
                profile: selectedPopoverProfile!,
                onDismiss: {
                    selectedPopoverProfile = nil
                },
                showsActionButtons: false,
                canRemoveReader: false
            )
        }
        
    }
}

#Preview {
    MultiReadersView(readers: [])
}
