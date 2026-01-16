//
//  AppSession.swift
//  Pro Service Hub
//
//  Created by Codex.
//

import Foundation
import Combine

@MainActor
final class AppSession: ObservableObject {
    @Published private(set) var token: String?
    @Published private(set) var user: User?

    private let tokenKey = "ProServiceHub.session.token"
    private let userKey = "ProServiceHub.session.user"

    init() {
        let defaults = UserDefaults.standard
        token = defaults.string(forKey: tokenKey)
        if let data = defaults.data(forKey: userKey) {
            user = try? JSONDecoder().decode(User.self, from: data)
        }
    }

    var isAuthenticated: Bool {
        guard let token, !token.isEmpty, user != nil else { return false }
        return true
    }

    func updateSession(token: String?, user: User?) {
        if let token, !token.isEmpty {
            self.token = token
            UserDefaults.standard.set(token, forKey: tokenKey)
        }
        if let user {
            self.user = user
            if let data = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(data, forKey: userKey)
            }
        }
    }

    func updateToken(_ token: String?) {
        guard let token, !token.isEmpty else { return }
        self.token = token
        UserDefaults.standard.set(token, forKey: tokenKey)
    }

    func updateUser(_ user: User?) {
        guard let user else { return }
        self.user = user
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
    }

    func clear() {
        token = nil
        user = nil
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: tokenKey)
        defaults.removeObject(forKey: userKey)
    }
}
