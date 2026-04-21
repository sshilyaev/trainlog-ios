//
//  RegisterView.swift
//  TrainLog
//

import SwiftUI

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
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                        .frame(minHeight: 40)

                    VStack(spacing: AppDesign.sectionSpacing) {
                        Text("Регистрация")
                            .appTypography(.screenTitle)

                        profileTypePicker

                        genderPicker

                        TextField("Имя", text: $displayName)
                            .textContentType(.name)
                            .textFieldStyle(.roundedBorder)

                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)

                        PasswordField(title: "Пароль", text: $password, textContentType: .newPassword)

                        MainActionButton(
                            title: "Создать аккаунт",
                            isLoading: isLoading,
                            isDisabled: email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || password.isEmpty
                                || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                            action: { Task { await signUp() } }
                        )

                        Button("Уже есть аккаунт? Войти", action: onBack)
                            .appTypography(.secondary)
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: 400)

                    Spacer(minLength: 0)
                        .frame(minHeight: 40)
                }
                .frame(minHeight: geo.size.height)
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
                        colors: [AppColors.accent, AppColors.accent.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                : AnyView(AppColors.secondarySystemGroupedBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? AppColors.accent.opacity(0.9) : AppColors.clear, lineWidth: 1)
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

#Preview {
    RegisterView(onSignUp: { _, _, _, _, _ in }, onBack: {})
}
