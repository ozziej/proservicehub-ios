//
//  CreateAccountView.swift
//  Pro Service Hub
//
//  Created by Codex.
//

import SwiftUI

struct CreateAccountView: View {
    @StateObject private var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    init(session: AppSession) {
        _viewModel = StateObject(wrappedValue: AuthViewModel(session: session))
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Create account")
                    .font(.title2.weight(.semibold))
                Text("We will email you a link to set your password.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                TextField("First Name", text: $viewModel.name)
                    .textInputAutocapitalization(.words)
                    .textFieldStyle(.roundedBorder)
                TextField("Surname", text: $viewModel.surname)
                    .textInputAutocapitalization(.words)
                    .textFieldStyle(.roundedBorder)
                TextField("Email Address", text: $viewModel.emailAddress)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textFieldStyle(.roundedBorder)
                TextField("Cell Phone", text: $viewModel.cellPhone)
                    .keyboardType(.phonePad)
                    .textFieldStyle(.roundedBorder)
            }

            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let success = viewModel.successMessage {
                Label(success, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if viewModel.isLoading {
                ProgressView()
            }

            Button {
                Task { await viewModel.createAccount() }
            } label: {
                Text("Create Account")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.name.isEmpty || viewModel.surname.isEmpty || viewModel.emailAddress.isEmpty || viewModel.cellPhone.isEmpty || viewModel.isLoading)

            Spacer()
        }
        .padding()
        .navigationTitle("Create Account")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
                .disabled(viewModel.isLoading)
            }
        }
    }
}
