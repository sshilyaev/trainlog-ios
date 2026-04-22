//
//  RegisterView.swift
//  TrainLog
//

import SwiftUI

private let authBorderStart = Color(red: 74/255, green: 172/255, blue: 144/255)
private let authBorderEnd = Color(red: 79/255, green: 84/255, blue: 171/255)

struct RegisterView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var profileType: ProfileType = .trainee
    @State private var gender: ProfileGender? = .male
    @State private var isLoading = false
    @State private var errorMessage: String?
    var onSignUp: (String, String, String, ProfileType, ProfileGender?) async throws -> Void
    var onBack: () -> Void

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

                    Text("Регистрация")
                        .appTypography(.screenTitle)

                    profileTypePicker

                    genderPicker

                    TextField("Имя", text: $displayName)
                        .textContentType(.name)
                        .authInputStyle()

                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .authInputStyle()

                    PasswordField(title: "Пароль", text: $password, textContentType: .newPassword)

                    Button {
                        Task { await signUp() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("Создать аккаунт")
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
                    .disabled(
                        isLoading
                        || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || password.isEmpty
                        || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )

                    Button("Уже есть аккаунт? Войти", action: onBack)
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
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackToolbarButton(action: onBack)
            }
        }
        .appConfirmationDialog(
            title: "Ошибка регистрации",
            message: errorMessage ?? "Произошла ошибка.",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ),
            confirmTitle: "OK",
            onConfirm: { errorMessage = nil },
            onCancel: { errorMessage = nil }
        )
        .trackAPIScreen("Регистрация")
    }

    private func signUp() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let nameTrimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let emailTrimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if nameTrimmed.isEmpty {
            errorMessage = "Введите имя"
            return
        }
        if emailTrimmed.isEmpty {
            errorMessage = "Введите email"
            return
        }
        if !emailTrimmed.contains("@") {
            errorMessage = "Введите корректный email"
            return
        }
        if password.count < 6 {
            errorMessage = "Пароль должен быть не менее 6 символов"
            return
        }

        do {
            try await onSignUp(nameTrimmed, emailTrimmed, password, profileType, gender)
            await MainActor.run { ToastCenter.shared.success("Аккаунт создан") }
        } catch {
            await MainActor.run {
                ToastCenter.shared.error(from: error, fallback: "Не удалось зарегистрироваться")
                if let msg = AppErrors.userMessageIfNeeded(for: error) { errorMessage = msg }
            }
        }
    }

    private var profileTypePicker: some View {
        HStack(spacing: 12) {
            typeTile(
                type: .trainee,
                icon: "file-default",
                title: "Дневник",
                description: "Для личного прогресса"
            )
            typeTile(
                type: .coach,
                icon: "user-love-heart",
                title: "Тренер",
                description: "Для работы с клиентами"
            )
        }
    }

    private func typeTile(type: ProfileType, icon: String, title: String, description: String) -> some View {
        let isSelected = profileType == type
        return Button {
            profileType = type
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                AppTablerIcon(icon)
                    .appTypography(.numericMetric)
                    .foregroundStyle(isSelected ? .white : AppColors.accent)
                Text(title)
                    .appTypography(.bodyEmphasis)
                    .foregroundStyle(isSelected ? .white : .primary)
                Text(description)
                    .appTypography(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected
                ? AnyView(
                    LinearGradient(
                        colors: [authBorderStart, authBorderEnd],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                : AnyView(AppColors.secondarySystemGroupedBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected
                        ? LinearGradient(
                            colors: [authBorderStart, authBorderEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        : LinearGradient(colors: [AppColors.clear, AppColors.clear], startPoint: .leading, endPoint: .trailing),
                        lineWidth: 1.2
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var genderPicker: some View {
        Picker("", selection: Binding(
            get: { gender ?? .male },
            set: { gender = $0 }
        )) {
            Text("Мужчина").tag(ProfileGender.male)
            Text("Женщина").tag(ProfileGender.female)
        }
        .pickerStyle(.segmented)
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
    RegisterView(onSignUp: { _, _, _, _, _ in }, onBack: {})
}
