//
//  AuthViewModel.swift
//  Pro Service Hub
//
//  Created by Codex.
//

import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var emailAddress = ""
    @Published var password = ""
    @Published var name = ""
    @Published var surname = ""
    @Published var cellPhone = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let session: AppSession
    private let api: LabourLinkAPI

    init(session: AppSession) {
        self.session = session
        self.api = LabourLinkAPI(tokenProvider: { [weak session] in
            session?.token
        })
    }

    func login() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        do {
            let response = try await api.loginUser(request: LoginRequest(emailAddress: emailAddress, password: password))
            session.updateToken(response.token)
            if let user = response.user {
                session.updateUser(user)
            }
            if response.didSucceed {
                successMessage = response.description
            } else {
                errorMessage = response.description ?? "Unable to log in."
            }
        } catch {
            if case APIError.unauthorized = error {
                errorMessage = "Invalid email or password."
                return
            }
            errorMessage = error.localizedDescription
        }
    }

    func createAccount() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        do {
            let request = CreateAccountRequest(name: name, surname: surname, email: emailAddress, cellPhone: cellPhone)
            let response = try await api.createAccount(request: request)
            if response.didSucceed {
                successMessage = response.description ?? "Account created. Check your email to set your password."
            } else {
                errorMessage = response.description ?? "Unable to create account."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateProfile(user: User) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        do {
            let response = try await api.updateUser(user)
            session.updateToken(response.token)
            if let updatedUser = response.user {
                session.updateUser(updatedUser)
            }
            if response.didSucceed {
                successMessage = response.description ?? "Profile updated."
            } else {
                errorMessage = response.description ?? "Unable to update profile."
            }
        } catch {
            if session.handleUnauthorized(error) {
                errorMessage = "Session expired. Please log in again."
                return
            }
            errorMessage = error.localizedDescription
        }
    }
}
