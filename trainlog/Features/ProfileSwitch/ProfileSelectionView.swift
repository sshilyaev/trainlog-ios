//
//  ProfileSelectionView.swift
//  TrainLog
//

import SwiftUI
import UIKit

struct ProfileSelectionView: View {
    let profiles: [Profile]
    let authService: AuthServiceProtocol
    let profileService: ProfileServiceProtocol
    let supportCampaignService: SupportCampaignServiceProtocol
    let rewardedAdService: RewardedAdServiceProtocol
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
                    profilesSection
                }
                .padding(.vertical, AppDesign.blockSpacing)
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .background(AppColors.systemGroupedBackground)
            .navigationTitle("Мои профили")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .destructive) {
                        showSignOutConfirmation = true
                    } label: {
                        AppTablerIcon("log-out-right")
                            .appTypography(.secondary)
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
        HeroCard(
            icon: "user-circle",
            title: "Аккаунт",
            headline: displayName,
            description: authService.currentUserEmail ?? ""
        ) {
            VStack(spacing: 10) {
                Button {
                    showChangePasswordSheet = true
                } label: {
                    HStack(spacing: 8) {
                        AppTablerIcon("lock-close")
                        Text("Сменить пароль")
                    }
                    .appTypography(.bodyEmphasis)
                    .foregroundStyle(AppColors.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 46)
                    .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(PressableButtonStyle(cornerRadius: 10))

                NavigationLink {
                    AppSettingsView(
                        showsDeveloperSettings: false,
                        supportCampaignService: supportCampaignService,
                        rewardedAdService: rewardedAdService
                    )
                } label: {
                    HStack(spacing: 8) {
                        AppTablerIcon("settings")
                        Text("Настройки")
                    }
                    .appTypography(.bodyEmphasis)
                    .foregroundStyle(AppColors.accent)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 46)
                    .background(
                        AppColors.secondarySystemGroupedBackground.opacity(0.85),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(AppColors.accent.opacity(0.35), lineWidth: 1)
                    )
                }
                .buttonStyle(PressableButtonStyle(cornerRadius: 10))
            }
        }
        .padding(.horizontal, AppDesign.cardPadding)
    }

    private var profilesSection: some View {
        let coaches = selectableProfiles.filter(\.isCoach)
        let trainees = selectableProfiles.filter(\.isTrainee)

        return VStack(alignment: .leading, spacing: 12) {
            if selectableProfiles.isEmpty {
                VStack(spacing: 16) {
                    quickAddProfileBlock(title: "Создать первый профиль")
                }
            } else {
                if !coaches.isEmpty {
                    Text("Тренерские профили")
                        .appTypography(.bodyEmphasis)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, AppDesign.cardPadding)
                    profileList(for: coaches)
                }
                if !trainees.isEmpty {
                    Text("Дневники")
                        .appTypography(.bodyEmphasis)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, AppDesign.cardPadding)
                        .padding(.top, coaches.isEmpty ? 0 : 8)
                    profileList(for: trainees)
                }
                quickAddProfileBlock(title: "Быстрое добавление профиля")
            }
        }
        .padding(.top, AppDesign.sectionSpacing)
    }

    private func quickAddProfileBlock(title: String) -> some View {
        VStack(spacing: 16) {
            SettingsCard(title: title) {
                VStack(spacing: 12) {
                    HStack(spacing: AppDesign.rectangularBlockSpacing) {
                        quickTypeTile(type: .trainee, icon: "note.text", title: "Дневник", description: "Замеры, цели и календарь.")
                        quickTypeTile(type: .coach, icon: "figure.strengthtraining.traditional", title: "Тренер", description: "Клиенты, абонементы, посещения.")
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

            MainActionButton(
                title: "Создать профиль",
                isLoading: isQuickCreating,
                isDisabled: quickName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                action: { Task { await quickCreateProfile() } }
            )
            .padding(.horizontal, AppDesign.cardPadding)

            if let msg = quickCreateError, !msg.isEmpty {
                Text(msg)
                    .appTypography(.caption)
                    .foregroundStyle(AppColors.destructive)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppDesign.cardPadding)
            }
        }
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
        let tileTint = type == .trainee ? AppColors.logoTeal : AppColors.logoViolet
        return Button {
            quickType = type
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                AppTablerIcon(icon)
                    .appTypography(.screenTitle)
                    .foregroundStyle(isSelected ? tileTint : AppColors.accent)
                Text(title)
                    .appTypography(.bodyEmphasis)
                    .foregroundStyle(.primary)
                Text(description)
                    .appTypography(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AppDesign.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.secondarySystemGroupedBackground)
            .overlay(
                RoundedRectangle(cornerRadius: AppDesign.cornerRadius)
                    .stroke(isSelected ? tileTint.opacity(0.95) : AppColors.separator.opacity(0.35), lineWidth: isSelected ? 1.2 : 0.8)
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
                    VStack(alignment: .leading, spacing: 12) {
                        HeroCard(
                            icon: "lock-close",
                            title: "Безопасность",
                            headline: "Минимум 6 символов",
                            description: "",
                            accent: AppColors.visitsOneTimeDebt
                        )
                        .padding(.horizontal, AppDesign.cardPadding)

                        SettingsCard(title: "Пароль") {
                            VStack(spacing: 10) {
                                passwordRow(title: "Текущий", text: $currentPassword, contentType: .password)
                                FormSectionDivider()
                                passwordRow(title: "Новый", text: $newPassword, contentType: .newPassword)
                                FormSectionDivider()
                                passwordRow(title: "Повтор", text: $confirmPassword, contentType: .newPassword)
                            }
                        }

                        if !newPassword.isEmpty && newPassword != confirmPassword {
                            Text("Пароли не совпадают")
                                .appTypography(.caption)
                                .foregroundStyle(AppColors.destructive)
                                .padding(.horizontal, AppDesign.cardPadding)
                        } else if !newPassword.isEmpty && newPassword.count < 6 {
                            Text("Пароль должен быть не короче 6 символов")
                                .appTypography(.caption)
                                .foregroundStyle(AppColors.destructive)
                                .padding(.horizontal, AppDesign.cardPadding)
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, AppDesign.sectionSpacing)
                }
                .background(AppColors.systemGroupedBackground)
                .scrollDismissesKeyboard(.interactively)
                .dismissKeyboardOnTap()
            }
        )
    }

    private func passwordRow(
        title: String,
        text: Binding<String>,
        contentType: UITextContentType
    ) -> some View {
        FormRow(icon: "lock-close", title: title) {
            PasswordField(
                title: "Введите",
                text: text,
                textContentType: contentType
            )
            .frame(maxWidth: 190)
        }
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
        supportCampaignService: MockSupportCampaignService(),
        rewardedAdService: DevMockRewardedAdService(),
        accountDisplayName: "Сергей",
        onSelect: { _ in },
        onCreate: {},
        onSignOut: {},
        onQuickCreate: { _, _, _ in }
    )
}
