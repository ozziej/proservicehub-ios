//
//  CompanySearchViewModel.swift
//  Pro Service Hub
//
//  Created by Codex.
//

import Foundation
import Combine
import MapKit

@MainActor
final class CompanySearchViewModel: ObservableObject {
    @Published var companies: [CompanyWithRating] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText: String = ""
    @Published var locationQuery: String = ""
    @Published var radiusKilometers: Double = 25
    @Published var locationSuggestions: [Place] = []
    @Published var mapRegion: MKCoordinateRegion
    @Published var selectedServiceNames: Set<String> = []
    @Published var ratingFilter: Int = 0
    @Published private(set) var catalogCategories: [CatalogCategory] = []
    @Published private(set) var isLoadingCatalogs = false
    @Published private(set) var catalogErrorMessage: String?
    @Published var selectedCompanyForDetail: CompanyWithRating?
    @Published private(set) var companyDetail: CompanyDetail?
    @Published private(set) var companyBusinessHours: [BusinessHour] = []
    @Published private(set) var companyServiceAreas: [CompanyArea] = []
    @Published private(set) var isLoadingCompanyDetail = false
    @Published private(set) var companyDetailError: String?

    struct CompanyAnnotation: Identifiable {
        let id: String
        let coordinate: CLLocationCoordinate2D
        let title: String
        let subtitle: String?
    }

    var annotations: [CompanyAnnotation] {
        companies.compactMap { company in
            guard let coordinate = company.coordinate else { return nil }
            return CompanyAnnotation(id: company.id,
                                     coordinate: coordinate,
                                     title: company.name,
                                     subtitle: company.formattedDistance)
        }
    }

    private var filters: CompanySearchFilters
    private var token: String?
    private lazy var api = LabourLinkAPI(tokenProvider: { [weak self] in
        self?.token
    })
    private let locationSearchService = LocationSearchService()
    private var searchTask: Task<Void, Never>?
    private var suggestionTask: Task<Void, Never>?
    private var mapSearchTask: Task<Void, Never>?
    private var detailTask: Task<Void, Never>?
    private var hasLoadedInitialResults = false
    private var userHasPinnedLocation = false
    private var lastAutomaticCoordinate: CLLocationCoordinate2D?

    init() {
        filters = CompanySearchFilters(center: CompanySearchFilters.defaultCenter)
        mapRegion = MKCoordinateRegion(center: filters.center,
                                       span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35))
        ratingFilter = filters.minimumRating
        selectedServiceNames = Set(filters.catalogItems)
    }

    deinit {
        searchTask?.cancel()
        suggestionTask?.cancel()
        mapSearchTask?.cancel()
        detailTask?.cancel()
    }

    func loadInitialCompaniesIfNeeded() async {
        guard !hasLoadedInitialResults else { return }
        hasLoadedInitialResults = true
        await searchCompanies()
    }

    func searchCompanies() async {
        searchTask?.cancel()
        searchTask = Task {
            isLoading = true
            errorMessage = nil
            do {
                let services = Array(selectedServiceNames).sorted()
                filters.minimumRating = ratingFilter
                filters.catalogItems = services
                var requestFilters = filters
                requestFilters.searchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                requestFilters.minimumRating = ratingFilter
                requestFilters.catalogItems = services
                let radiusInMeters = max(1, radiusKilometers) * 1_000
                requestFilters.radiusMeters = Int(radiusInMeters.rounded())
                let response = try await api.fetchCompanies(filters: requestFilters)
                guard !Task.isCancelled else { return }
                token = response.token ?? token
                if response.didSucceed {
                    companies = response.companies
                } else {
                    errorMessage = response.description ?? "Unable to load companies."
                    companies = []
                }
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
                companies = []
            }
            isLoading = false
        }
        await searchTask?.value
    }

    func lookupLocations(for query: String) {
        suggestionTask?.cancel()
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 3 else {
            locationSuggestions = []
            return
        }

        suggestionTask = Task {
            do {
                try await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                let response = try await api.searchPlaces(query: trimmedQuery)
                guard !Task.isCancelled else { return }
                token = response.token ?? token
                locationSuggestions = Array(response.places.prefix(10))
            } catch {
                guard !Task.isCancelled else { return }
                locationSuggestions = []
            }
        }
    }

    func selectLocation(_ place: Place) {
        userHasPinnedLocation = true
        locationQuery = place.label
        filters.updateCenter(place.coordinate)
        locationSuggestions = []
        updateMapRegion(center: place.coordinate)
        Task {
            await searchCompanies()
        }
    }

    func updateUserLocation(_ coordinate: CLLocationCoordinate2D) {
        guard !userHasPinnedLocation else { return }
        if let lastAutomaticCoordinate {
            let delta = hypot(lastAutomaticCoordinate.latitude - coordinate.latitude,
                              lastAutomaticCoordinate.longitude - coordinate.longitude)
            guard delta > 0.0005 else { return }
        }
        lastAutomaticCoordinate = coordinate
        filters.updateCenter(coordinate)
        updateMapRegion(center: coordinate)
        if hasLoadedInitialResults {
            Task {
                await searchCompanies()
            }
        }
    }

    func resetToDefaultLocation() {
        userHasPinnedLocation = false
        filters.updateCenter(CompanySearchFilters.defaultCenter)
        locationQuery = ""
        updateMapRegion(center: filters.center)
    }

    func updateMapCenterFromUserInteraction(_ center: CLLocationCoordinate2D) {
        userHasPinnedLocation = true
        mapSearchTask?.cancel()
        mapSearchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            locationQuery = ""
            locationSuggestions = []
            filters.updateCenter(center)
            updateMapRegion(center: center)
            await searchCompanies()
        }
    }

    func clearAdvancedFilters() {
        searchText = ""
        ratingFilter = 0
        selectedServiceNames.removeAll()
    }

    func showDetails(for company: CompanyWithRating) {
        selectedCompanyForDetail = company
        companyDetail = nil
        companyBusinessHours = []
        companyServiceAreas = []
        companyDetailError = nil
        detailTask?.cancel()
        detailTask = Task { [weak self] in
            await self?.loadCompanyDetail(for: company)
        }
    }

    func refreshSelectedCompanyDetail() {
        guard let company = selectedCompanyForDetail else { return }
        detailTask?.cancel()
        detailTask = Task { [weak self] in
            await self?.loadCompanyDetail(for: company)
        }
    }

    func dismissCompanyDetail() {
        detailTask?.cancel()
        selectedCompanyForDetail = nil
        companyDetail = nil
        companyBusinessHours = []
        companyServiceAreas = []
        companyDetailError = nil
        isLoadingCompanyDetail = false
    }

    func loadCatalogsIfNeeded() async {
        guard catalogCategories.isEmpty else { return }
        await fetchCatalogOptions()
    }

    func refreshCatalogs() async {
        await fetchCatalogOptions()
    }

    private func fetchCatalogOptions() async {
        guard !isLoadingCatalogs else { return }
        isLoadingCatalogs = true
        catalogErrorMessage = nil
        defer { isLoadingCatalogs = false }
        do {
            let response = try await api.fetchCatalogs()
            guard !Task.isCancelled else { return }
            if response.didSucceed {
                catalogCategories = Self.makeCatalogCategories(from: response.catalogList)
            } else {
                catalogErrorMessage = response.description ?? "Unable to load service filters."
                catalogCategories = []
            }
        } catch {
            guard !Task.isCancelled else { return }
            catalogErrorMessage = error.localizedDescription
            catalogCategories = []
        }
    }

    private static func makeCatalogCategories(from items: [CatalogListResponse.CatalogItem]) -> [CatalogCategory] {
        let grouped = Dictionary(grouping: items, by: { $0.parentName ?? "Other Services" })
        return grouped.map { key, value in
            let sortedOptions = value.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                .map(CatalogOption.init(item:))
            return CatalogCategory(id: key, title: key, options: sortedOptions)
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func loadCompanyDetail(for company: CompanyWithRating) async {
        guard selectedCompanyForDetail?.uuid == company.uuid else { return }
        isLoadingCompanyDetail = true
        companyDetailError = nil
        companyDetail = nil
        companyBusinessHours = []
        companyServiceAreas = []
        defer {
            if selectedCompanyForDetail?.uuid == company.uuid {
                isLoadingCompanyDetail = false
            }
        }

        do {
            let detailResponse = try await api.fetchCompanyDetail(companyID: company.uuid)
            guard !Task.isCancelled else { return }
            guard selectedCompanyForDetail?.uuid == company.uuid else { return }
            token = detailResponse.token ?? token
            if detailResponse.didSucceed {
                companyDetail = detailResponse.company
            } else {
                companyDetailError = detailResponse.description ?? "Unable to load company details."
            }
        } catch {
            guard !Task.isCancelled else { return }
            guard selectedCompanyForDetail?.uuid == company.uuid else { return }
            companyDetailError = error.localizedDescription
        }

        guard !Task.isCancelled else { return }
        guard selectedCompanyForDetail?.uuid == company.uuid else { return }
        do {
            let hoursResponse = try await api.fetchBusinessHours(companyID: company.uuid)
            guard !Task.isCancelled else { return }
            guard selectedCompanyForDetail?.uuid == company.uuid else { return }
            if hoursResponse.didSucceed {
                companyBusinessHours = hoursResponse.businessHours.sorted { $0.sortOrder < $1.sortOrder }
            } else {
                companyBusinessHours = []
            }
        } catch {
            guard !Task.isCancelled else { return }
            guard selectedCompanyForDetail?.uuid == company.uuid else { return }
            companyBusinessHours = []
        }

        guard !Task.isCancelled else { return }
        guard selectedCompanyForDetail?.uuid == company.uuid else { return }
        do {
            let areasResponse = try await api.fetchCompanyAreas(companyID: company.uuid)
            guard !Task.isCancelled else { return }
            guard selectedCompanyForDetail?.uuid == company.uuid else { return }
            if areasResponse.didSucceed {
                companyServiceAreas = areasResponse.companyAreaList
            } else {
                companyServiceAreas = []
            }
        } catch {
            guard !Task.isCancelled else { return }
            guard selectedCompanyForDetail?.uuid == company.uuid else { return }
            companyServiceAreas = []
        }
    }

    private func updateMapRegion(center: CLLocationCoordinate2D) {
        mapRegion = MKCoordinateRegion(center: center,
                                       span: MKCoordinateSpan(latitudeDelta: mapRegion.span.latitudeDelta,
                                                              longitudeDelta: mapRegion.span.longitudeDelta))
    }
}
