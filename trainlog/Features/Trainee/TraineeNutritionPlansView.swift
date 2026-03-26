//
//  TraineeNutritionPlansView.swift
//  TrainLog
//

import SwiftUI
import Foundation

struct TraineeNutritionPlansView: View {
    let trainee: Profile
    let nutritionService: NutritionServiceProtocol
    let profileService: ProfileServiceProtocol
    let measurementService: MeasurementServiceProtocol
    var fallbackCoachProfiles: [Profile] = []

    @State private var plans: [NutritionPlan] = []
    @State private var coachProfiles: [Profile] = []
    @State private var isLoading = true
    @State private var showEditWeight = false
    @State private var isSavingWeight = false
    @State private var errorMessage: String?
    @State private var supplementAssignments: [TraineeSportsSupplementAssignment] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if isLoading {
                    loadingSkeletonSection
                } else if plans.isEmpty {
                    SettingsCard(title: "Питание") {
                        emptyStateWideBlock(
                            icon: "coffee-cup-01",
                            title: "Тренер еще не назначил вам план питания",
                            message: "Когда тренер сохранит КБЖУ, здесь появятся калории и Б/Ж/У по каждому тренеру"
                        )
                    }
                } else {
                    ForEach(plans.sorted(by: planSort)) { plan in
                        NutritionPlanCard(
                            title: nil,
                            subtitle: nil,
                            plan: plan,
                            accentColor: AppColors.accent,
                            actionTitle: "Редактировать вес",
                            onActionTap: { showEditWeight = true }
                        )
                    }
                }

                SettingsCard(title: "Спортивные добавки") {
                    if supplementAssignments.isEmpty {
                        emptyStateWideBlock(
                            icon: "token",
                            title: "Тренер еще не назначил спортивные добавки",
                            message: "Когда тренер добавит рекомендации, они появятся здесь в вашем разделе питания"
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            let sortedAssignments = supplementAssignments.sorted(by: { $0.updatedAt > $1.updatedAt })
                            ForEach(Array(sortedAssignments.enumerated()), id: \.element.id) { index, assignment in
                                SupplementAssignmentRow(
                                    assignment: assignment,
                                    contentHorizontalPadding: 0,
                                    contentVerticalPadding: 8
                                )
                                if index < sortedAssignments.count - 1 {
                                    Divider()
                                        .padding(.leading, AppDesign.listDividerLeadingCompact)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .background(AdaptiveScreenBackground())
        .navigationTitle("Питание и добавки")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPlans()
        }
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
        .sheet(isPresented: $showEditWeight) {
            EditTraineeWeightSheet(
                initialWeightKg: plans.first?.weightKgUsed ?? trainee.weight ?? 0.1,
                plansForPreview: plans,
                onSave: { newWeightKg in
                    try await saveWeightAndRecalculatePlans(newWeightKg: newWeightKg)
                }
            )
            .sheetContentEntrance()
            .sheetPresentationStyle()
            .presentationDetents(AppSheetDetents.mediumOnly)
            .presentationDragIndicator(.visible)
        }
    }

    private func loadPlans() async {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        do {
            async let feedTask = nutritionService.fetchNutritionPlansForTrainee(traineeProfileId: trainee.id)
            async let supplementsTask = nutritionService.fetchSupplementAssignmentsForTrainee(traineeProfileId: trainee.id)
            let (feed, supplements) = try await (feedTask, supplementsTask)
            await MainActor.run {
                plans = feed.plans
                coachProfiles = mergedCoachProfiles(apiProfiles: feed.coachProfiles)
                supplementAssignments = supplements.sorted { $0.updatedAt > $1.updatedAt }
            }
        } catch {
            if let msg = AppErrors.userMessageIfNeeded(for: error) {
                await MainActor.run { errorMessage = msg }
            }
        }
    }

    private func mergedCoachProfiles(apiProfiles: [Profile]) -> [Profile] {
        let all = apiProfiles + fallbackCoachProfiles
        var unique: [String: Profile] = [:]
        for profile in all {
            unique[profile.id] = profile
        }
        return Array(unique.values)
    }

    private func coachTitle(for plan: NutritionPlan) -> String {
        if let coach = coachProfiles.first(where: { $0.id == plan.coachProfileId }) {
            let gym = coach.gymName?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let gym, !gym.isEmpty {
                return "\(coach.name) · \(gym)"
            }
            return coach.name
        }
        return "Тренер"
    }

    private func coachName(for plan: NutritionPlan) -> String {
        if let coach = coachProfiles.first(where: { $0.id == plan.coachProfileId }) {
            coach.name
        } else {
            "Тренер"
        }
    }

    private func planSort(_ lhs: NutritionPlan, _ rhs: NutritionPlan) -> Bool {
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }
        return coachTitle(for: lhs) < coachTitle(for: rhs)
    }

    private func emptyStateWideBlock(icon: String, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            AppTablerIcon(icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.black)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.label)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(AppColors.secondaryLabel)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    private var loadingSkeletonSection: some View {
        VStack(spacing: 0) {
            SettingsCard(title: "Питание") {
                VStack(alignment: .leading, spacing: 10) {
                    SkeletonBlock(height: 120, cornerRadius: 12)
                    SkeletonBlock(height: 220, cornerRadius: 12)
                }
            }
            SettingsCard(title: "Спортивные добавки") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(0..<2, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 8) {
                            SkeletonLine(width: 160, height: 12)
                            SkeletonLine(width: 90, height: 10)
                            HStack(spacing: 8) {
                                SkeletonLine(width: 80, height: 10)
                                SkeletonLine(width: 96, height: 10)
                                SkeletonLine(width: 88, height: 10)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    private func saveWeightAndRecalculatePlans(newWeightKg: Double) async throws {
        await MainActor.run { isSavingWeight = true }
        defer { Task { @MainActor in isSavingWeight = false } }

        // 1) Обновляем вес в профиле и измерении за сегодня.
        try await syncWeightToProfileAndTodayMeasurement(weightKg: newWeightKg)

        // 2) Пересчитываем планы (макросы сохраняются, пересчитывается итог по весу).
        for plan in plans {
            _ = try await nutritionService.updateNutritionPlan(
                planId: plan.id,
                coachProfileId: plan.coachProfileId,
                traineeProfileId: trainee.id,
                weightKg: newWeightKg,
                proteinPerKg: plan.proteinPerKg,
                fatPerKg: plan.fatPerKg,
                carbsPerKg: plan.carbsPerKg,
                // В фиче "Дневник" при пересчете по весу нужны только `weightKg`.
                // Комментарий не отправляем, чтобы не трогать потенциально поврежденный `plan.comment`.
                comment: nil
            )
        }

        await loadPlans()
        await MainActor.run {
            showEditWeight = false
            ToastCenter.shared.success("Вес обновлен, питание пересчитано")
        }
    }

    private func syncWeightToProfileAndTodayMeasurement(weightKg: Double) async throws {
        let updatedProfile = Profile(
            id: trainee.id,
            userId: trainee.userId,
            type: trainee.type,
            name: trainee.name,
            gymName: trainee.gymName,
            createdAt: trainee.createdAt,
            gender: trainee.gender,
            dateOfBirth: trainee.dateOfBirth,
            iconEmoji: trainee.iconEmoji,
            phoneNumber: trainee.phoneNumber,
            telegramUsername: trainee.telegramUsername,
            notes: trainee.notes,
            ownerCoachProfileId: trainee.ownerCoachProfileId,
            mergedIntoProfileId: trainee.mergedIntoProfileId,
            height: trainee.height,
            weight: weightKg,
            developerMode: trainee.developerMode
        )
        try await profileService.updateProfile(updatedProfile)

        let list = try await measurementService.fetchMeasurements(profileId: trainee.id)
        let calendar = Calendar.current
        if let today = list.first(where: { calendar.isDate($0.date, inSameDayAs: Date()) }) {
            var patched = today
            patched.weight = weightKg
            try await measurementService.saveMeasurement(patched)
        } else {
            let created = Measurement(
                id: "",
                profileId: trainee.id,
                date: Date(),
                weight: weightKg
            )
            try await measurementService.saveMeasurement(created)
        }
    }
}

private struct EditTraineeWeightSheet: View {
    let initialWeightKg: Double
    let plansForPreview: [NutritionPlan]
    let onSave: (Double) async throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var weightKg: Double
    @State private var weightText: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        initialWeightKg: Double,
        plansForPreview: [NutritionPlan],
        onSave: @escaping (Double) async throws -> Void
    ) {
        self.initialWeightKg = initialWeightKg
        self.plansForPreview = plansForPreview
        self.onSave = onSave
        _weightKg = State(initialValue: max(0.1, initialWeightKg))
        let initialRounded = (max(0.1, initialWeightKg) * 10).rounded() / 10
        _weightText = State(initialValue: initialRounded.measurementFormatted)
    }

    private var previews: [NutritionPreviewModel] {
        plansForPreview.map {
            NutritionPreviewModel(
                weightKg: weightKg,
                proteinPerKg: $0.proteinPerKg,
                fatPerKg: $0.fatPerKg,
                carbsPerKg: $0.carbsPerKg
            )
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    SettingsCard(title: "Вес") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Значения Б/Ж/У не изменяются — пересчёт делается по новому весу.")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.secondaryLabel)

                            TextField("0.1", text: $weightText)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.plain)
                                .font(.subheadline.weight(.semibold))
                                .multilineTextAlignment(.leading)
                                .formInputStyle()
                                .onChange(of: weightText) { _, newValue in
                                    let sanitized = sanitizeDecimalInput(newValue)
                                    if sanitized != newValue {
                                        weightText = sanitized
                                        return
                                    }
                                    guard let d = Double(sanitized) else { return }
                                    let rounded = max(0, roundTo0_1(d))
                                    weightKg = rounded
                                    let formatted = rounded.measurementFormatted
                                    if weightText != formatted {
                                        weightText = formatted
                                    }
                                }
                        }
                    }

                    if !previews.isEmpty {
                        SettingsCard(title: "Пересчёт") {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(previews.indices, id: \.self) { idx in
                                    NutritionPreviewCard(preview: previews[idx])
                                }
                            }
                        }
                    }

                    if let errorMessage, !errorMessage.isEmpty {
                        SettingsCard {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(AppColors.destructive)
                        }
                    }
                }
                .padding(.bottom, AppDesign.sectionSpacing)
            }
            .background(AdaptiveScreenBackground())
            .navigationTitle("Питание")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isSaving {
                        ProgressView().scaleEffect(0.9)
                    } else {
                        Button("Сохранить") { submit() }
                            .disabled(weightKg <= 0)
                    }
                }
            }
        }
    }

    private func submit() {
        errorMessage = nil
        isSaving = true
        Task {
            do {
                try await onSave(weightKg)
                await MainActor.run { dismiss() }
            } catch {
                let message = AppErrors.userMessageIfNeeded(for: error) ?? "Не удалось обновить вес"
                await MainActor.run {
                    self.isSaving = false
                    self.errorMessage = message
                    ToastCenter.shared.error(message)
                }
            }
        }
    }

    private func roundTo0_1(_ v: Double) -> Double {
        (v * 10).rounded() / 10
    }

    private func sanitizeDecimalInput(_ raw: String) -> String {
        var s = raw.replacingOccurrences(of: ",", with: ".")
        s = s.filter { $0.isNumber || $0 == "." }
        if let firstDot = s.firstIndex(of: ".") {
            let after = s[s.index(after: firstDot)...]
            let cleanedAfter = after.replacingOccurrences(of: ".", with: "")
            s = String(s[..<s.index(after: firstDot)]) + cleanedAfter
        }
        return s
    }
}
