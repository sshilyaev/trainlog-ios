//
//  EditTraineeSheet.swift
//  TrainLog
//

import SwiftUI

/// Шит редактирования подопечного. Единый дизайн: секции Основное, Контакты, Дата рождения, Заметки, Иконка (у managed).
struct EditTraineeSheet: View {
    let coachProfileId: String
    let link: CoachTraineeLink
    let profile: Profile
    let profileService: ProfileServiceProtocol
    let measurementService: MeasurementServiceProtocol
    let linkService: CoachTraineeLinkServiceProtocol
    let onSaved: (Profile) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var displayName: String
    @State private var dateOfBirth: Date?
    @State private var notes: String
    @State private var gender: ProfileGender?
    @State private var phoneNumber: String
    @State private var telegramUsername: String
    @State private var weight: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showDatePickerSheet = false

    private var isManaged: Bool { profile.isManaged }

    init(
        coachProfileId: String,
        link: CoachTraineeLink,
        profile: Profile,
        profileService: ProfileServiceProtocol,
        measurementService: MeasurementServiceProtocol,
        linkService: CoachTraineeLinkServiceProtocol,
        onSaved: @escaping (Profile) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.coachProfileId = coachProfileId
        self.link = link
        self.profile = profile
        self.profileService = profileService
        self.measurementService = measurementService
        self.linkService = linkService
        self.onSaved = onSaved
        self.onCancel = onCancel
        _name = State(initialValue: profile.name)
        _displayName = State(initialValue: link.displayName ?? "")
        _dateOfBirth = State(initialValue: profile.dateOfBirth)
        _notes = State(initialValue: profile.notes ?? "")
        _gender = State(initialValue: profile.gender)
        _phoneNumber = State(initialValue: PhoneFormatter.format(profile.phoneNumber ?? ""))
        _telegramUsername = State(initialValue: profile.telegramUsername ?? "")
        _weight = State(initialValue: profile.weight?.measurementFormatted ?? "")
    }

    var body: some View {
        MainSheet(
            title: "Редактировать",
            onBack: onCancel,
            trailing: {
                Button(isSaving ? "Сохраняю…" : "Сохранить") { save() }
                    .disabled(isSaving || (isManaged && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                    .foregroundStyle(.primary)
            },
            content: {
                ScrollView {
                    VStack(spacing: 0) {
                        SettingsCard(title: "Основное") {
                            VStack(spacing: 0) {
                                if isManaged {
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
                                } else {
                                    FormRow(icon: "writing-sign", title: "Имя") {
                                        Text(profile.name)
                                            .foregroundStyle(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                    }
                                    FormSectionDivider()
                                }
                                FormRowTextField(icon: "writing-sign", title: "Имя в списке", placeholder: "Как показывать в списке подопечных", text: $displayName, textContentType: .name, autocapitalization: .words)
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

                        if isManaged {
                            SettingsCard(title: "Контакты") {
                                VStack(spacing: 0) {
                                    FormRowPhone(icon: "phone", title: "Телефон", text: $phoneNumber)
                                    FormSectionDivider()
                                    FormRowTextField(icon: "send-plane-horizontal", title: "Telegram", placeholder: "Логин без @", text: $telegramUsername, textContentType: .username, autocapitalization: .never)
                                }
                            }
                        } else if profile.phoneNumber != nil || profile.telegramUsername != nil {
                            SettingsCard(title: "Контакты") {
                                VStack(spacing: 0) {
                                    if let phone = profile.phoneNumber, !phone.isEmpty {
                                        FormRow(icon: "phone", title: "Телефон") {
                                            Text(PhoneFormatter.displayString(phone))
                                                .foregroundStyle(.secondary)
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                        }
                                        if profile.telegramUsername != nil { FormSectionDivider() }
                                    }
                                    if let tg = profile.telegramUsername, !tg.isEmpty {
                                        FormRow(icon: "send-plane-horizontal", title: "Telegram") {
                                            Text("@" + tg)
                                                .foregroundStyle(.secondary)
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                        }
                                    }
                                }
                            }
                        }

                        SettingsCard(title: "Дата рождения") {
                            FormRowDateOfBirth(selection: $dateOfBirth, onTap: { showDatePickerSheet = true })
                        }
                        .sheet(isPresented: $showDatePickerSheet) {
                            FormDatePickerSheet(selection: $dateOfBirth, isPresented: $showDatePickerSheet, title: "Дата рождения")
                                .mainSheetPresentation(.calendar)
                        }

                        FormNotesCard(notes: $notes)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, AppDesign.sectionSpacing)
                }
                .background(AppColors.systemGroupedBackground)
                .scrollDismissesKeyboard(.interactively)
                .dismissKeyboardOnTap()
                .overlay {
                    if isSaving {
                        AppColors.overlayDim
                            .ignoresSafeArea()
                            .overlay {
                                VStack(spacing: AppDesign.loadingSpacing) {
                                    ProgressView()
                                        .scaleEffect(AppDesign.loadingScale)
                                        .tint(AppColors.white)
                                    Text("Сохранение…")
                                        .appTypography(.secondary)
                                        .foregroundStyle(AppColors.white)
                                }
                            }
                    }
                }
                .allowsHitTesting(!isSaving)
                .appConfirmationDialog(
                    title: "Ошибка",
                    message: errorMessage ?? "Произошла ошибка.",
                    isPresented: Binding(
                        get: { errorMessage != nil },
                        set: { if !$0 { errorMessage = nil } }
                    ),
                    confirmTitle: "OK",
                    onConfirm: { errorMessage = nil },
                    onCancel: { errorMessage = nil }
                )
            }
        )
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let weightValue = parsedPositiveDouble(weight)
        Task {
            do {
                let phone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                let telegram = telegramUsername.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: "@", with: "")
                let updated = Profile(
                    id: profile.id,
                    userId: profile.userId,
                    type: profile.type,
                    name: trimmedName,
                    gymName: profile.gymName,
                    createdAt: profile.createdAt,
                    gender: isManaged ? gender : profile.gender,
                    dateOfBirth: dateOfBirth,
                    iconEmoji: nil,
                    phoneNumber: isManaged ? (phone.isEmpty ? nil : (PhoneFormatter.isValid(phone) ? phone : nil)) : profile.phoneNumber,
                    telegramUsername: isManaged ? (telegram.isEmpty ? nil : telegram) : profile.telegramUsername,
                    notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                    ownerCoachProfileId: profile.ownerCoachProfileId,
                    mergedIntoProfileId: profile.mergedIntoProfileId,
                    height: profile.height,
                    weight: weightValue
                )
                try await profileService.updateProfile(
                    id: profile.id,
                    userId: profile.userId,
                    type: profile.type,
                    name: trimmedName,
                    gymName: profile.gymName,
                    createdAt: profile.createdAt,
                    gender: isManaged ? gender : profile.gender,
                    dateOfBirth: dateOfBirth,
                    iconEmoji: nil,
                    phoneNumber: isManaged ? (phone.isEmpty ? nil : (PhoneFormatter.isValid(phone) ? phone : nil)) : profile.phoneNumber,
                    telegramUsername: isManaged ? (telegram.isEmpty ? nil : telegram) : profile.telegramUsername,
                    notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                    ownerCoachProfileId: profile.ownerCoachProfileId,
                    mergedIntoProfileId: profile.mergedIntoProfileId,
                    height: profile.height,
                    weight: weightValue
                )
                if let weightValue {
                    try await syncTodayWeightMeasurement(profileId: profile.id, weightKg: weightValue)
                }
                try await linkService.updateLink(
                    coachProfileId: coachProfileId,
                    traineeProfileId: profile.id,
                    displayName: trimmedDisplayName.isEmpty ? nil : trimmedDisplayName
                )
                await MainActor.run {
                    AppDesign.triggerSuccessHaptic()
                    ToastCenter.shared.success("Данные подопечного обновлены")
                    isSaving = false
                    onSaved(updated)
                }
            } catch {
                await MainActor.run {
                    ToastCenter.shared.error(from: error, fallback: "Не удалось обновить подопечного")
                    if let msg = AppErrors.userMessageIfNeeded(for: error) { errorMessage = msg }
                    isSaving = false
                }
            }
        }
    }

    private func parsedPositiveDouble(_ text: String) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value > 0 else { return nil }
        return value
    }

    private func syncTodayWeightMeasurement(profileId: String, weightKg: Double) async throws {
        let list = try await measurementService.fetchMeasurements(profileId: profileId)
        let calendar = Calendar.current
        if let today = list.first(where: { calendar.isDate($0.date, inSameDayAs: Date()) }) {
            var patched = today
            patched.weight = weightKg
            try await measurementService.saveMeasurement(patched)
        } else {
            let created = Measurement(id: "", profileId: profileId, date: Date(), weight: weightKg)
            try await measurementService.saveMeasurement(created)
        }
    }
}
