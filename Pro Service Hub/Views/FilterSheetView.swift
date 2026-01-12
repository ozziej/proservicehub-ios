//
//  FilterSheetView.swift
//  Pro Service Hub
//
//  Created by Codex.
//

import SwiftUI

struct FilterSheetView: View {
    @Binding var isPresented: Bool
    @Binding var searchText: String
    @Binding var ratingFilter: Int
    @Binding var selectedServiceNames: Set<String>

    let catalogCategories: [CatalogCategory]
    let isLoadingCatalogs: Bool
    let catalogErrorMessage: String?
    let loadCatalogs: () async -> Void
    let reloadCatalogs: () async -> Void
    let onApply: () -> Void
    let onClear: () -> Void

    @State private var serviceSearchTerm: String = ""

    private let ratingOptions: [Int] = [4, 3, 2, 1, 0]

    private var filteredCategories: [CatalogCategory] {
        guard !serviceSearchTerm.isEmpty else { return catalogCategories }
        return catalogCategories.compactMap { category in
            let filteredOptions = category.options.filter {
                $0.name.localizedCaseInsensitiveContains(serviceSearchTerm)
            }
            guard !filteredOptions.isEmpty else { return nil }
            return CatalogCategory(id: category.id, title: category.title, options: filteredOptions)
        }
    }

    @ViewBuilder
    private var servicesSectionContent: some View {
                    if isLoadingCatalogs && catalogCategories.isEmpty {
                        ProgressView("Loading services...")
                .frame(maxWidth: .infinity, alignment: .center)
        } else if let message = catalogErrorMessage, catalogCategories.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(message)
                    .foregroundStyle(.red)
                Button {
                    Task { await reloadCatalogs() }
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
            }
        } else if catalogCategories.isEmpty {
            Text("No services are available. Try refreshing later.")
                .foregroundStyle(.secondary)
        } else {
            TextField("Search services", text: $serviceSearchTerm)
                .textInputAutocapitalization(.none)
                .disableAutocorrection(true)

            if !selectedServiceNames.isEmpty {
                Text("\(selectedServiceNames.count) service(s) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ServiceCategoryListView(categories: filteredCategories,
                                    selectedServiceNames: $selectedServiceNames,
                                    onToggle: toggleSelection)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Company") {
                    TextField("Name or phone number", text: $searchText)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                }

                Section("Services") {
                    servicesSectionContent
                }

                Section("Minimum rating") {
                    Picker("Minimum rating", selection: $ratingFilter) {
                        ForEach(ratingOptions, id: \.self) { rating in
                            Text(ratingLabel(for: rating)).tag(rating)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section {
                    Button(role: .destructive) {
                        serviceSearchTerm = ""
                        onClear()
                    } label: {
                        Label("Clear filters", systemImage: "line.horizontal.3.decrease.circle.badge.minus")
                    }
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        isPresented = false
                        onApply()
                    }
                    .disabled(isLoadingCatalogs && catalogCategories.isEmpty)
                }
            }
            .task {
                await loadCatalogs()
            }
        }
    }

    private func toggleSelection(for option: CatalogOption) {
        if selectedServiceNames.contains(option.name) {
            selectedServiceNames.remove(option.name)
        } else {
            selectedServiceNames.insert(option.name)
        }
    }

    private func ratingLabel(for rating: Int) -> String {
        switch rating {
        case 4:
            return "4 stars and up"
        case 3:
            return "3 stars and up"
        case 2:
            return "2 stars and up"
        case 1:
            return "1 star and up"
        default:
            return "Any rating"
        }
    }
}

private struct ServiceCategoryListView: View {
    let categories: [CatalogCategory]
    @Binding var selectedServiceNames: Set<String>
    let onToggle: (CatalogOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(categories) { category in
                DisclosureGroup(category.title) {
                    ServiceOptionListView(options: category.options,
                                          selectedServiceNames: $selectedServiceNames,
                                          onToggle: onToggle)
                        .padding(.top, 4)
                }
            }
        }
    }
}

private struct ServiceOptionListView: View {
    let options: [CatalogOption]
    @Binding var selectedServiceNames: Set<String>
    let onToggle: (CatalogOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(options) { option in
                ServiceOptionRow(option: option,
                                 isSelected: selectedServiceNames.contains(option.name),
                                 onToggle: onToggle)
                if option.id != options.last?.id {
                    Divider()
                        .padding(.leading, 4)
                }
            }
        }
    }
}

private struct ServiceOptionRow: View {
    let option: CatalogOption
    let isSelected: Bool
    let onToggle: (CatalogOption) -> Void

    var body: some View {
        Button {
            onToggle(option)
        } label: {
            HStack {
                Text(option.name)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.tint, .white)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
