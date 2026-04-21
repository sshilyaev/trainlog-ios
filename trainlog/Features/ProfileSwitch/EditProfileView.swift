//
//  EditProfileView.swift
//  TrainLog
//
//  Редактирование профиля: загрузка по id → форма → сохранение внутри экрана.
//  Родитель получает только onSaved(Profile) после успешного сохранения.
//

import SwiftUI
import UIKit

struct EditProfileView: View {
    let profileId: String
    let profileService: ProfileServiceProtocol
    let measurementService: MeasurementServiceProtocol
    let onSaved: (Profile) -> Void
    let onCancel: () -> Void
    let onDismiss: () -> Void

    @State private var loadedProfile: Profile?
    @State private var isLoaded = false
    @State private var isSaving = false
    @State private var saveError: String?

    @State private var name: String = ""
    @State private var gymName: String = ""
    @State private var gender: ProfileGender?
    @State private var dateOfBirth: Date?
    @State private var phoneNumber: String = ""
    @State private var telegramUsername: String = ""
    @State private var notes: String = ""
    @State private var height: String = ""
    @State private var weight: String = ""

    @State private var showDatePickerSheet = false

    private var profileType: ProfileType { loadedProfile?.type ?? .trainee }

    var body: some View {
        MainSheet(
            title: "Редактировать",
            onBack: onCancel,
            trailing: {
                Button("Обновить") {
                    AppDesign.dismissKeyboardThen { save() }
                }
                .disabled(isSaving || !isLoaded || loadedProfile == nil || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            },
            content: {
                Group {
                    if isLoaded && loadedProfile == nil {
                        ContentUnavailableView(
                            "Профиль не найден",
                            image: "tabler-outline-user-circle",
                            description: Text("Не удалось загрузить данные профиля.")
                        )
                    } else {
                        formContent
                    }
                }
                .background(AppColors.systemGroupedBackground)
                .overlay {
                    if !isLoaded {
                        LoadingOverlayView(message: "Загружаю")
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .dismissKeyboardOnTap()
                .navigationBarBackButtonHidden(true)
                .overlay {
                    if isSaving {
                        LoadingOverlayView(message: "Сохранение…")
                    }
                }
                .allowsHitTesting(!isSaving)
                .appConfirmationDialog(
                    title: "Ошибка",
                    message: saveError ?? "Произошла ошибка.",
                    isPresented: Binding(
                        get: { saveError != nil },
                        set: { if !$0 { saveError = nil } }
                    ),
                    confirmTitle: "OK",
                    onConfirm: { saveError = nil },
                    onCancel: { saveError = nil }
                )
                .task { await loadProfile() }
            }
        )
        .sheetContentEntrance()
        .mainSheetPresentation(.half)
    }

    private var formContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                SettingsCard(title: "Основное") {
                    VStack(spacing: 0) {
                        FormRowTextField(icon: "writing-sign", title: "Имя", placeholder: "Как к вам обращаться", text: $name, textContentType: .name, autocapitalization: .words)
                        FormSectionDivider()
                        if profileType == .coach {
                            FormRowTextField(icon: "building-apartment-two", title: "Зал", placeholder: "Название зала", text: $gymName, textContentType: .organizationName, autocapitalization: .words)
                        }
                    }
                }

                SettingsCard(title: "Личные данные") {
                    VStack(spacing: 0) {
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
                        FormRowDateOfBirth(selection: $dateOfBirth, onTap: { showDatePickerSheet = true })
                    }
                }

                bodyMetricsCard

                SettingsCard(title: "Контакты") {
                    VStack(spacing: 0) {
                        FormRowPhone(icon: "phone", title: "Телефон", text: $phoneNumber)
                        FormSectionDivider()
                        FormRowTextField(icon: "send-plane-horizontal", title: "Telegram", placeholder: "Логин без @", text: $telegramUsername, textContentType: .username, autocapitalization: .never)
                    }
                }

                if profileType == .trainee {
                    FormNotesCard(notes: $notes)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .sheet(isPresented: $showDatePickerSheet) {
            FormDatePickerSheet(selection: $dateOfBirth, isPresented: $showDatePickerSheet, title: "Дата рождения")
        }
    }

    private var bodyMetricsCard: some View {
        SettingsCard(title: "") {
            HStack(spacing: AppDesign.rectangularBlockSpacing) {
                metricInputCard(
                    icon: "ruler-2",
                    title: "Рост",
                    unit: "см",
                    value: $height
                )
                metricInputCard(
                    icon: "weight",
                    title: "Вес",
                    unit: "кг",
                    value: $weight
                )
            }
        }
    }

    private func metricInputCard(
        icon: String,
        title: String,
        unit: String,
        value: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, appIcon: icon)
                .appTypography(.secondary)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                TextField(unit, text: value)
                    .appTypography(.body)
                    .keyboardType(.decimalPad)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                Text(unit)
                    .appTypography(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(AppColors.tertiarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadProfile() async {
        do {
            guard let p = try await profileService.fetchProfile(id: profileId) else {
                await MainActor.run {
                    saveError = "Профиль не найден"
                    isLoaded = true
                }
                return
            }
            await MainActor.run {
                loadedProfile = p
                name = p.name
                gymName = p.gymName ?? ""
                gender = p.gender
                dateOfBirth = p.dateOfBirth
                phoneNumber = PhoneFormatter.format(p.phoneNumber ?? "")
                telegramUsername = p.telegramUsername ?? ""
                notes = p.notes ?? ""
                height = p.height.map { $0.measurementFormatted } ?? ""
                weight = p.weight.map { $0.measurementFormatted } ?? ""
                isLoaded = true
            }
        } catch {
            await MainActor.run {
                if let msg = AppErrors.userMessageIfNeeded(for: error) { saveError = msg }
                isLoaded = true
            }
        }
    }

    private func save() {
        guard let profile = loadedProfile else { return }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let nameStr = String(trimmed)
        let gymStr = profileType == .coach ? (gymName.isEmpty ? nil : String(gymName)) : nil
        let phone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let telegram = telegramUsername.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: "@", with: "")
        let notesTrimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let phoneVal = phone.isEmpty ? nil : (PhoneFormatter.isValid(phone) ? String(phone) : nil)
        let telegramVal = telegram.isEmpty ? nil : String(telegram)
        let notesVal = profileType == .trainee ? (notesTrimmed.isEmpty ? nil : String(notesTrimmed)) : nil
        let heightTrimmed = height.trimmingCharacters(in: .whitespacesAndNewlines)
        let heightValue: Double? = {
            guard !heightTrimmed.isEmpty else { return nil }
            let normalized = heightTrimmed.replacingOccurrences(of: ",", with: ".")
            return Double(normalized)
        }()
        let weightTrimmed = weight.trimmingCharacters(in: .whitespacesAndNewlines)
        let weightValue: Double? = {
            guard !weightTrimmed.isEmpty else { return nil }
            let normalized = weightTrimmed.replacingOccurrences(of: ",", with: ".")
            guard let value = Double(normalized), value > 0 else { return nil }
            return value
        }()

        isSaving = true
        saveError = nil

        Task {
            do {
                try await profileService.updateProfile(
                    id: profile.id,
                    userId: profile.userId,
                    type: profile.type,
                    name: nameStr,
                    gymName: gymStr,
                    createdAt: profile.createdAt,
                    gender: gender,
                    dateOfBirth: dateOfBirth,
                    iconEmoji: nil,
                    phoneNumber: phoneVal,
                    telegramUsername: telegramVal,
                    notes: notesVal,
                    ownerCoachProfileId: profile.ownerCoachProfileId,
                    mergedIntoProfileId: profile.mergedIntoProfileId,
                    height: heightValue,
                    weight: weightValue
                )

                if let weightValue {
                    try await syncTodayWeightMeasurement(profileId: profile.id, weightKg: weightValue)
                }

                let updated = Profile(
                    id: profile.id,
                    userId: profile.userId,
                    type: profile.type,
                    name: nameStr,
                    gymName: gymStr,
                    createdAt: profile.createdAt,
                    gender: gender,
                    dateOfBirth: dateOfBirth,
                    iconEmoji: nil,
                    phoneNumber: phoneVal,
                    telegramUsername: telegramVal,
                    notes: notesVal,
                    ownerCoachProfileId: profile.ownerCoachProfileId,
                    mergedIntoProfileId: profile.mergedIntoProfileId,
                    height: heightValue,
                    weight: weightValue
                )

                await MainActor.run {
                    AppDesign.triggerSuccessHaptic()
                    ToastCenter.shared.success("Профиль обновлен")
                    onSaved(updated)
                    onDismiss()
                }
            } catch {
                await MainActor.run {
                    if let msg = AppErrors.userMessageIfNeeded(for: error) {
                        AppDesign.triggerWarningHaptic()
                        saveError = msg
                    }
                    ToastCenter.shared.error(from: error, fallback: "Не удалось обновить профиль")
                }
            }
            await MainActor.run {
                isSaving = false
            }
        }
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

struct EditProfileSnapshot: Identifiable {
    var id: String { profileId }
    let profileId: String
    let userId: String
    let profileType: ProfileType
    let initialName: String
    let initialGymName: String
    let createdAt: Date
    let initialGender: ProfileGender?
    let initialIconEmoji: String?
    let initialPhoneNumber: String?
    let initialTelegramUsername: String?
}

#Preview {
    EditProfileView(
        profileId: "1",
        profileService: MockProfileService(),
        measurementService: MockMeasurementService(),
        onSaved: { _ in },
        onCancel: {},
        onDismiss: {}
    )
}
