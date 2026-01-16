//
//  BookingModels.swift
//  Pro Service Hub
//
//  Created by Codex.
//

import Foundation

struct BookingRequest: Encodable {
    let bookingUuid: String?
    let userUuid: String
    let companyUuid: String
    let bookingTime: Date
}

struct BookingResponse: Decodable {
    let responseCode: ResponseCode
    let title: String?
    let description: String?
    let token: String?
    let booking: CompanyBooking?

    var didSucceed: Bool { responseCode == .successful }
}

struct BookingListResponse: Decodable {
    let responseCode: ResponseCode
    let title: String?
    let description: String?
    let token: String?
    let bookingList: [CompanyBooking]?

    var didSucceed: Bool { responseCode == .successful }
}

struct CompanyBooking: Decodable, Identifiable {
    let uuid: String
    let user: BookingUserSummary
    let company: BookingCompanySummary
    let bookingTime: Date
    let status: BookingStatus

    var id: String { uuid }
}

struct BookingUserSummary: Decodable {
    let uuid: String
    let email: String
}

struct BookingCompanySummary: Decodable {
    let uuid: String
    let name: String
}

enum BookingStatus: String, Decodable {
    case unconfirmed = "UNCONFIRMED"
    case confirmed = "CONFIRMED"
    case cancelled = "CANCELLED"
}
