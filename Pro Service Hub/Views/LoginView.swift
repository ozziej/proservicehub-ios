//
//  LoginView.swift
//  Pro Service Hub
//
//  Created by Codex.
//

import SwiftUI

struct LoginView: View {
    @ObservedObject private var session: AppSession
    @StateObject private var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    init(session: AppSession) {
        self.session = session
        _viewModel = StateObject(wrappedValue: AuthViewModel(session: session))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome back")
                        .font(.title2.weight(.semibold))
                    Text("Log in to book appointments and manage your profile.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 12) {
                    TextField("Email Address", text: $viewModel.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Password", text: $viewModel.password)
                        .textFieldStyle(.roundedBorder)
                }

                if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if viewModel.isLoading {
                    ProgressView()
                }

                Button {
                    Task { await viewModel.login() }
                } label: {
                    Text("Log In")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.emailAddress.isEmpty || viewModel.password.isEmpty || viewModel.isLoading)

                NavigationLink("Create an account", destination: CreateAccountView(session: session))
                    .font(.subheadline)
                    .padding(.top, 8)

                Spacer()
            }
            .padding()
            .navigationTitle("Login")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: session.user?.uuid ?? "") { _, uuid in
            if !uuid.isEmpty {
                dismiss()
            }
        }
    }
}
