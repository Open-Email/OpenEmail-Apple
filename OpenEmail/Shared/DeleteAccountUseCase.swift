//
//  DeleteAccountUseCase.swift
//  OpenEmail
//
//  Created by Antony Akimchenko on 10.04.25.
//
class DeleteAccountUseCase {
    @Injected(\.client) private var client
    
    func deleteAccount() async throws {
        try await self.client.deleteCurrentUser()
        RemoveAccountUseCase().removeAccount()
    }
}
