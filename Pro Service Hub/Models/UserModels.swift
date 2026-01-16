//
//  UserModels.swift
//  Pro Service Hub
//
//  Created by Codex.
//

import Foundation

struct LoginRequest: Encodable {
    let emailAddress: String
    let password: String
}

struct CreateAccountRequest: Encodable {
    let name: String
    let surname: String
    let email: String
    let cellPhone: String
}

struct UserResponse: Decodable {
    let responseCode: ResponseCode
    let title: String?
    let description: String?
    let token: String?
    let user: User?

    var didSucceed: Bool { responseCode == .successful }
}

struct User: Codable, Identifiable {
    let uuid: String
    var username: String?
    var name: String
    var surname: String
    var cellPhone: String
    var email: String
    var statusType: UserStatus?
    var userType: UserType?

    var id: String { uuid }
}

enum UserStatus: String, Codable {
    case enabled = "ENABLED"
    case disabled = "DISABLED"
    case verifyEmail = "VERIFY_EMAIL"
    case reset = "RESET"
}

enum UserType: String, Codable {
    case user = "USER"
    case admin = "ADMIN"
}
