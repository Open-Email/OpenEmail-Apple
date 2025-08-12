//
//  MultiReadersView.swift
//  OpenEmail
//
//  Created by Antony Akimchenko on 12.08.25.
//

import SwiftUI
import OpenEmailModel
import Flow

struct MultiReadersView: View {
    
    let readers: [String]
    
    var body: some View {
        HFlow(
            itemSpacing: -ProfileImageSize.small.size / 2.0,
            rowSpacing: .Spacing.xxxSmall
        ) {
            ForEach(readers, id: \.self) { reader in
                ProfileImageView(emailAddress: reader, size: .small)
            }
        }
    }
}

#Preview {
    MultiReadersView(readers: [])
}
