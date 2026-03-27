//
//  ProfileSelectionView.swift
//  TrainLog
//

import SwiftUI

struct ProfileSelectionView: View {
    let profiles: [Profile]
    let authService: AuthServiceProtocol
    let profileService: ProfileServiceProtocol
    /// Отображаемое имя пользователя (displayName или email из Auth). Если не задано — берётся из authService.
    var accountDisplayName: String? = nil
    let onSelect: (Profile) -> Void
    let onCreate: () -> Void
    let onSignOut: () -> Void
    /// Быстрое создание профиля прямо на экране (когда список пуст).
    let onQuickCreate: (ProfileType, ProfileGender?, String) async throws -> Void

    @State private var passwordResetMessage: String?
    @State private var passwordResetError: String?
    @State private var showChangePasswordSheet = false
    @State private var showSignOutConfirmation = false
    @AppStorage("appTheme") private var appThemeRaw = AppTheme.system.rawValue
    @State private var quickType: ProfileType = .trainee
    @State private var quickGender: ProfileGender? = .male
    @State private var quickName: String = ""
    @State private var isQuickCreating = false
    @State private var quickCreateError: String?

    /// Managed-профили не показываются в списке профилей.
    private var selectableProfiles: [Profile] {
        profiles.filter { !$0.isManaged }
    }

    private var displayName: String {
        if let explicit = accountDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !explicit.isEmpty {
            return explicit
        }
        return authService.currentUserDisplayName ?? authService.currentUserEmail ?? "Аккаунт"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    accountHeader
                    themeSection
                    profilesSection
                }
                .padding(.vertical, AppDesign.blockSpacing)
            }
            .background(AppColors.systemGroupedBackground)
            .navigationTitle("Мои профили")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .destructive) {
                        showSignOutConfirmation = true
                    } label: {
                        AppTablerIcon("log-out-right")
                            .font(.subheadline)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onCreate()
                    } label: {
                        AppTablerIcon("plus-square")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
            .appConfirmationDialog(
                title: "Выйти из аккаунта?",
                message: "Вы всегда сможете войти снова",
                isPresented: $showSignOutConfirmation,
                confirmTitle: "Выйти",
                confirmRole: .destructive,
                onConfirm: {
                    showSignOutConfirmation = false
                    onSignOut()
                },
                onCancel: {
                    showSignOutConfirmation = false
                }
            )
            .appConfirmationDialog(
                title: "Сменить пароль",
                message: passwordResetMessage ?? "",
                isPresented: Binding(
                    get: { passwordResetMessage != nil },
                    set: { if !$0 { passwordResetMessage = nil } }
                ),
                confirmTitle: "OK",
                onConfirm: { passwordResetMessage = nil },
                onCancel: { passwordResetMessage = nil }
            )
            .appConfirmationDialog(
                title: "Ошибка",
                message: passwordResetError ?? "Произошла ошибка.",
                isPresented: Binding(
                    get: { passwordResetError != nil },
                    set: { if !$0 { passwordResetError = nil } }
                ),
                confirmTitle: "OK",
                onConfirm: { passwordResetError = nil },
                onCancel: { passwordResetError = nil }
            )
            .sheet(isPresented: $showChangePasswordSheet) {
                ChangePasswordSheet(
                    authService: authService,
                    onSuccess: {
                        showChangePasswordSheet = false
                        passwordResetMessage = "Пароль изменён"
                        ToastCenter.shared.success("Пароль изменен")
                    },
                    onError: {
                        passwordResetError = $0
                        ToastCenter.shared.error($0)
                    },
                    onCancel: { showChangePasswordSheet = false }
                )
                .mainSheetPresentation(.half)
            }
        }
        .trackAPIScreen("Выбор профиля")
    }

    // MARK: - Sections

    private var accountHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let email = authService.currentUserEmail,
                       !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            Button {
                showChangePasswordSheet = true
            } label: {
                WideActionButtonToOneColumn(
                    icon: "lock-close",
                    title: "Сменить пароль",
                    subtitle: "",
                    iconColor: AppColors.secondaryLabel,
                    chevronColor: AppColors.tertiaryLabel
                )
            }
            .buttonStyle(PressableButtonStyle(cornerRadius: AppDesign.cornerRadius))
        }
        .padding(AppDesign.cardPadding)
        .background(
            AppColors.secondarySystemGroupedBackground,
            in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius)
        )
        .padding(.horizontal, AppDesign.cardPadding)
    }

    private var themeSection: some View {
        SettingsCard(title: "Тема оформления") {
            SegmentedPicker(
                title: "",
                selection: $appThemeRaw,
                options: [
                    (AppTheme.light.rawValue, "Светлая"),
                    (AppTheme.dark.rawValue, "Тёмная"),
                    (AppTheme.system.rawValue, "Системная")
                ]
            )
        }
        .padding(.top, AppDesign.blockSpacing)
    }

    private var profilesSection: some View {
        let coaches = selectableProfiles.filter(\.isCoach)
        let trainees = selectableProfiles.filter(\.isTrainee)

        return VStack(alignment: .leading, spacing: 12) {
            if selectableProfiles.isEmpty {
                VStack(spacing: 16) {
                    SettingsCard(title: "Создать первый профиль") {
                        VStack(spacing: 12) {
                            HStack(spacing: AppDesign.rectangularBlockSpacing) {
                                quickTypeTile(type: .trainee, icon: "file-default", title: "Дневник", description: "Замеры, цели и календарь.")
                                quickTypeTile(type: .coach, icon: "user-love-heart", title: "Тренер", description: "Клиенты, абонементы, посещения.")
                            }
                            FormSectionDivider()
                            Picker("", selection: Binding(
                                get: { quickGender ?? .male },
                                set: { quickGender = $0 }
                            )) {
                                Text("Мужчина").tag(ProfileGender.male)
                                Text("Женщина").tag(ProfileGender.female)
                            }
                            .pickerStyle(.segmented)

                            FormRowTextField(
                                icon: "writing-sign",
                                title: "Имя в профиле",
                                placeholder: "Как к вам обращаться",
                                text: $quickName,
                                textContentType: .name,
                                autocapitalization: .words
                            )
                        }
                    }
                    .padding(.horizontal, AppDesign.cardPadding)

                    MainActionButton(
                        title: "Создать профиль",
                        isLoading: isQuickCreating,
                        isDisabled: quickName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        action: { Task { await quickCreateProfile() } }
                    )
                    .padding(.horizontal, AppDesign.cardPadding)

                    if let msg = quickCreateError, !msg.isEmpty {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(AppColors.destructive)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppDesign.cardPadding)
                    }
                }
            } else {
                if !coaches.isEmpty {
                    Text("Тренерские профили")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, AppDesign.cardPadding)
                    profileList(for: coaches)
                }
                if !trainees.isEmpty {
                    Text("Дневники")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, AppDesign.cardPadding)
                        .padding(.top, coaches.isEmpty ? 0 : 8)
                    profileList(for: trainees)
                }
            }
        }
        .padding(.top, AppDesign.sectionSpacing)
    }

    private func profileList(for items: [Profile]) -> some View {
        // Мои профили → Список профилей: ап внут, доун внеш.
        let layout = ActionButtonLayout(
            contentPaddingHorizontal: ActionButtonLayout.wideDefault.contentPaddingHorizontal,
            contentPaddingVertical: ActionButtonLayout.wideDefault.contentPaddingVertical + 4,
            outerPaddingVertical: max(0, ActionButtonLayout.wideDefault.outerPaddingVertical - 3),
            minHeight: ActionButtonLayout.wideDefault.minHeight
        )
        return VStack(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, profile in
                Button {
                    AppDesign.triggerSelectionHaptic()
                    onSelect(profile)
                } label: {
                    WideActionButtonToOneColumn(
                        leading: .avatar(
                            icon: profile.isCoach ? "figure.strengthtraining.traditional" : "note.text",
                            iconColor: AppColors.avatarColor(gender: profile.gender, defaultColor: AppColors.avatarIcon),
                            background: AppColors.avatarBackground,
                            cornerRadius: AppDesign.profileSwitchWideAvatarCornerRadius,
                            sideLength: AppDesign.profileSwitchWideAvatarSide
                        ),
                        title: profile.name,
                        subtitle: profileSubtitle(profile) ?? "",
                        prominentTitle: true,
                        chevronColor: AppColors.secondaryLabel,
                        layout: layout
                    )
                }
                .buttonStyle(PressableButtonStyle(cornerRadius: AppDesign.cornerRadius))
            }
        }
        .padding(.horizontal, AppDesign.cardPadding)
    }

    private func profileSubtitle(_ profile: Profile) -> String? {
        if profile.isCoach {
            if let gym = profile.gymName, !gym.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Тренер · \(gym)"
            }
            return "Тренерский профиль"
        } else {
            return "Дневник"
        }
    }

    private func quickTypeTile(type: ProfileType, icon: String, title: String, description: String) -> some View {
        let isSelected = quickType == type
        return Button {
            quickType = type
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                AppTablerIcon(icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : AppColors.accent)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AppDesign.cardPadding)
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
                RoundedRectangle(cornerRadius: AppDesign.cornerRadius)
                    .stroke(isSelected ? AppColors.accent.opacity(0.9) : AppColors.clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func quickCreateProfile() async {
        guard authService.currentUserId != nil else {
            await MainActor.run { quickCreateError = "Вы не авторизованы. Войдите снова" }
            return
        }
        let nameTrimmed = quickName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nameTrimmed.isEmpty else { return }
        await MainActor.run {
            isQuickCreating = true
            quickCreateError = nil
        }
        defer { Task { @MainActor in isQuickCreating = false } }
        do {
            // Создание через колбэк RootView (он обновит список и выберет профиль).
            try await onQuickCreate(quickType, quickGender, nameTrimmed)
            // Сохраняем имя как дефолт для следующего раза (редко, но удобно).
            await MainActor.run {
                quickName = ""
                ToastCenter.shared.success("Профиль создан")
            }
        } catch {
            await MainActor.run {
                ToastCenter.shared.error(from: error, fallback: "Не удалось создать профиль")
                if let msg = AppErrors.userMessageIfNeeded(for: error) { quickCreateError = msg }
            }
        }
    }
}

// MARK: - Смена пароля в приложении

private struct ChangePasswordSheet: View {
    let authService: AuthServiceProtocol
    let onSuccess: () -> Void
    let onError: (String) -> Void
    let onCancel: () -> Void

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isChanging = false

    private var canSubmit: Bool {
        !currentPassword.isEmpty && newPassword.count >= 6 && newPassword == confirmPassword
    }

    var body: some View {
        MainSheet(
            title: "Сменить пароль",
            onBack: onCancel,
            trailing: {
                if isChanging {
                    ProgressView().scaleEffect(0.9)
                } else {
                    Button {
                        submit()
                    } label: {
                        Text("Изменить")
                            .fontWeight(.regular)
                    }
                    .disabled(!canSubmit)
                    .foregroundStyle(.primary)
                }
            },
            content: {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Обновите пароль для входа в аккаунт. Минимум 6 символов.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, AppDesign.cardPadding)

                        VStack(spacing: 12) {
                            SecureField("Текущий пароль", text: $currentPassword)
                                .textContentType(.password)
                                .padding(12)
                                .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))

                            SecureField("Новый пароль (не менее 6 символов)", text: $newPassword)
                                .textContentType(.newPassword)
                                .padding(12)
                                .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))

                            SecureField("Повторите новый пароль", text: $confirmPassword)
                                .textContentType(.newPassword)
                                .padding(12)
                                .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))

                            if !newPassword.isEmpty && newPassword != confirmPassword {
                                Text("Пароли не совпадают")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.destructive)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else if !newPassword.isEmpty && newPassword.count < 6 {
                                Text("Пароль должен быть не короче 6 символов")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.destructive)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.horizontal, AppDesign.cardPadding)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, AppDesign.sectionSpacing)
                }
                .background(AppColors.systemGroupedBackground)
            }
        )
    }

    private func submit() {
        guard canSubmit else { return }
        isChanging = true
        Task {
            do {
                try await authService.changePassword(currentPassword: currentPassword, newPassword: newPassword)
                await MainActor.run {
                    AppDesign.triggerSuccessHaptic()
                    onSuccess()
                }
            } catch {
                await MainActor.run {
                    if let msg = AppErrors.userMessageIfNeeded(for: error) { onError(msg) }
                }
            }
            await MainActor.run { isChanging = false }
        }
    }
}

// MARK: - Строка профиля (для списков в других экранах)

struct ProfileRow: View {
    let profile: Profile
    /// Если задано, отображается вместо profile.name (для списка подопечных у тренера).
    var displayName: String? = nil
    /// Показывать ли подпись «Тренер»/«Дневник».
    var showTypeLabel: Bool = true

    private var title: String { displayName ?? profile.name }

    /// Строка под заголовком: зал (у тренера), пол.
    private var profileRowSubtitle: String? {
        let parts = [profile.displaySubtitle, profile.gender?.displayName].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        // Мои профили → Список профилей: ап внут, доун внеш.
        let layout = ActionButtonLayout(
            contentPaddingHorizontal: ActionButtonLayout.wideDefault.contentPaddingHorizontal,
            contentPaddingVertical: ActionButtonLayout.wideDefault.contentPaddingVertical + 4,
            outerPaddingVertical: max(0, ActionButtonLayout.wideDefault.outerPaddingVertical - 3),
            minHeight: ActionButtonLayout.wideDefault.minHeight
        )
        WideActionButtonToOneColumn(
            leading: .avatar(
                icon: profile.isCoach ? "figure.strengthtraining.traditional" : "note.text",
                iconColor: AppColors.avatarColor(gender: profile.gender, defaultColor: AppColors.avatarIcon),
                background: AppColors.avatarBackground,
                cornerRadius: AppDesign.profileSwitchWideAvatarCornerRadius,
                sideLength: AppDesign.profileSwitchWideAvatarSide
            ),
            title: title,
            subtitle: [
                profileRowSubtitle,
                (showTypeLabel ? (profile.type == .coach ? "Тренер" : "Дневник") : nil)
            ]
            .compactMap { $0 }
            .joined(separator: " · "),
            prominentTitle: true,
            chevronColor: AppColors.secondaryLabel,
            layout: layout
        )
    }
}

#Preview {
    ProfileSelectionView(
        profiles: [
            Profile(id: "1", userId: "u1", type: .coach, name: "Зал на Арбате", gymName: "Фитнес Арбат"),
            Profile(id: "2", userId: "u1", type: .trainee, name: "Мой дневник")
        ],
        authService: MockAuthService(),
        profileService: MockProfileService(),
        accountDisplayName: "Сергей",
        onSelect: { _ in },
        onCreate: {},
        onSignOut: {},
        onQuickCreate: { _, _, _ in }
    )
}
