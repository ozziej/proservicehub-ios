//
//  ProfileBookingsViewModel.swift
//  Pro Service Hub
//
//  Created by Codex.
//

import Foundation
import Combine

@MainActor
final class ProfileBookingsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var bookings: [CompanyBooking] = []
    @Published var needsLogin = false

    private let session: AppSession
    private let api: LabourLinkAPI

    init(session: AppSession) {
        self.session = session
        self.api = LabourLinkAPI(tokenProvider: { [weak session] in
            session?.token
        })
    }

    func loadCurrentMonth() async {
        guard let userUuid = session.user?.uuid else {
            bookings = []
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)

        do {
            let response = try await api.getUserBookings(userUuid: userUuid, month: month, year: year)
            session.updateToken(response.token)
            if response.responseCode == .tokenExpired {
                handleTokenExpiry(message: response.description)
                return
            }
            if response.didSucceed {
                bookings = response.bookingList ?? []
            } else {
                errorMessage = response.description ?? "Unable to load bookings."
                bookings = []
            }
        } catch {
            errorMessage = error.localizedDescription
            bookings = []
        }
    }

    private func handleTokenExpiry(message: String?) {
        session.clear()
        bookings = []
        errorMessage = message ?? "Session expired. Please log in again."
        needsLogin = true
    }
}
