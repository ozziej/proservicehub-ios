//
//  CatalogModels.swift
//  Pro Service Hub
//
//  Created by Codex.
//

import Foundation

struct CatalogListResponse: Decodable {
    let responseCode: ResponseCode?
    let title: String?
    let description: String?
    let catalogList: [CatalogItem]

    var didSucceed: Bool {
        guard let responseCode else { return true }
        return responseCode == .successful
    }

    struct CatalogItem: Decodable, Identifiable {
        let uuid: String?
        let name: String
        let parentName: String?

        var id: String { uuid ?? "\(parentName ?? "Ungrouped")-\(name)" }
    }
}

struct CatalogCategory: Identifiable, Hashable {
    let id: String
    let title: String
    let options: [CatalogOption]
}

struct CatalogOption: Identifiable, Hashable {
    let id: String
    let name: String
    let parentTitle: String

    init(item: CatalogListResponse.CatalogItem) {
        id = item.uuid ?? "\(item.parentName ?? "Ungrouped")-\(item.name)"
        name = item.name
        parentTitle = item.parentName ?? "Other Services"
    }
}
