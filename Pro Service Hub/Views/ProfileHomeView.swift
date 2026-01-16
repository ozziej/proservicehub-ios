//
//  ProfileHomeView.swift
//  Pro Service Hub
//
//  Created by Codex.
//

import SwiftUI

struct ProfileHomeView: View {
    @ObservedObject private var session: AppSession
    @State private var isShowingLogin = false
    @StateObject private var bookingsViewModel: ProfileBookingsViewModel

    init(session: AppSession) {
        self.session = session
        _bookingsViewModel = StateObject(wrappedValue: ProfileBookingsViewModel(session: session))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if session.isAuthenticated, let user = session.user {
                        profileSummary(user)

                        NavigationLink("Edit Profile", destination: ProfileEditView(session: session))
                            .buttonStyle(.borderedProminent)

                        Button("Log Out", role: .destructive) {
                            session.clear()
                        }
                        .buttonStyle(.bordered)

                        bookingsSection
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Profile")
                                .font(.title2.weight(.semibold))
                            Text("Log in to manage your bookings and details.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Button("Log In or Create Account") {
                            isShowingLogin = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .navigationTitle("Profile")
        }
        .sheet(isPresented: $isShowingLogin) {
            LoginView(session: session)
        }
        .task {
            if session.isAuthenticated {
                await bookingsViewModel.loadCurrentMonth()
            }
        }
        .onChange(of: session.user?.uuid ?? "") { _, uuid in
            if !uuid.isEmpty {
                Task { await bookingsViewModel.loadCurrentMonth() }
            } else {
                bookingsViewModel.bookings = []
            }
        }
        .onChange(of: bookingsViewModel.needsLogin) { _, needsLogin in
            if needsLogin {
                bookingsViewModel.needsLogin = false
                isShowingLogin = true
            }
        }
    }

    private func profileSummary(_ user: User) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(user.name) \(user.surname)")
                .font(.title2.weight(.semibold))
            Label(user.email, systemImage: "envelope.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Label(user.cellPhone, systemImage: "phone.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private var bookingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Bookings")
                .font(.headline)

            if bookingsViewModel.isLoading {
                ProgressView()
            } else if let error = bookingsViewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            } else if bookingsViewModel.bookings.isEmpty {
                Text("No bookings this month.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(bookingsViewModel.bookings.sorted(by: { $0.bookingTime < $1.bookingTime })) { booking in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(booking.company.name)
                                .font(.subheadline.weight(.semibold))
                            Text(dateFormatter.string(from: booking.bookingTime))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(booking.status.rawValue.capitalized)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}
