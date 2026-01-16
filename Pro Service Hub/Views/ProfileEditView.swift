//
//  ProfileEditView.swift
//  Pro Service Hub
//
//  Created by Codex.
//

import SwiftUI

struct ProfileEditView: View {
    private let session: AppSession
    @StateObject private var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var surname: String
    @State private var email: String
    @State private var cellPhone: String

    init(session: AppSession) {
        self.session = session
        _viewModel = StateObject(wrappedValue: AuthViewModel(session: session))
        let user = session.user
        _name = State(initialValue: user?.name ?? "")
        _surname = State(initialValue: user?.surname ?? "")
        _email = State(initialValue: user?.email ?? "")
        _cellPhone = State(initialValue: user?.cellPhone ?? "")
    }

    var body: some View {
        Form {
            Section("Details") {
                TextField("First Name", text: $name)
                    .textInputAutocapitalization(.words)
                TextField("Surname", text: $surname)
                    .textInputAutocapitalization(.words)
                TextField("Email Address", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                TextField("Cell Phone", text: $cellPhone)
                    .keyboardType(.phonePad)
            }

            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }

            if let success = viewModel.successMessage {
                Label(success, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            Section {
                Button("Save Changes") {
                    Task { await saveProfile() }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .navigationTitle("Edit Profile")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
    }

    private func saveProfile() async {
        guard let user = session.user else { return }
        let updatedUser = User(uuid: user.uuid,
                               username: user.username ?? email,
                               name: name,
                               surname: surname,
                               cellPhone: cellPhone,
                               email: email,
                               statusType: user.statusType,
                               userType: user.userType)
        await viewModel.updateProfile(user: updatedUser)
    }
}
