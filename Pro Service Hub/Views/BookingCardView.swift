//
//  BookingCardView.swift
//  Pro Service Hub
//
//  Created by Codex.
//

import SwiftUI

struct BookingCardView: View {
    @ObservedObject var viewModel: CompanyBookingViewModel
    let companyName: String
    @State private var bookingPendingCancel: CompanyBooking?
    @State private var isShowingCancelConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Book an appointment")
                .font(.headline)

            DatePicker("Date", selection: $viewModel.selectedDate, in: Date()..., displayedComponents: .date)
                .datePickerStyle(.compact)

            Picker("Time", selection: $viewModel.selectedTime) {
                ForEach(timeOptions, id: \.self) { option in
                    Text(timeFormatter.string(from: option)).tag(option)
                }
            }
            .pickerStyle(.wheel)

            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }

            if viewModel.isLoading {
                ProgressView()
            }

            HStack {
                Button(viewModel.selectedBooking == nil ? "Schedule" : "Update Booking") {
                    Task {
                        if viewModel.selectedBooking == nil {
                            await viewModel.createBooking()
                        } else {
                            await viewModel.updateBooking()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)

                if viewModel.selectedBooking != nil {
                    Button("Cancel Edit") {
                        viewModel.clearSelection()
                    }
                    .buttonStyle(.bordered)
                }
            }

            Divider()

            Text("Your bookings with \(companyName)")
                .font(.subheadline.weight(.semibold))

            if viewModel.userBookings.isEmpty {
                Text("No upcoming bookings yet.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.userBookings.sorted(by: { $0.bookingTime < $1.bookingTime })) { booking in
                        bookingRow(booking)
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        .task {
            await viewModel.loadUserBookings()
        }
        .onChange(of: viewModel.selectedDate) { _, newValue in
            let calendar = Calendar.current
            if calendar.isDateInToday(newValue) {
                viewModel.selectedTime = roundedToQuarterHour(Date())
            } else {
                let timeComponents = calendar.dateComponents([.hour, .minute], from: viewModel.selectedTime)
                viewModel.selectedTime = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                                       minute: timeComponents.minute ?? 0,
                                                       second: 0,
                                                       of: newValue) ?? newValue
            }
        }
        .confirmationDialog("Cancel this booking?",
                            isPresented: $isShowingCancelConfirmation,
                            titleVisibility: .visible) {
            Button("Cancel Booking", role: .destructive) {
                if let bookingPendingCancel {
                    Task { await viewModel.deleteBooking(bookingPendingCancel) }
                }
                bookingPendingCancel = nil
            }
            Button("Keep Booking", role: .cancel) {
                bookingPendingCancel = nil
            }
        } message: {
            Text("This will cancel the appointment and cannot be undone.")
        }
    }

    @ViewBuilder
    private func bookingRow(_ booking: CompanyBooking) -> some View {
        let isCancelled = booking.status == .cancelled
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dateFormatter.string(from: booking.bookingTime))
                    .font(.subheadline.weight(.semibold))
                Text(timeFormatter.string(from: booking.bookingTime))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(booking.status.rawValue.capitalized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 6) {
                Button("Edit") {
                    viewModel.prepareEdit(for: booking)
                }
                .buttonStyle(.bordered)
                .disabled(isCancelled)

                Button(role: .destructive) {
                    bookingPendingCancel = booking
                    isShowingCancelConfirmation = true
                } label: {
                    Text("Cancel")
                }
                .buttonStyle(.bordered)
                .disabled(isCancelled)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }

    private var timeOptions: [Date] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: viewModel.selectedDate)
        let startDate: Date
        if calendar.isDateInToday(viewModel.selectedDate) {
            startDate = max(roundedToQuarterHour(Date()), startOfDay)
        } else {
            startDate = startOfDay
        }
        let startMinutes = calendar.dateComponents([.minute], from: startOfDay, to: startDate).minute ?? 0
        return stride(from: startMinutes, to: 24 * 60, by: 15).compactMap { minutes in
            calendar.date(byAdding: .minute, value: minutes, to: startOfDay)
        }
    }

    private func roundedToQuarterHour(_ date: Date) -> Date {
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
}
