//
//  ContentView.swift
//  Pro Service Hub
//
//  Created by James Ostrowick on 2026/01/06.
//

import SwiftUI
import MapKit

struct ContentView: View {
    private let session: AppSession
    @StateObject private var viewModel: CompanySearchViewModel
    @StateObject private var locationManager = LocationManager()
    @State private var cameraPosition: MapCameraPosition = .region(.defaultSearchRegion)
    @State private var isShowingFilters = false
    @State private var isUpdatingMapProgrammatically = false
    @State private var lastObservedMapRegion = MKCoordinateRegion.defaultSearchRegion

    init(session: AppSession) {
        self.session = session
        _viewModel = StateObject(wrappedValue: CompanySearchViewModel(session: session))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    filterCard
                    mapCard
                    resultsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Pro Service Hub")
            .task {
                locationManager.requestAccess()
                await viewModel.loadInitialCompaniesIfNeeded()
            }
            .onReceive(locationManager.$lastLocation) { coordinate in
                guard let coordinate else { return }
                viewModel.updateUserLocation(coordinate)
            }
            .onReceive(viewModel.$mapRegion) { region in
                isUpdatingMapProgrammatically = true
                cameraPosition = .region(region)
                lastObservedMapRegion = region
            }
            .sheet(isPresented: $isShowingFilters) {
                FilterSheetView(isPresented: $isShowingFilters,
                                searchText: $viewModel.searchText,
                                ratingFilter: $viewModel.ratingFilter,
                                selectedServiceNames: $viewModel.selectedServiceNames,
                                catalogCategories: viewModel.catalogCategories,
                                isLoadingCatalogs: viewModel.isLoadingCatalogs,
                                catalogErrorMessage: viewModel.catalogErrorMessage,
                                loadCatalogs: { await viewModel.loadCatalogsIfNeeded() },
                                reloadCatalogs: { await viewModel.refreshCatalogs() },
                                onApply: {
                                    Task { await viewModel.searchCompanies() }
                                },
                                onClear: {
                                    viewModel.clearAdvancedFilters()
                                    Task { await viewModel.searchCompanies() }
                                })
            }
            .sheet(item: $viewModel.selectedCompanyForDetail, onDismiss: {
                viewModel.dismissCompanyDetail()
            }) { company in
                CompanyDetailSheetView(summary: company,
                                       detail: viewModel.companyDetail,
                                       businessHours: viewModel.companyBusinessHours,
                                       serviceAreas: viewModel.companyServiceAreas,
                                       isLoading: viewModel.isLoadingCompanyDetail,
                                       errorMessage: viewModel.companyDetailError,
                                       userCoordinate: locationManager.lastLocation,
                                       session: session,
                                       onRefresh: {
                                           viewModel.refreshSelectedCompanyDetail()
                                       })
                .presentationDetents([.medium, .large])
            }
        }
    }

    private var filterCard: some View {
        let suggestions = Array(viewModel.locationSuggestions.prefix(5))
        return VStack(alignment: .leading, spacing: 12) {
            Text("Find trusted companies")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Location")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("City, suburb, or landmark", text: $viewModel.locationQuery)
                    .textFieldStyle(.roundedBorder)
                    .overlay(alignment: .trailing) {
                        if viewModel.isLoadingLocationSuggestions {
                            ProgressView()
                                .scaleEffect(0.8)
                                .padding(.trailing, 8)
                        }
                    }
                    .clearButton(text: $viewModel.locationQuery) {
                        viewModel.locationQuery = ""
                        viewModel.lookupLocations(for: "")
                    }
                    .onChange(of: viewModel.locationQuery, initial: false) { _, newValue in
                        if viewModel.consumeSuppressLocationLookup() {
                            return
                        }
                        viewModel.lookupLocations(for: newValue)
                    }
                if !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, place in
                            Button {
                                viewModel.selectLocation(place)
                            } label: {
                                HStack {
                                    Text(place.label)
                                        .multilineTextAlignment(.leading)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "mappin.and.ellipse")
                                        .foregroundStyle(.regularMaterial)
                                }
                                .padding(8)
                            }
                            if index < suggestions.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Search radius")
                    Spacer()
                    Text("\(Int(viewModel.radiusKilometers)) km")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Slider(value: $viewModel.radiusKilometers, in: 5...100, step: 5)
            }

            if let summary = activeFilterSummary {
                Divider()
                Label(summary, systemImage: "line.horizontal.3.decrease.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button(role: .cancel) {
                    viewModel.resetToDefaultLocation()
                } label: {
                    Label("Reset", systemImage: "arrow.uturn.left")
                }
                Spacer()
                Button {
                    isShowingFilters = true
                } label: {
                    Label("Filters", systemImage: "slider.horizontal.3")
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                Button {
                    Task { await viewModel.searchCompanies() }
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var activeFilterSummary: String? {
        var parts: [String] = []
        let trimmedQuery = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            parts.append("Text: \"\(trimmedQuery)\"")
        }
        if !viewModel.selectedServiceNames.isEmpty {
            parts.append("\(viewModel.selectedServiceNames.count) service(s)")
        }
        if viewModel.ratingFilter > 0 {
            parts.append(">= \(viewModel.ratingFilter) ★")
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " • ")
    }

    private var mapCard: some View {
        return VStack(alignment: .leading, spacing: 8) {
            Map(position: $cameraPosition, interactionModes: [.pan, .zoom, .rotate, .pitch]) {
                ForEach(viewModel.annotations) { annotation in
                    Annotation(annotation.title, coordinate: annotation.coordinate) {
                        Button {
                            if let company = viewModel.companies.first(where: { $0.id == annotation.id }) {
                                viewModel.showDetails(for: company)
                            }
                        } label: {
                            CompanyMarkerView(annotation: annotation)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                handleMapCameraChange(region: context.region)
            }
            .overlay(alignment: .topTrailing) {
                if viewModel.isLoading {
                    HStack(spacing: 6) {
                        ProgressView()
                        Text("Updating…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                    .padding(8)
                }
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Text("Showing \(viewModel.companies.count) result(s) within \(Int(viewModel.radiusKilometers)) km")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func handleMapCameraChange(region: MKCoordinateRegion) {
        if isUpdatingMapProgrammatically {
            isUpdatingMapProgrammatically = false
            return
        }
        let centerDelta = hypot(region.center.latitude - lastObservedMapRegion.center.latitude,
                                region.center.longitude - lastObservedMapRegion.center.longitude)
        let spanDelta = hypot(region.span.latitudeDelta - lastObservedMapRegion.span.latitudeDelta,
                              region.span.longitudeDelta - lastObservedMapRegion.span.longitudeDelta)
        guard centerDelta > 0.0001 || spanDelta > 0.0001 else { return }
        lastObservedMapRegion = region
        let zoomRadius = radiusKilometers(for: region)
        viewModel.updateMapRegionFromUserInteraction(region, radiusKilometers: zoomRadius)
    }

    private func radiusKilometers(for region: MKCoordinateRegion) -> Double {
        let spanKm = max(region.span.latitudeDelta, region.span.longitudeDelta) * 111.0
        let radius = max(5, min(100, spanKm / 2))
        return (radius / 5).rounded() * 5
    }

private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if viewModel.isLoading {
                HStack {
                    ProgressView()
                    Text("Searching Labour Link...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            }

            if viewModel.companies.isEmpty && !viewModel.isLoading {
                Text("No companies match the current filters. Try adjusting your filters or radius.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.companies) { company in
                        CompanyCardView(company: company) { selectedCompany in
                            viewModel.showDetails(for: selectedCompany)
                        }
                    }
                }
            }
        }
    }
}

private struct CompanyCardView: View {
    let company: CompanyWithRating
    let onSelect: (CompanyWithRating) -> Void

    var body: some View {
        Button {
            onSelect(company)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(company.name)
                        .font(.headline)
                    Spacer()
                    if let distance = company.formattedDistance {
                        Label(distance, systemImage: "mappin")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(company.formattedRating)
                    .font(.subheadline)
                    .foregroundStyle(Color(.systemYellow))

                if let address = company.address, !address.isEmpty {
                    Label(address, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let phone = company.phoneNumber, !phone.isEmpty {
                    Label(phone, systemImage: "phone")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let catalogItems = company.catalogItems, !catalogItems.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(catalogItems.prefix(4), id: \.self) { item in
                                Text(item)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color(.systemGray5)))
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        }
        .buttonStyle(.plain)
    }
}

private struct CompanyMarkerView: View {
    let annotation: CompanySearchViewModel.CompanyAnnotation

    var body: some View {
        VStack(spacing: 2) {
            Text(annotation.title)
                .font(.caption2)
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(.systemBackground)))
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.red, .white)
        }
    }
}

private extension MKCoordinateRegion {
    static var defaultSearchRegion: MKCoordinateRegion {
        MKCoordinateRegion(center: CompanySearchFilters.defaultCenter,
                           span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35))
    }
}

#Preview {
    RootTabView(session: AppSession())
}
