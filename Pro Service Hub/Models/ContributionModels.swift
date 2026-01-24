//
//  ContributionModels.swift
//  Pro Service Hub
//
//  Created by Codex.
//

import Foundation

struct ContributionStatsResponse: Decodable {
    let responseCode: ResponseCode
    let title: String?
    let description: String?
    let token: String?
    let stats: ContributionStats?

    var didSucceed: Bool { responseCode == .successful }
}

struct ContributionStats: Decodable {
    let creatorCount: Int?
    let reviewerCount: Int?
    let totalContributions: Int?
    let placements: [ContributionPlacement]?
    let badges: [ContributionBadge]?
    let awards: [ContributionAward]?
}

struct ContributionPlacement: Decodable, Identifiable {
    let category: String
    let count: Int?
    let rank: Int?
    let totalParticipants: Int?
    let percentile: Double?

    var id: String { category }
}

struct ContributionBadge: Decodable, Identifiable {
    let category: String
    let type: String
    let label: String
    let rank: Int?
    let percentile: Int?

    var id: String { "\(category)-\(type)-\(label)" }
}

struct ContributionAward: Decodable, Identifiable {
    let category: String
    let title: String
    let rank: Int?

    var id: String { "\(category)-\(title)" }
}
