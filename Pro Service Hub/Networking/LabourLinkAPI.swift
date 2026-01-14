//
//  LabourLinkAPI.swift
//  Pro Service Hub
//
//  Created by Codex.
//

import Foundation
internal import _LocationEssentials

enum LabourLinkEnvironment {
    static var baseURL: URL {
        if let rawValue = ProcessInfo.processInfo.environment["LABOUR_LINK_BASE_URL"],
           let overrideURL = URL(string: rawValue) {
            return overrideURL
        }
        return URL(string: "https://api.labourlink.local:8081/api")!
    }
}

enum APIError: LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server response was invalid."
        case .serverError(let statusCode):
            return "The server returned status code \(statusCode)."
        }
    }
}

struct LabourLinkAPI {
    let session: URLSession
    let baseURL: URL
    var tokenProvider: () -> String?

    init(session: URLSession = .shared,
         baseURL: URL = LabourLinkEnvironment.baseURL,
         tokenProvider: @escaping () -> String? = { nil }) {
        self.session = session
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
    }

    func fetchCompanies(filters: CompanySearchFilters, page: Int = 0, size: Int = 20) async throws -> CompanyListResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("companies/getAllCompanies"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(makeAuthorizationHeaderValue(), forHTTPHeaderField: "Authorization")

        let body = CompanySearchRequest(filters: filters, page: page, size: size)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        return try JSONDecoder().decode(CompanyListResponse.self, from: data)
    }

    func searchPlaces(query: String) async throws -> PlaceResponse {
        guard var components = URLComponents(url: baseURL.appendingPathComponent("location/findLocation"), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidResponse
        }
        components.queryItems = [URLQueryItem(name: "searchString", value: query)]
        guard let url = components.url else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(makeAuthorizationHeaderValue(), forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(PlaceResponse.self, from: data)
    }

    func fetchCatalogs(searchString: String = "") async throws -> CatalogListResponse {
        guard var components = URLComponents(url: baseURL.appendingPathComponent("catalog/getAllCatalogs"), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidResponse
        }
        components.queryItems = [URLQueryItem(name: "searchString", value: searchString)]
        guard let url = components.url else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(makeAuthorizationHeaderValue(), forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        return try JSONDecoder().decode(CatalogListResponse.self, from: data)
    }

    func fetchCompanyDetail(companyID: String) async throws -> CompanyDetailResponse {
        let url = baseURL.appendingPathComponent("companies/\(companyID)")
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(makeAuthorizationHeaderValue(), forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        return try JSONDecoder().decode(CompanyDetailResponse.self, from: data)
    }

    func fetchBusinessHours(companyID: String) async throws -> BusinessHoursResponse {
        let url = baseURL.appendingPathComponent("businessHours/\(companyID)")
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(makeAuthorizationHeaderValue(), forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        return try JSONDecoder().decode(BusinessHoursResponse.self, from: data)
    }

    func fetchCompanyAreas(companyID: String) async throws -> CompanyAreasResponse {
        let url = baseURL.appendingPathComponent("area/findAllCompanyAreas/\(companyID)")
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(makeAuthorizationHeaderValue(), forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        return try JSONDecoder().decode(CompanyAreasResponse.self, from: data)
    }

    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }
    }

    private func makeAuthorizationHeaderValue() -> String {
        guard let token = tokenProvider()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else {
            return ""
        }
        return "Bearer \(token)"
    }
}

struct CompanySearchRequest: Encodable {
    let filter: [String: FilterValue]
    let sortBy: String
    let direction: SortDirection
    let page: Int
    let size: Int

    init(filters: CompanySearchFilters, page: Int, size: Int) {
        var filterPayload: [String: FilterValue] = [
            "search": FilterValue(value: .string(filters.searchText), matchMode: .contains),
            "rating": FilterValue(value: .integer(filters.minimumRating), matchMode: .greaterThanOrEqualTo),
            "location": FilterValue(value: .location(LocationFilter(filters: filters)), matchMode: .equals)
        ]

        if !filters.catalogItems.isEmpty {
            filterPayload["catalogItems"] = FilterValue(value: .stringArray(filters.catalogItems), matchMode: .contains)
        }

        self.filter = filterPayload
        self.sortBy = "name"
        self.direction = .ascending
        self.page = page
        self.size = size
    }
}

struct LocationFilter: Encodable {
    let latitude: Double
    let longitude: Double
    let radius: Int

    init(filters: CompanySearchFilters) {
        latitude = filters.center.latitude
        longitude = filters.center.longitude
        radius = filters.radiusMeters
    }
}

enum SortDirection: String, Encodable {
    case ascending = "ASC"
    case descending = "DESC"
}

struct FilterValue: Encodable {
    let value: Payload
    let matchMode: FilterMatchMode

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(matchMode.rawValue, forKey: .matchMode)
        try container.encode(value, forKey: .value)
    }

    enum Payload: Encodable {
        case string(String)
        case stringArray([String])
        case integer(Int)
        case location(LocationFilter)

        func encode(to encoder: Encoder) throws {
            switch self {
            case .string(let value):
                var container = encoder.singleValueContainer()
                try container.encode(value)
            case .stringArray(let array):
                var container = encoder.singleValueContainer()
                try container.encode(array)
            case .integer(let value):
                var container = encoder.singleValueContainer()
                try container.encode(value)
            case .location(let location):
                try location.encode(to: encoder)
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case value
        case matchMode
    }
}

enum FilterMatchMode: String, Encodable {
    case contains = "CONTAINS"
    case equals = "EQUALS"
    case greaterThanOrEqualTo = "GREATER_THAN_OR_EQUAL_TO"
}
