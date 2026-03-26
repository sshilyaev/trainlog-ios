//
//  AddTraineeView.swift
//  TrainLog
//

import SwiftUI

/// Полноэкранный экран «Добавить подопечного»: сверху кнопка «Добавить по коду», ниже список своих профилей подопечного.
struct AddTraineeView: View {
    let coachProfile: Profile
    let myTraineeProfiles: [Profile]
    let linkedTraineeIds: Set<String>
    let linkService: CoachTraineeLinkServiceProtocol
    let profileService: ProfileServiceProtocol
    let connectionTokenService: ConnectionTokenServiceProtocol
    let onLinkAdded: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var availableProfiles: [Profile] {
        myTraineeProfiles
            .filter { !$0.isManaged } // managed создаются через отдельный сценарий ниже
            .filter { !linkedTraineeIds.contains($0.id) }
    }

    @State private var errorMessage: String?
    @State private var showCreateManagedTrainee = false
    @State private var showAddByCodeSheet = false
    @State private var showMyProfilesSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SingleContentCard(
                    title: "По коду",
                    description: "Подопечный создаёт временный код в разделе «Подключить по коду» в своём профиле."
                ) {
                    Button {
                        showAddByCodeSheet = true
                    } label: {
                        WideActionButtonToOneColumn(
                            icon: "key-left",
                            title: "Добавить по коду",
                            subtitle: "",
                            showChevron: true,
                            iconColor: AppColors.accent
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                }

                SingleContentCard(
                    title: "Без приложения",
                    description: "Если клиент не хочет устанавливать приложение, вы можете создать его профиль и вести учёт. Позже этот профиль можно будет объединить с реальным."
                ) {
                    Button {
                        showCreateManagedTrainee = true
                    } label: {
                        WideActionButtonToOneColumn(
                            icon: "plus-square",
                            title: "Создать подопечного вручную",
                            subtitle: "",
                            showChevron: true,
                            iconColor: AppColors.accent
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                }

                SingleContentCard(
                    title: "Мои профили подопечного",
                    description: availableProfiles.isEmpty
                    ? "Все ваши профили подопечного уже добавлены или у вас нет такого профиля."
                    : ""
                ) {
                    Button {
                        showMyProfilesSheet = true
                    } label: {
                        WideActionButtonToOneColumn(
                            icon: "user-default",
                            title: "Выбрать из моих профилей",
                            subtitle: availableProfilesSubtitle,
                            showChevron: true,
                            iconColor: AppColors.accent
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(availableProfiles.isEmpty)
                }

                if let msg = errorMessage, !msg.isEmpty {
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(AppColors.destructive)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }
            }
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .background(AppColors.systemGroupedBackground)
        .navigationTitle("Добавить подопечного")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackToolbarButton(action: { dismiss() })
            }
        }
        .sheet(isPresented: $showCreateManagedTrainee) {
            CreateManagedTraineeSheet(
                coachProfile: coachProfile,
                profileService: profileService,
                linkService: linkService,
                onCreated: {
                    showCreateManagedTrainee = false
                    dismiss()
                    onLinkAdded()
                },
                onCancel: { showCreateManagedTrainee = false },
                onError: { errorMessage = $0 }
            )
            .presentationDetents(AppSheetDetents.mediumOnly)
        }
        .sheet(isPresented: $showAddByCodeSheet) {
            AddByTokenSheet(
                coachProfile: coachProfile,
                tokenService: connectionTokenService,
                linkService: linkService,
                profileService: profileService,
                onLinkAdded: {
                    showAddByCodeSheet = false
                    dismiss()
                    onLinkAdded()
                },
                onDismiss: { showAddByCodeSheet = false }
            )
            .presentationDetents(AppSheetDetents.mediumOnly)
        }
        .sheet(isPresented: $showMyProfilesSheet) {
            AddFromMyProfilesSheet(
                profiles: availableProfiles,
                coachProfileId: coachProfile.id,
                linkService: linkService,
                onLinkAdded: {
                    showMyProfilesSheet = false
                    dismiss()
                    onLinkAdded()
                },
                onDismiss: { showMyProfilesSheet = false }
            )
            .presentationDetents(AppSheetDetents.mediumOnly)
        }
    }

    /// Бывшее значение `CardRow.value`: число доступных профилей для привязки.
    private var availableProfilesSubtitle: String {
        let n = availableProfiles.count
        guard n > 0 else { return "" }
        return "Доступно: \(n)"
    }
}

private struct CreateManagedTraineeSheet: View {
    let coachProfile: Profile
    let profileService: ProfileServiceProtocol
    let linkService: CoachTraineeLinkServiceProtocol
    let onCreated: () -> Void
    let onCancel: () -> Void
    let onError: (String) -> Void

    @State private var name = ""
    @State private var gender: ProfileGender? = .male
    @State private var dateOfBirth: Date? = nil
    @State private var phoneNumber = ""
    @State private var telegramUsername = ""
    @State private var notes = ""
    @State private var weight = ""
    @State private var isSaving = false
    @State private var showDatePickerSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    SettingsCard(title: "Основное") {
                        VStack(spacing: 0) {
                            FormRowTextField(icon: "writing-sign", title: "Имя", placeholder: "Имя подопечного", text: $name, textContentType: .name, autocapitalization: .words)
                            FormSectionDivider()
                            FormRow(icon: "user-default", title: "Пол") {
                                Picker("", selection: Binding(
                                    get: { gender ?? .male },
                                    set: { gender = $0 }
                                )) {
                                    Text("Муж").tag(ProfileGender.male)
                                    Text("Жен").tag(ProfileGender.female)
                                }
                                .pickerStyle(.segmented)
                            }
                            FormSectionDivider()
                            FormRowTextField(
                                icon: "pencil-scale",
                                title: "Вес",
                                placeholder: "кг",
                                text: $weight,
                                autocapitalization: .never,
                                keyboardType: .decimalPad
                            )
                        }
                    }

                    SettingsCard(title: "Контакты") {
                        VStack(spacing: 0) {
                            FormRowPhone(icon: "phone", title: "Телефон", text: $phoneNumber)
                            FormSectionDivider()
                            FormRowTextField(icon: "send-plane-horizontal", title: "Telegram", placeholder: "Логин без @", text: $telegramUsername, textContentType: .username, autocapitalization: .never)
                        }
                    }

                    SettingsCard(title: "Дата рождения") {
                        FormRowDateOfBirth(selection: $dateOfBirth, onTap: { showDatePickerSheet = true })
                    }
                    .sheet(isPresented: $showDatePickerSheet) {
                        FormDatePickerSheet(selection: $dateOfBirth, isPresented: $showDatePickerSheet, title: "Дата рождения")
                    }

                    FormNotesCard(notes: $notes)
                }
                .padding(.top, 8)
                .padding(.bottom, AppDesign.sectionSpacing)
            }
            .background(AppColors.systemGroupedBackground)
            .navigationTitle("Создать подопечного")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    BackToolbarButton(action: onCancel)
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "Создаю…" : "Создать") { create() }
                        .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func create() {
        isSaving = true
        Task {
            do {
                let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                let phone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                let telegram = telegramUsername.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: "@", with: "")
                let notesTrimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                let weightValue = parsedPositiveDouble(weight)
                let managed = Profile(
                    id: "",
                    userId: coachProfile.userId,
                    type: .trainee,
                    name: trimmedName,
                    createdAt: Date(),
                    gender: gender,
                    dateOfBirth: dateOfBirth,
                    iconEmoji: nil,
                    phoneNumber: phone.isEmpty ? nil : (PhoneFormatter.isValid(phone) ? phone : nil),
                    telegramUsername: telegram.isEmpty ? nil : telegram,
                    notes: notesTrimmed.isEmpty ? nil : notesTrimmed,
                    ownerCoachProfileId: coachProfile.id,
                    mergedIntoProfileId: nil,
                    weight: weightValue
                )
                let created = try await profileService.createProfile(managed, name: trimmedName)
                try await linkService.addLink(
                    coachProfileId: coachProfile.id,
                    traineeProfileId: created.id,
                    displayName: nil
                )
                await MainActor.run {
                    isSaving = false
                    AppDesign.triggerSuccessHaptic()
                    ToastCenter.shared.success("Подопечный создан")
                    onCreated()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    ToastCenter.shared.error(from: error, fallback: "Не удалось создать подопечного")
                    if let msg = AppErrors.userMessageIfNeeded(for: error) { onError(msg) }
                }
            }
        }
    }

    private func parsedPositiveDouble(_ text: String) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ").")
        guard let value = Double(normalized), value > 0 else { return nil }
        return value
    }
}

/// Выезжающий снизу список «Мои профили подопечного» для выбора профиля и привязки к тренеру.
struct AddFromMyProfilesSheet: View {
    let profiles: [Profile]
    let coachProfileId: String
    let linkService: CoachTraineeLinkServiceProtocol
    let onLinkAdded: () -> Void
    let onDismiss: () -> Void

    @State private var selectedProfile: Profile?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if profiles.isEmpty {
                        ContentUnavailableView(
                            "Нет профилей",
                            image: "tabler-outline-user",
                            description: Text("Все ваши профили подопечного уже добавлены или у вас нет такого профиля.")
                        )
                        .padding(.vertical, 32)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(profiles) { p in
                                Button {
                                    selectedProfile = p
                                } label: {
                                    ProfileRow(profile: p, showTypeLabel: false)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(PressableButtonStyle())
                            }
                        }
                        .padding(.horizontal, AppDesign.cardPadding)
                        .padding(.top, AppDesign.blockSpacing)
                    }
                }
                .padding(.bottom, AppDesign.sectionSpacing)
            }
            .background(AppColors.systemGroupedBackground)
            .navigationTitle("Мои профили")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    BackToolbarButton(action: onDismiss)
                }
            }
            .navigationDestination(item: $selectedProfile) { p in
                TraineeLinkFormView(
                    trainee: p,
                    coachProfileId: coachProfileId,
                    linkService: linkService,
                    tokenService: nil,
                    pendingToken: nil,
                    onLinkAdded: {
                        selectedProfile = nil
                        onLinkAdded()
                    },
                    onDismiss: { selectedProfile = nil }
                )
            }
        }
    }
}

