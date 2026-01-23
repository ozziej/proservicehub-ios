//
//  SessionErrorHandling.swift
//  Pro Service Hub
//
//  Created by Codex.
//

import Foundation

@MainActor
extension AppSession {
    func handleUnauthorized(_ error: Error) -> Bool {
        if case APIError.unauthorized = error {
            clear()
            return true
        }
        if case APIError.serverError(let statusCode) = error, statusCode == 401 {
            clear()
            return true
        }
        return false
    }
}
