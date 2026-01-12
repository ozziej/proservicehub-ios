//
//  CompanyDetailSheetView.swift
//  Pro Service Hub
//
//  Created by Codex.
//

import SwiftUI
import MapKit

struct CompanyDetailSheetView: View {
    let summary: CompanyWithRating
    let detail: CompanyDetail?
    let businessHours: [BusinessHour]
    let serviceAreas: [CompanyArea]
    let isLoading: Bool
    let errorMessage: String?
    let userCoordinate: CLLocationCoordinate2D?
    let onRefresh: () -> Void

    @State private var mapPosition: MapCameraPosition

    init(summary: CompanyWithRating,
         detail: CompanyDetail?,
         businessHours: [BusinessHour],
         serviceAreas: [CompanyArea],
         isLoading: Bool,
         errorMessage: String?,
         userCoordinate: CLLocationCoordinate2D?,
         onRefresh: @escaping () -> Void) {
        self.summary = summary
        self.detail = detail
        self.businessHours = businessHours
        self.serviceAreas = serviceAreas
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.userCoordinate = userCoordinate
        self.onRefresh = onRefresh
        _mapPosition = State(initialValue: .region(CompanyDetailSheetView.region(for: summary,
                                                                                detail: detail,
                                                                                serviceAreas: serviceAreas)))
    }

    private var targetRegion: MKCoordinateRegion {
        CompanyDetailSheetView.region(for: summary, detail: detail, serviceAreas: serviceAreas)
    }

    private var regionAnchorKey: String {
        let region = targetRegion
        return "\(region.center.latitude)-\(region.center.longitude)-\(region.span.latitudeDelta)-\(region.span.longitudeDelta)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isLoading {
                        HStack {
                            ProgressView()
                            Text("Loading latest details...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .padding()
                            .background(Color.red.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    overviewSection
                    servicesSection
                    businessHoursSection
                    serviceAreasSection
                    mapSection
                }
                .padding()
            }
            .navigationTitle(detail?.name ?? summary.name)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onRefresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                    .accessibilityLabel("Refresh company details")
                }
            }
        }
        .task(id: regionAnchorKey) {
            mapPosition = .region(targetRegion)
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(detail?.name ?? summary.name)
                        .font(.title2.weight(.semibold))
                    if let description = detail?.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                statusBadge
            }

            Group {
                infoRow(icon: "phone.fill", title: "Phone", value: displayPhone)
                infoRow(icon: "envelope.fill", title: "Email", value: displayEmail)
                if let website = displayWebsite {
                    infoRow(icon: "globe", title: "Website", value: website)
                }
                infoRow(icon: "mappin.and.ellipse", title: "Address", value: displayAddress)
                infoRow(icon: "car.fill", title: "Distance", value: displayDistance)
                infoRow(icon: "star.fill", title: "Average Rating", value: displayRating)
            }
            .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Services")
                .font(.headline)
            if services.isEmpty {
                Text("No services listed.")
                    .foregroundStyle(.secondary)
            } else {
                let columns = [GridItem(.adaptive(minimum: 90), spacing: 8)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(services, id: \.self) { service in
                        Text(service)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color(.systemGray5)))
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private var businessHoursSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Business Hours")
                .font(.headline)
            if businessHours.isEmpty {
                Text("Hours not provided.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(businessHours.enumerated()), id: \.element.id) { index, hour in
                    HStack {
                        Text(hour.displayDayName)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(hour.displayRange)
                            .foregroundStyle(hour.available ? Color.primary : Color.secondary)
                    }
                    if index < businessHours.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private var serviceAreasSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Areas Covered")
                .font(.headline)
            if serviceAreas.isEmpty {
                Text("No service areas shared.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(serviceAreas.enumerated()), id: \.element.id) { index, area in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(area.displayTitle)
                            .fontWeight(.semibold)
                        Text(area.formattedRadius)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if index < serviceAreas.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Map")
                .font(.headline)
            if companyCoordinate == nil && serviceAreas.first?.coordinate == nil {
                Text("No map data is available for this company.")
                    .foregroundStyle(.secondary)
            } else {
                Map(position: $mapPosition, interactionModes: [.pan, .zoom, .rotate, .pitch]) {
                    if let companyCoordinate {
                        Annotation(summary.name, coordinate: companyCoordinate) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title2)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.red, .white)
                        }
                    }
                    if let userCoordinate {
                        Annotation("You", coordinate: userCoordinate) {
                            Image(systemName: "person.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.blue)
                        }
                    }
                    ForEach(serviceAreas) { area in
                        if let coordinate = area.coordinate, area.radiusMeters > .zero {
                            MapCircle(center: coordinate, radius: area.radiusMeters)
                                .stroke(Color.accentColor.opacity(0.65), lineWidth: 1)
                                .foregroundStyle(Color.accentColor.opacity(0.15))
                        }
                    }
                }
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private var statusBadge: some View {
        let rawStatus = (detail?.statusType ?? summary.statusType ?? "").uppercased()
        let isVerified = rawStatus == "VERIFIED"
        let labelText = isVerified ? "Verified" : "Unverified"
        let iconName = isVerified ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
        let tint = isVerified ? Color.green : Color.orange
        return Label(labelText, systemImage: iconName)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.15))
            .foregroundStyle(tint)
            .clipShape(Capsule())
    }

    private func infoRow(icon: String, title: String, value: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value?.isEmpty == false ? value! : "Not available")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
        }
    }

    private var services: [String] {
        if let detailedServices = detail?.serviceNames, !detailedServices.isEmpty {
            return detailedServices
        }
        return summary.catalogItems ?? []
    }

    private var displayPhone: String? {
        detail?.phoneNumber ?? summary.phoneNumber
    }

    private var displayEmail: String? {
        detail?.email ?? summary.email
    }

    private var displayWebsite: String? {
        detail?.websiteUrl
    }

    private var displayAddress: String? {
        detail?.address ?? summary.address
    }

    private var displayDistance: String? {
        summary.formattedDistance
    }

    private var displayRating: String {
        if let rating = detail?.averageRating ?? summary.averageRating, rating > 0 {
            return String(format: "%.1f ★", rating)
        }
        return "Unrated"
    }

    private var companyCoordinate: CLLocationCoordinate2D? {
        detail?.coordinate ?? summary.coordinate ?? serviceAreas.first?.coordinate
    }

    private static func region(for summary: CompanyWithRating,
                               detail: CompanyDetail?,
                               serviceAreas: [CompanyArea]) -> MKCoordinateRegion {
        if let area = serviceAreas.first(where: { $0.coordinate != nil }) {
            let center = area.coordinate!
            let span = span(for: area.radiusMeters)
            return MKCoordinateRegion(center: center, span: span)
        }
        if let coordinate = detail?.coordinate ?? summary.coordinate {
            return MKCoordinateRegion(center: coordinate,
                                      span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2))
        }
        return MKCoordinateRegion(center: CompanySearchFilters.defaultCenter,
                                  span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0))
    }

    private static func span(for radius: CLLocationDistance) -> MKCoordinateSpan {
        guard radius > 0 else {
            return MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
        }
        let kilometers = max(radius / 1_000, 1)
        let delta = min(max(kilometers / 111, 0.05), 2.0)
        return MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)
    }
}
