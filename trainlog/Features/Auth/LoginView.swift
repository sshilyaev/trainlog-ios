//
//  LoginView.swift
//  TrainLog
//

import SwiftUI

private let authBorderStart = Color(red: 74/255, green: 172/255, blue: 144/255)
private let authBorderEnd = Color(red: 79/255, green: 84/255, blue: 171/255)

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    var onSignIn: (String, String) async throws -> Void
    var onSignUp: () -> Void

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: AppDesign.sectionSpacing) {
                    Image("AuthTopIllustration")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 230)
                        .padding(.top, 8)
                        .padding(.bottom, 2)

                    Text("Вход")
                        .appTypography(.screenTitle)

                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .authInputStyle()

                    PasswordField(title: "Пароль", text: $password, textContentType: .password)

                    Button {
                        Task { await signIn() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("Войти")
                                .appTypography(.button)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: AppDesign.minTouchTarget)
                        .background(
                            LinearGradient(
                                colors: [authBorderStart, authBorderEnd],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                    }
                    .buttonStyle(PressableButtonStyle(cornerRadius: 12))
                    .disabled(isLoading || email.isEmpty || password.isEmpty)

                    if let msg = errorMessage {
                        Text(msg)
                            .appTypography(.caption)
                            .foregroundStyle(AppColors.destructive)
                            .multilineTextAlignment(.center)
                    }

                    Button("Нет аккаунта? Регистрация", action: onSignUp)
                        .appTypography(.secondary)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 400)
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
                .padding(.bottom, 40)
                .frame(minHeight: geo.size.height, alignment: .top)
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
        }
        .onChange(of: email) { _, _ in errorMessage = nil }
        .onChange(of: password) { _, _ in errorMessage = nil }
        .trackAPIScreen("Вход")
    }

    private func signIn() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await onSignIn(email, password)
            await MainActor.run { ToastCenter.shared.success("Вход выполнен") }
        } catch {
            await MainActor.run {
                ToastCenter.shared.error(from: error, fallback: "Не удалось войти")
                if let msg = AppErrors.userMessageIfNeeded(for: error) { errorMessage = msg }
            }
        }
    }
}

private extension View {
    func authInputStyle() -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [authBorderStart, authBorderEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.4
                    )
            )
    }
}

#Preview {
    LoginView(
        onSignIn: { _, _ in },
        onSignUp: {}
    )
}
