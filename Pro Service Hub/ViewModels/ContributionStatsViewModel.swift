//
//  ContributionStatsViewModel.swift
//  Pro Service Hub
//
//  Created by Codex.
//

import Foundation
import Combine

@MainActor
final class ContributionStatsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var stats: ContributionStats?
    @Published var needsLogin = false

    private let session: AppSession
    private let api: LabourLinkAPI

    init(session: AppSession) {
        self.session = session
        self.api = LabourLinkAPI(tokenProvider: { [weak session] in
            session?.token
        })
    }

    func loadStats() async {
        guard let userUuid = session.user?.uuid else {
            stats = nil
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await api.fetchContributionStats(userUuid: userUuid)
            session.updateToken(response.token)
            if response.responseCode == .tokenExpired {
                handleTokenExpiry(message: response.description)
                return
            }
            if response.didSucceed {
                stats = response.stats
                errorMessage = nil
            } else {
                stats = nil
                errorMessage = response.description ?? "Unable to load contributions."
            }
        } catch {
            if session.handleUnauthorized(error) {
                handleTokenExpiry(message: nil)
                return
            }
            stats = nil
            errorMessage = error.localizedDescription
        }
    }

    var orderedPlacements: [ContributionPlacement] {
        guard let placements = stats?.placements else { return [] }
        return placements.sorted { categoryOrderIndex($0.category) < categoryOrderIndex($1.category) }
    }

    var orderedBadges: [ContributionBadge] {
        guard let badges = stats?.badges else { return [] }
        return badges.sorted { lhs, rhs in
            let categoryDelta = categoryOrderIndex(lhs.category) - categoryOrderIndex(rhs.category)
            if categoryDelta != 0 { return categoryDelta < 0 }
            return badgeTypeOrder(lhs.type) < badgeTypeOrder(rhs.type)
        }
    }

    var orderedAwards: [ContributionAward] {
        guard let awards = stats?.awards else { return [] }
        return awards.sorted { categoryOrderIndex($0.category) < categoryOrderIndex($1.category) }
    }

    var hasAnyRank: Bool {
        orderedPlacements.contains { $0.rank != nil }
    }

    private func handleTokenExpiry(message: String?) {
        session.clear()
        stats = nil
        errorMessage = message ?? "Session expired. Please log in again."
        needsLogin = true
    }

    private func categoryOrderIndex(_ category: String) -> Int {
        switch category.lowercased() {
        case "overall":
            return 0
        case "creator":
            return 1
        case "reviewer":
            return 2
        default:
            return 3
        }
    }

    private func badgeTypeOrder(_ type: String) -> Int {
        switch type.uppercased() {
        case "RANK":
            return 0
        case "TOP_PERCENT":
            return 1
        default:
            return 2
        }
    }
}
