//
//  CompanyModels.swift
//  Pro Service Hub
//
//  Created by Codex.
//

import Foundation
import CoreLocation

enum ResponseCode: String, Decodable {
    case successful = "SUCCESSFUL"
    case error = "ERROR"
    case noResponse = "NO_RESPONSE"
    case tokenExpired = "TOKEN_EXPIRED"
}

struct CompanyListResponse: Decodable {
    let responseCode: ResponseCode
    let title: String?
    let description: String?
    let token: String?
    let companyList: CompanyPage

    var companies: [CompanyWithRating] { companyList.content }
    var didSucceed: Bool { responseCode == .successful }

    struct CompanyPage: Decodable {
        let content: [CompanyWithRating]
        let totalElements: Int
        let totalPages: Int
        let size: Int
        let number: Int
    }
}

struct CompanyWithRating: Decodable, Identifiable {
    let uuid: String
    let name: String
    let phoneNumber: String?
    let email: String?
    let address: String?
    let websiteUrl: String?
    let statusType: String?
    let catalogItems: [String]?
    let averageRating: Double?
    let latitude: Double?
    let longitude: Double?
    let distance: Double?

    var id: String { uuid }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var formattedDistance: String? {
        guard let distance else { return nil }
        if distance > 1000 {
            return String(format: "%.1f km", distance / 1000)
        }
        return String(format: "%.0f m", distance)
    }

    var formattedRating: String {
        guard let rating = averageRating, rating > .zero else { return "Unrated" }
        return String(format: "%.1f ★", rating)
    }
}

struct CompanySearchFilters {
    var searchText: String = ""
    var center: CLLocationCoordinate2D
    var radiusMeters: Int = 25_000
    var minimumRating: Int = 0
    var catalogItems: [String] = []

    static let defaultCenter = CLLocationCoordinate2D(latitude: -33.9249, longitude: 18.4241)

    mutating func updateCenter(_ coordinate: CLLocationCoordinate2D) {
        center = coordinate
    }
}

struct CompanyDetailResponse: Decodable {
    let responseCode: ResponseCode
    let title: String?
    let description: String?
    let token: String?
    let company: CompanyDetail

    var didSucceed: Bool { responseCode == .successful }
}

struct CompanyDetail: Decodable, Identifiable {
    let uuid: String
    let name: String
    let phoneNumber: String?
    let email: String?
    let address: String?
    let websiteUrl: String?
    let statusType: String?
    let catalogItems: [CompanyCatalogItemValue]?
    let description: String?
    let averageRating: Double?
    let distance: Double?
    let latitude: Double?
    let longitude: Double?

    var id: String { uuid }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var serviceNames: [String] {
        catalogItems?.map(\.name).filter { !$0.isEmpty } ?? []
    }
}

struct CompanyCatalogItemValue: Decodable {
    let name: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            name = text
            return
        }
        let object = try container.decode(CatalogItemObject.self)
        name = object.name ?? object.label ?? ""
    }

    private struct CatalogItemObject: Decodable {
        let name: String?
        let label: String?
    }
}

struct BusinessHoursResponse: Decodable {
    let responseCode: ResponseCode?
    let title: String?
    let description: String?
    let businessHours: [BusinessHour]

    var didSucceed: Bool {
        guard let responseCode else { return true }
        return responseCode == .successful
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        responseCode = try container.decodeIfPresent(ResponseCode.self, forKey: .responseCode)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        businessHours = try container.decodeIfPresent([BusinessHour].self, forKey: .businessHours) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case responseCode
        case title
        case description
        case businessHours
    }
}

struct BusinessHour: Decodable, Identifiable {
    let uuid: String?
    let dayOfWeek: String
    let available: Bool
    let startTime: String?
    let endTime: String?

    var id: String { uuid ?? dayOfWeek }

    var normalizedDayKey: String {
        dayOfWeek.uppercased()
    }

    var displayDayName: String {
        let lowercased = normalizedDayKey.lowercased()
        guard let first = lowercased.first else { return normalizedDayKey }
        return String(first).uppercased() + lowercased.dropFirst()
    }

    var normalizedStartTime: String? {
        BusinessHour.normalize(time: startTime)
    }

    var normalizedEndTime: String? {
        BusinessHour.normalize(time: endTime)
    }

    var displayRange: String {
        guard available else { return "Closed" }
        return "\(normalizedStartTime ?? "--") - \(normalizedEndTime ?? "--")"
    }

    var sortOrder: Int {
        Self.weekdayOrder.firstIndex(of: normalizedDayKey) ?? Self.weekdayOrder.count
    }

    private static func normalize(time: String?) -> String? {
        guard let value = time, !value.isEmpty else { return nil }
        if value.count >= 5 {
            let index = value.index(value.startIndex, offsetBy: 5)
            return String(value[..<index])
        }
        return value
    }

    private static let weekdayOrder = [
        "MONDAY",
        "TUESDAY",
        "WEDNESDAY",
        "THURSDAY",
        "FRIDAY",
        "SATURDAY",
        "SUNDAY"
    ]
}

struct CompanyAreasResponse: Decodable {
    let responseCode: ResponseCode?
    let title: String?
    let description: String?
    let companyAreaList: [CompanyArea]

    var didSucceed: Bool {
        guard let responseCode else { return true }
        return responseCode == .successful
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        responseCode = try container.decodeIfPresent(ResponseCode.self, forKey: .responseCode)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        companyAreaList = try container.decodeIfPresent([CompanyArea].self, forKey: .companyAreaList) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case responseCode
        case title
        case description
        case companyAreaList
    }
}

struct CompanyArea: Decodable, Identifiable {
    let uuid: String?
    let name: String?
    let latitude: Double?
    let longitude: Double?
    let radius: Double?

    var id: String {
        if let uuid, !uuid.isEmpty {
            return uuid
        }
        let lat = latitude ?? 0
        let lon = longitude ?? 0
        return "\(lat)-\(lon)"
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var radiusMeters: CLLocationDistance {
        max(radius ?? 0, 0)
    }

    var displayTitle: String {
        if let name, !name.isEmpty {
            return name
        }
        return "Service Area"
    }

    var formattedRadius: String {
        let meters = radiusMeters
        if meters >= 1000 {
            return String(format: "%.1f km radius", meters / 1000)
        }
        return "\(Int(meters)) m radius"
    }
}
