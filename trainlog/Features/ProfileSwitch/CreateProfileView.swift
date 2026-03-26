//
//  CreateProfileView.swift
//  TrainLog
//

import SwiftUI
import UIKit

struct CreateProfileView: View {
    let userId: String
    @State private var name: String
    @State private var profileType: ProfileType
    @State private var gymName: String
    @State private var gender: ProfileGender?
    @State private var phoneNumber: String
    @State private var telegramUsername: String
    @State private var dateOfBirth: Date?
    @State private var height: String
    @State private var weight: String
    @State private var notes: String
    @State private var showDatePickerSheet: Bool
    @State private var isLoading: Bool

    let profileService: ProfileServiceProtocol
    let measurementService: MeasurementServiceProtocol
    /// Передаём id и type созданного профиля (не сам Profile), чтобы избежать коррупции объекта при переходе через async.
    var onCreated: (String, ProfileType) -> Void
    var onCancel: () -> Void
    var createProfileError: String?
    var onClearError: () -> Void
    var onError: (String) -> Void

    init(
        userId: String,
        profileService: ProfileServiceProtocol,
        measurementService: MeasurementServiceProtocol,
        initialName: String? = nil,
        onCreated: @escaping (String, ProfileType) -> Void,
        onCancel: @escaping () -> Void,
        createProfileError: String?,
        onClearError: @escaping () -> Void,
        onError: @escaping (String) -> Void
    ) {
        self.userId = userId
        self.profileService = profileService
        self.measurementService = measurementService
        self.onCreated = onCreated
        self.onCancel = onCancel
        self.createProfileError = createProfileError
        self.onClearError = onClearError
        self.onError = onError

        _name = State(initialValue: initialName ?? "")
        _profileType = State(initialValue: .trainee)
        _gymName = State(initialValue: "")
        _gender = State(initialValue: .male)
        _phoneNumber = State(initialValue: "")
        _telegramUsername = State(initialValue: "")
        _dateOfBirth = State(initialValue: nil)
        _height = State(initialValue: "")
        _weight = State(initialValue: "")
        _notes = State(initialValue: "")
        _showDatePickerSheet = State(initialValue: false)
        _isLoading = State(initialValue: false)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    SettingsCard(title: "Выберите тип профиля") {
                        VStack(spacing: 12) {
                            HStack(spacing: AppDesign.rectangularBlockSpacing) {
                                typeTile(
                                    type: .trainee,
                                    icon: "file-default",
                                    title: "Дневник",
                                    description: "Для личного прогресса: замеры, цели и графики"
                                )
                                typeTile(
                                    type: .coach,
                                    icon: "user-love-heart",
                                    title: "Тренер",
                                    description: "Для работы с подопечными, абонементами и посещениями"
                                )
                            }
                            .padding(.top, 4)
                            FormSectionDivider()
                            FormRowTextField(
                                icon: "writing-sign",
                                title: "Имя в профиле",
                                placeholder: "Как к вам обращаться",
                                text: $name,
                                textContentType: .name,
                                autocapitalization: .words
                            )
                            if profileType == .trainee {
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
                    }
                }
                .padding(.top, 8)
            .padding(.bottom, AppDesign.sectionSpacing)
            }
            .background(AppColors.systemGroupedBackground)
            .navigationTitle("Новый профиль")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onCancel()
                    } label: {
                        BackToolbarButton(action: onCancel)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.9)
                    } else {
                        Button {
                            AppDesign.dismissKeyboardThen { createProfile() }
                        } label: {
                            Text("Создать")
                                .font(.body)
                                .fontWeight(.regular)
                        }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .overlay {
                if isLoading {
                    LoadingOverlayView(message: "Загружаю")
                }
            }
            .appConfirmationDialog(
                title: "Ошибка",
                message: createProfileError ?? "Произошла ошибка.",
                isPresented: Binding(
                    get: { createProfileError != nil },
                    set: { if !$0 { onClearError() } }
                ),
                confirmTitle: "OK",
                onConfirm: onClearError,
                onCancel: onClearError
            )
        }
        .trackAPIScreen("Новый профиль")
        .sheetContentEntrance()
        .sheetPresentationStyle()
    }

    private func createProfile() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        Task {
            await MainActor.run { onClearError() }
            let trimmedName = trimmed
            let weightValue = parsedPositiveDouble(weight)
            let profile = Profile(
                id: UUID().uuidString,
                userId: userId,
                type: profileType,
                name: trimmedName,
                gymName: nil,
                createdAt: Date(),
                gender: nil,
                dateOfBirth: nil,
                iconEmoji: nil,
                phoneNumber: nil,
                telegramUsername: nil,
                notes: nil,
                ownerCoachProfileId: nil,
                mergedIntoProfileId: nil,
                height: nil,
                weight: weightValue
            )
            do {
                let created = try await profileService.createProfile(profile, name: trimmedName)
                if created.type == .trainee, let weightValue {
                    let todayWeightMeasurement = Measurement(
                        id: "",
                        profileId: created.id,
                        date: Date(),
                        weight: weightValue
                    )
                    try? await measurementService.saveMeasurement(todayWeightMeasurement)
                }
                AppDesign.triggerSuccessHaptic()
                let createdId = created.id
                let createdType = created.type
                await MainActor.run { isLoading = false }
                await MainActor.run { ToastCenter.shared.success("Профиль создан") }
                onCreated(createdId, createdType)
            } catch {
                await MainActor.run {
                    AppDesign.triggerWarningHaptic()
                    ToastCenter.shared.error(from: error, fallback: "Не удалось создать профиль")
                    if let msg = AppErrors.userMessageIfNeeded(for: error) { onError(msg) }
                    isLoading = false
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

    private func typeTile(type: ProfileType, icon: String, title: String, description: String) -> some View {
        let isSelected = profileType == type
        return Button {
            profileType = type
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

    private func profileTypeCard(type: ProfileType, icon: String, title: String, description: String) -> some View {
        let isSelected = profileType == type
        return Button {
            profileType = type
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
                ? AnyView(LinearGradient(
                    colors: [AppColors.accent, AppColors.accent.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
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
}

#Preview {
    CreateProfileView(
        userId: "preview-user",
        profileService: MockProfileService(),
        measurementService: MockMeasurementService(),
        onCreated: { _, _ in },
        onCancel: {},
        createProfileError: nil,
        onClearError: {},
        onError: { _ in }
    )
}
