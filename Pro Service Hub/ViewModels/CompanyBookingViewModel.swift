//
//  CompanyBookingViewModel.swift
//  Pro Service Hub
//
//  Created by Codex.
//

import Foundation
import Combine

@MainActor
final class CompanyBookingViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var userBookings: [CompanyBooking] = []
    @Published var selectedBooking: CompanyBooking?
    @Published var selectedDate: Date = Date()
    @Published var selectedTime: Date = Date() {
        didSet {
            guard !isRoundingTime else { return }
            isRoundingTime = true
            selectedTime = Self.roundedToQuarterHour(selectedTime)
            isRoundingTime = false
        }
    }

    private let companyUuid: String
    private let session: AppSession
    private let api: LabourLinkAPI
    private var isRoundingTime = false
    @Published var needsLogin = false

    init(companyUuid: String, session: AppSession) {
        self.companyUuid = companyUuid
        self.session = session
        self.api = LabourLinkAPI(tokenProvider: { [weak session] in
            session?.token
        })
        let now = Date()
        isRoundingTime = true
        self.selectedTime = Self.roundedToQuarterHour(now)
        isRoundingTime = false
    }

    func loadUserBookings() async {
        guard let userUuid = session.user?.uuid else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await api.getUserCompanyBookings(userUuid: userUuid, companyUuid: companyUuid)
            session.updateToken(response.token)
            if response.responseCode == .tokenExpired {
                handleTokenExpiry(message: response.description)
                return
            }
            if response.didSucceed {
                userBookings = response.bookingList ?? []
            } else {
                errorMessage = response.description ?? "Unable to load bookings."
                userBookings = []
            }
        } catch {
            if session.handleUnauthorized(error) {
                handleTokenExpiry(message: nil)
                return
            }
            errorMessage = error.localizedDescription
            userBookings = []
        }
    }

    func createBooking() async {
        guard let userUuid = session.user?.uuid else { return }
        let bookingTime = combinedDateTime()
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let request = BookingRequest(bookingUuid: nil,
                                         userUuid: userUuid,
                                         companyUuid: companyUuid,
                                         bookingTime: bookingTime)
            let response = try await api.createBooking(request)
            session.updateToken(response.token)
            if response.responseCode == .tokenExpired {
                handleTokenExpiry(message: response.description)
                return
            }
            if response.didSucceed {
                await loadUserBookings()
                selectedBooking = nil
            } else {
                errorMessage = response.description ?? "Unable to create booking."
            }
        } catch {
            if session.handleUnauthorized(error) {
                handleTokenExpiry(message: nil)
                return
            }
            errorMessage = error.localizedDescription
        }
    }

    func updateBooking() async {
        guard let userUuid = session.user?.uuid, let booking = selectedBooking else { return }
        let bookingTime = combinedDateTime()
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let request = BookingRequest(bookingUuid: booking.uuid,
                                         userUuid: userUuid,
                                         companyUuid: companyUuid,
                                         bookingTime: bookingTime)
            let response = try await api.updateBooking(request)
            session.updateToken(response.token)
            if response.responseCode == .tokenExpired {
                handleTokenExpiry(message: response.description)
                return
            }
            if response.didSucceed {
                await loadUserBookings()
                selectedBooking = nil
            } else {
                errorMessage = response.description ?? "Unable to update booking."
            }
        } catch {
            if session.handleUnauthorized(error) {
                handleTokenExpiry(message: nil)
                return
            }
            errorMessage = error.localizedDescription
        }
    }

    func deleteBooking(_ booking: CompanyBooking) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await api.deleteBooking(bookingUuid: booking.uuid)
            session.updateToken(response.token)
            if response.responseCode == .tokenExpired {
                handleTokenExpiry(message: response.description)
                return
            }
            if response.didSucceed {
                await loadUserBookings()
                if selectedBooking?.uuid == booking.uuid {
                    selectedBooking = nil
                }
            } else {
                errorMessage = response.description ?? "Unable to cancel booking."
            }
        } catch {
            if session.handleUnauthorized(error) {
                handleTokenExpiry(message: nil)
                return
            }
            errorMessage = error.localizedDescription
        }
    }

    func prepareEdit(for booking: CompanyBooking) {
        selectedBooking = booking
        selectedDate = booking.bookingTime
        selectedTime = Self.roundedToQuarterHour(booking.bookingTime)
    }

    func clearSelection() {
        selectedBooking = nil
    }

    private func combinedDateTime() -> Date {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: Self.roundedToQuarterHour(selectedTime))
        return calendar.date(bySettingHour: timeComponents.hour ?? 0,
                             minute: timeComponents.minute ?? 0,
                             second: 0,
                             of: selectedDate) ?? selectedDate
    }

    private static func roundedToQuarterHour(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let minute = components.minute ?? 0
        let roundedMinute = Int((Double(minute) / 15.0).rounded() * 15)
        var rounded = components
        if roundedMinute == 60 {
            rounded.minute = 0
            if let baseDate = calendar.date(from: components) {
                return calendar.date(byAdding: .hour, value: 1, to: baseDate) ?? date
            }
            return date
        }
        rounded.minute = roundedMinute
        rounded.second = 0
        return calendar.date(from: rounded) ?? date
    }

    private func handleTokenExpiry(message: String?) {
        session.clear()
        userBookings = []
        errorMessage = message ?? "Session expired. Please log in again."
        needsLogin = true
    }
}
