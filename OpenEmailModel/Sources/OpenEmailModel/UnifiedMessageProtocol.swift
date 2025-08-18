//
//  UnifiedMessageProtocol.swift
//  OpenEmailModel
//
//  Created by Antony Akimchenko on 18.08.25.
//

public protocol UnifiedMessage: Identifiable, Equatable, Hashable {
    var id: String { get }
}
