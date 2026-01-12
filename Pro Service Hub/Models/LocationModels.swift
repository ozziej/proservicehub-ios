//
//  LocationModels.swift
//  Pro Service Hub
//
//  Created by Codex.
//

import Foundation
import CoreLocation

struct PlaceResponse: Decodable {
    let responseCode: ResponseCode?
    let title: String?
    let description: String?
    let token: String?
    let places: [Place]

    var didSucceed: Bool {
        guard let responseCode else { return true }
        return responseCode == .successful
    }
}

struct Place: Decodable, Identifiable {
    let placeId: Int?
    let name: String?
    let displayName: String?
    let type: String?
    let importance: Double?
    let boundingBox: [Double]?
    let coordinate: CLLocationCoordinate2D

    private let identifier = UUID()

    var id: UUID { identifier }

    var label: String {
        if let displayName, !displayName.isEmpty {
            return displayName
        }
        if let name, !name.isEmpty {
            return name
        }
        if let type, !type.isEmpty {
            return type.capitalized
        }
        return "Unknown place"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        placeId = try container.decodeIfPresent(Int.self, forKey: .placeId)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        importance = try container.decodeIfPresent(Double.self, forKey: .importance)
        boundingBox = try container.decodeIfPresent([Double].self, forKey: .boundingBox)

        let latValue = try Place.decodeCoordinate(from: container, key: .lat)
        let lonValue = try Place.decodeCoordinate(from: container, key: .lon)
        coordinate = CLLocationCoordinate2D(latitude: latValue, longitude: lonValue)
    }

    init(placeId: Int?,
         name: String?,
         displayName: String?,
         type: String?,
         importance: Double?,
         boundingBox: [Double]?,
         coordinate: CLLocationCoordinate2D) {
        self.placeId = placeId
        self.name = name
        self.displayName = displayName
        self.type = type
        self.importance = importance
        self.boundingBox = boundingBox
        self.coordinate = coordinate
    }

    private static func decodeCoordinate(from container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) throws -> Double {
        if let doubleValue = try container.decodeIfPresent(Double.self, forKey: key) {
            return doubleValue
        }
        if let stringValue = try container.decodeIfPresent(String.self, forKey: key), let doubleValue = Double(stringValue) {
            return doubleValue
        }
        throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "Expected coordinate value")
    }

    private enum CodingKeys: String, CodingKey {
        case placeId
        case name
        case displayName
        case lat
        case lon
        case type
        case importance
        case boundingBox
    }
}
