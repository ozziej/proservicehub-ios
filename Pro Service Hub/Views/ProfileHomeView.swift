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
    @StateObject private var contributionsViewModel: ContributionStatsViewModel

    init(session: AppSession) {
        self.session = session
        _bookingsViewModel = StateObject(wrappedValue: ProfileBookingsViewModel(session: session))
        _contributionsViewModel = StateObject(wrappedValue: ContributionStatsViewModel(session: session))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if session.isAuthenticated, let user = session.user {
                        profileSummary(user)

                        contributionsSection

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
                await contributionsViewModel.loadStats()
            }
        }
        .onChange(of: session.user?.uuid ?? "") { _, uuid in
            if !uuid.isEmpty {
                Task {
                    await bookingsViewModel.loadCurrentMonth()
                    await contributionsViewModel.loadStats()
                }
            } else {
                bookingsViewModel.bookings = []
                contributionsViewModel.stats = nil
            }
        }
        .onChange(of: bookingsViewModel.needsLogin) { _, needsLogin in
            if needsLogin {
                bookingsViewModel.needsLogin = false
                isShowingLogin = true
            }
        }
        .onChange(of: contributionsViewModel.needsLogin) { _, needsLogin in
            if needsLogin {
                contributionsViewModel.needsLogin = false
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

    private var contributionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Contributions")
                        .font(.headline)
                    Text("Badges, trophies, and ranking highlights.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "trophy.fill")
                    .foregroundStyle(.orange)
            }

            if contributionsViewModel.isLoading {
                ProgressView()
            } else if let error = contributionsViewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            } else if contributionsViewModel.stats != nil {
                rankingsView()
                badgesView()
                trophiesView()
                if !contributionsViewModel.hasAnyRank {
                    Label("Add a company or rate one to earn badges.", systemImage: "bolt.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No contribution data available yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    @ViewBuilder
    private func rankingsView() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rankings")
                .font(.subheadline.weight(.semibold))

            if contributionsViewModel.orderedPlacements.isEmpty {
                Text("No rankings yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(contributionsViewModel.orderedPlacements) { placement in
                    let meta = categoryMeta(for: placement.category)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label(meta.label, systemImage: meta.icon)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(rankLabel(for: placement.rank))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(placement.rank == nil ? .secondary : .primary)
                        }
                        Text(rankDetail(for: placement))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
                }
            }
        }
    }

    @ViewBuilder
    private func badgesView() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Badges")
                .font(.subheadline.weight(.semibold))

            if contributionsViewModel.orderedBadges.isEmpty {
                Text("No badges yet. Keep contributing to unlock them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(contributionsViewModel.orderedBadges) { badge in
                        badgeChip(for: badge)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func trophiesView() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trophies")
                .font(.subheadline.weight(.semibold))

            if contributionsViewModel.orderedAwards.isEmpty {
                Text("No trophies yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(contributionsViewModel.orderedAwards) { award in
                        Label(award.title, systemImage: "trophy.fill")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color(.systemBackground)))
                    }
                }
            }
        }
    }

    private func badgeChip(for badge: ContributionBadge) -> some View {
        let meta = categoryMeta(for: badge.category)
        let icon = badge.type.uppercased() == "RANK" ? "crown.fill" : "bolt.fill"
        return Label(badge.label, systemImage: icon)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(meta.tint.opacity(0.15)))
            .foregroundStyle(meta.tint)
    }

    private func categoryMeta(for category: String) -> (label: String, icon: String, tint: Color) {
        switch category.lowercased() {
        case "creator":
            return ("Creator", "building.2.fill", .green)
        case "reviewer":
            return ("Reviewer", "star.fill", .orange)
        default:
            return ("Overall", "chart.bar.fill", .blue)
        }
    }

    private func rankLabel(for rank: Int?) -> String {
        guard let rank else { return "--" }
        return "#\(rank)"
    }

    private func rankDetail(for placement: ContributionPlacement) -> String {
        guard placement.rank != nil, let total = placement.totalParticipants, total > 0 else {
            return "No contributions yet."
        }
        return "Out of \(total) contributors"
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}
