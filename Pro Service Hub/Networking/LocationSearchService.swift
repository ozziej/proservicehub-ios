//
//  LocationSearchService.swift
//  Pro Service Hub
//
//  Created by Codex.
//

import Foundation
import CoreLocation

struct LocationSearchService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchPlaces(query: String, limit: Int = 5) async throws -> [Place] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }
        guard var components = URLComponents(string: "https://nominatim.openstreetmap.org/search") else {
            throw APIError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: trimmedQuery),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "addressdetails", value: "0"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        guard let url = components.url else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("ProServiceHub-iOS", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let rawResults = try decoder.decode([NominationResult].self, from: data)
        return rawResults.compactMap { result in
            guard let coordinate = result.coordinate else { return nil }
            let boundingBox = result.boundingbox?.compactMap(Double.init)
            return Place(placeId: result.placeId,
                         name: result.displayName,
                         displayName: result.displayName,
                         type: result.type,
                         importance: result.importance,
                         boundingBox: boundingBox,
                         coordinate: coordinate)
        }
    }
}

private struct NominationResult: Decodable {
    let placeId: Int?
    let displayName: String
    let lat: String
    let lon: String
    let type: String?
    let importance: Double?
    let boundingbox: [String]?

    var coordinate: CLLocationCoordinate2D? {
        guard let latValue = Double(lat), let lonValue = Double(lon) else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: latValue, longitude: lonValue)
    }
}
