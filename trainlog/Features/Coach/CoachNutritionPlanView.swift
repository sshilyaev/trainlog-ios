//
//  CoachNutritionPlanView.swift
//  TrainLog
//

import SwiftUI
import Combine

struct CoachNutritionPlanView: View {
    let coachProfileId: String
    let trainee: Profile
    let nutritionService: NutritionServiceProtocol
    let profileService: ProfileServiceProtocol
    let measurementService: MeasurementServiceProtocol

    @State private var plan: NutritionPlan?
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showEditSheet = false
    @State private var supplements: [TraineeSportsSupplementAssignment] = []
    @State private var showSupplementsEditorScreen = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if isLoading {
                    SettingsCard(title: "Питание") {
                        SkeletonBlock(height: 290, cornerRadius: 12)
                    }
                } else if let plan {
                    NutritionPlanCard(
                        title: nil,
                        subtitle: nil,
                        plan: plan,
                        accentColor: AppColors.profileAccent,
                        actionTitle: "Редактировать КБЖУ",
                        onActionTap: {
                            showEditSheet = true
                        }
                    )
                } else {
                    SettingsCard(title: "Питание") {
                        VStack(alignment: .leading, spacing: 14) {
                            nutritionEmptyStateBlock
                            Button {
                                showEditSheet = true
                            } label: {
                                Text("Задать КБЖУ")
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .contentShape(Rectangle())
                        }
                    }
                }

                SettingsCard(title: "Спортивные добавки") {
                    VStack(alignment: .leading, spacing: 12) {
                        if supplements.isEmpty {
                            supplementsEmptyStateBlock
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                let sortedSupplements = supplements.sorted(by: { $0.updatedAt > $1.updatedAt })
                                ForEach(sortedSupplements) { assignment in
                                    SupplementAssignmentRow(
                                        assignment: assignment,
                                        presentation: .card,
                                        contentHorizontalPadding: 12,
                                        contentVerticalPadding: 10
                                    )
                                }
                            }
                        }

                        Button {
                            showSupplementsEditorScreen = true
                        } label: {
                            Text("Редактировать добавки")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
            }
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .background(AdaptiveScreenBackground())
        .navigationTitle("Питание и добавки")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPlan()
            await loadSupplements()
        }
        .sheet(isPresented: $showEditSheet) {
            EditNutritionPlanSheet(
                initialDraft: currentDraft,
                canEditWeight: canEditWeight,
                lockedWeightKg: lockedWeightKg,
                onSave: { weightKg, proteinPerKg, fatPerKg, carbsPerKg, _ in
                    try await savePlan(
                        weightKg: weightKg,
                        proteinPerKg: proteinPerKg,
                        fatPerKg: fatPerKg,
                        carbsPerKg: carbsPerKg,
                        comment: nil,
                        shouldSyncWeight: canEditWeight
                    )
                }
            )
            .sheetContentEntrance()
            .mainSheetPresentation(.half)
        }
        .navigationDestination(isPresented: $showSupplementsEditorScreen) {
            CoachSupplementsEditorSheet(
                coachProfileId: coachProfileId,
                traineeProfileId: trainee.id,
                nutritionService: nutritionService,
                initialAssignments: supplements,
                onChanged: { updated in
                    supplements = updated.sorted { $0.updatedAt > $1.updatedAt }
                }
            )
        }
        .overlay {
            if isSaving {
                LoadingOverlayView(message: "Сохраняю питание")
            }
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
    }

    private var supplementsEmptyStateBlock: some View {
        emptyStateWideBlock(
            icon: "token",
            title: "Пока ничего не назначено",
            message: "Добавьте спортивные добавки из каталога, чтобы подопечный видел рекомендации в разделе питания"
        )
    }

    private var nutritionEmptyStateBlock: some View {
        emptyStateWideBlock(
            icon: "coffee-cup-01",
            title: "План питания для этого подопечного еще не задан",
            message: "Тренер указывает Б/Ж/У в граммах на кг, а итоговые данные считаются автоматически"
        )
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

    private var currentDraft: NutritionPlanDraft {
        NutritionPlanDraft(
            coachProfileId: coachProfileId,
            traineeProfileId: trainee.id,
            weightKg: plan?.weightKgUsed ?? trainee.weight,
            proteinPerKg: plan?.proteinPerKg ?? 0,
            fatPerKg: plan?.fatPerKg ?? 0,
            carbsPerKg: plan?.carbsPerKg ?? 0,
            // Комментарий временно убран из UI: чтобы не читать потенциально поврежденный `plan.comment`,
            // в draft всегда кладём пустую строку.
            comment: ""
        )
    }

    private var canEditWeight: Bool {
        // Если это "настоящий" подключенный профиль и вес уже есть — вес нельзя редактировать.
        trainee.isManaged || trainee.weight == nil
    }

    private var lockedWeightKg: Double {
        // Stepper требует минимум > 0, поэтому используем безопасный дефолт.
        max(0.1, (trainee.weight ?? plan?.weightKgUsed) ?? 0.1)
    }

    private func loadPlan() async {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        do {
            let loadedPlan = try await nutritionService.fetchNutritionPlan(
                coachProfileId: coachProfileId,
                traineeProfileId: trainee.id
            )
            await MainActor.run {
                plan = loadedPlan
            }
        } catch {
            if let msg = AppErrors.userMessageIfNeeded(for: error) {
                await MainActor.run { errorMessage = msg }
            }
        }
    }

    private func loadSupplements() async {
        do {
            let loaded = try await nutritionService.fetchSupplementAssignmentsForCoach(
                coachProfileId: coachProfileId,
                traineeProfileId: trainee.id
            )
            await MainActor.run {
                supplements = loaded.sorted { $0.updatedAt > $1.updatedAt }
            }
        } catch {
            if let msg = AppErrors.userMessageIfNeeded(for: error) {
                await MainActor.run { errorMessage = msg }
            }
        }
    }

    private func savePlan(
        weightKg: Double,
        proteinPerKg: Double,
        fatPerKg: Double,
        carbsPerKg: Double,
        comment: String?,
        shouldSyncWeight: Bool
    ) async throws {
        await MainActor.run { isSaving = true }
        defer { Task { @MainActor in isSaving = false } }

        if shouldSyncWeight {
            try await syncWeightToProfileAndTodayMeasurement(weightKg: weightKg)
        }
        let saved: NutritionPlan
        if let currentPlanId = plan?.id, !currentPlanId.isEmpty {
            saved = try await nutritionService.updateNutritionPlan(
                planId: currentPlanId,
                coachProfileId: coachProfileId,
                traineeProfileId: trainee.id,
                weightKg: weightKg,
                proteinPerKg: proteinPerKg,
                fatPerKg: fatPerKg,
                carbsPerKg: carbsPerKg,
                comment: comment
            )
        } else {
            saved = try await nutritionService.createNutritionPlan(
                coachProfileId: coachProfileId,
                traineeProfileId: trainee.id,
                weightKg: weightKg,
                proteinPerKg: proteinPerKg,
                fatPerKg: fatPerKg,
                carbsPerKg: carbsPerKg,
                comment: comment
            )
        }
        await MainActor.run {
            plan = saved
            ToastCenter.shared.success("План питания сохранен")
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

private struct CoachSupplementsEditorSheet: View {
    let coachProfileId: String
    let traineeProfileId: String
    let nutritionService: NutritionServiceProtocol
    let initialAssignments: [TraineeSportsSupplementAssignment]
    let onChanged: ([TraineeSportsSupplementAssignment]) -> Void

    @State private var selectedType: SportsSupplementType?
    @State private var catalog: [SportsSupplementCatalogItem] = []
    @State private var assignments: [TraineeSportsSupplementAssignment]
    @State private var searchText: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var editingDraft: SupplementEditDraft?
    @State private var showEditSheet = false
    @State private var isMutatingAssignment = false
    @State private var mutatingSupplementId: String?
    @State private var mutatingMessage = "Сохраняю добавку"

    private struct SupplementEditDraft: Identifiable {
        let id: String
        let supplementId: String
        let supplementName: String
        let dosageValue: String
        let dosageUnit: SupplementDosageUnit?
        let timing: String
        let frequency: String
        let note: String
    }

    struct SupplementEditPayload {
        let dosageValue: String
        let dosageUnit: SupplementDosageUnit?
        let timing: String
        let frequency: String
        let note: String
    }

    init(
        coachProfileId: String,
        traineeProfileId: String,
        nutritionService: NutritionServiceProtocol,
        initialAssignments: [TraineeSportsSupplementAssignment],
        onChanged: @escaping ([TraineeSportsSupplementAssignment]) -> Void
    ) {
        self.coachProfileId = coachProfileId
        self.traineeProfileId = traineeProfileId
        self.nutritionService = nutritionService
        self.initialAssignments = initialAssignments
        self.onChanged = onChanged
        _assignments = State(initialValue: initialAssignments.sorted { $0.updatedAt > $1.updatedAt })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    assignedSection
                    filterSection
                    catalogSection
                    errorSection
                }
                .padding(.bottom, 20)
            }
            .background(AdaptiveScreenBackground())
            .overlay {
                if isMutatingAssignment {
                    LoadingOverlayView(message: mutatingMessage)
                }
            }
            .navigationTitle("Спортивные добавки")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showEditSheet) {
                if let draft = editingDraft {
                SupplementAssignmentEditScreen(
                    supplementName: draft.supplementName,
                    initialDosageValue: draft.dosageValue,
                    initialDosageUnit: draft.dosageUnit,
                    initialTiming: draft.timing,
                    initialFrequency: draft.frequency,
                    initialNote: draft.note,
                    onSave: { payload in
                        try await updateAssignment(
                            draft,
                            payload: payload
                        )
                    }
                )
                .sheetContentEntrance()
                .mainSheetPresentation(.half)
                }
            }
        }
        .task { await reloadAll() }
        .onChange(of: selectedType) { _, _ in
            Task { await loadCatalog() }
        }
        .onChange(of: showEditSheet) { _, isPresented in
            if !isPresented {
                editingDraft = nil
            }
        }
    }

    private var filterSection: some View {
        SettingsCard {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    typeChip(
                        title: "Все типы",
                        isSelected: selectedType == nil,
                        action: { selectedType = nil }
                    )
                    ForEach(SportsSupplementType.allCases) { type in
                        typeChip(
                            title: type.displayName,
                            isSelected: selectedType == type,
                            action: { selectedType = type }
                        )
                    }
                }
            }
        }
    }

    private var assignedSection: some View {
        SettingsCard(title: "Назначенные добавки") {
            if isLoading && assignments.isEmpty {
                supplementsAssignedSkeleton
            } else if assignments.isEmpty {
                emptyStateWideBlock(
                    icon: "token",
                    title: "Пока ничего не назначено",
                    message: "Выберите добавки из каталога ниже. Можно назначить несколько добавок одновременно"
                )
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Можно указать дозировку, время и частоту при редактировании.")
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .padding(.bottom, 2)
                    ForEach(Array(assignments.enumerated()), id: \.element.id) { index, assignment in
                        SupplementAssignmentRow(
                            assignment: assignment,
                            presentation: .listRow,
                            showsDeleteAction: true,
                            showsEditAction: true,
                            showsActionsMenu: true,
                            contentHorizontalPadding: 0,
                            contentVerticalPadding: 8,
                            onEdit: {
                                openEditSheetFromMenu(for: assignment)
                            },
                            onDelete: { Task { await removeAssignment(assignment) } }
                        )
                        if index < assignments.count - 1 {
                            Divider()
                                .padding(.leading, AppDesign.listDividerLeadingCompact)
                        }
                    }
                }
            }
        }
    }

    private var catalogSection: some View {
        SettingsCard(title: "Каталог") {
            if isLoading && catalog.isEmpty {
                supplementsCatalogSkeleton
            } else if catalog.isEmpty {
                Text("Добавки не найдены для выбранного типа.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryLabel)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    searchField
                    if filteredCatalog.isEmpty {
                        Text("По запросу ничего не найдено.")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.secondaryLabel)
                    } else {
                        ForEach(Array(filteredCatalog.enumerated()), id: \.element.id) { index, item in
                            supplementCatalogRow(item)
                            if index < filteredCatalog.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage, !errorMessage.isEmpty {
            SettingsCard {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.destructive)
            }
        }
    }

    private func supplementCatalogRow(_ item: SportsSupplementCatalogItem) -> some View {
        let alreadyAssigned = assignments.contains { $0.supplementId == item.id }
        return Button {
            guard !alreadyAssigned else { return }
            Task {
                _ = await addAssignment(item)
            }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                    Text(item.type.displayName)
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                    if !item.description.isEmpty {
                        Text(item.description)
                            .font(.caption)
                            .foregroundStyle(AppColors.tertiaryLabel)
                    }
                }
                Spacer()
                if isMutatingAssignment && mutatingSupplementId == item.id {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    AppTablerIcon(alreadyAssigned ? "checkmark" : "plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                }
            }
            .padding(.horizontal, 0)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PressableButtonStyle(cornerRadius: 0))
    }

    private func reloadAll() async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        defer { Task { @MainActor in isLoading = false } }
        do {
            async let assigned = nutritionService.fetchSupplementAssignmentsForCoach(
                coachProfileId: coachProfileId,
                traineeProfileId: traineeProfileId
            )
            async let catalogItems = nutritionService.fetchSupplementCatalog(type: selectedType)
            let (loadedAssignments, loadedCatalog) = try await (assigned, catalogItems)
            await MainActor.run {
                assignments = loadedAssignments.sorted { $0.updatedAt > $1.updatedAt }
                catalog = loadedCatalog
                onChanged(assignments)
            }
        } catch {
            if let msg = AppErrors.userMessageIfNeeded(for: error) {
                await MainActor.run { errorMessage = msg }
            }
        }
    }

    private func loadCatalog() async {
        do {
            let loaded = try await nutritionService.fetchSupplementCatalog(type: selectedType)
            await MainActor.run {
                catalog = loaded
            }
        } catch {
            if let msg = AppErrors.userMessageIfNeeded(for: error) {
                await MainActor.run { errorMessage = msg }
            }
        }
    }

    private func addAssignment(_ item: SportsSupplementCatalogItem) async -> Bool {
        await MainActor.run {
            isMutatingAssignment = true
            mutatingSupplementId = item.id
            mutatingMessage = "Добавляю добавку"
        }
        defer {
            Task { @MainActor in
                isMutatingAssignment = false
                mutatingSupplementId = nil
            }
        }
        do {
            _ = try await nutritionService.createSupplementAssignment(
                coachProfileId: coachProfileId,
                traineeProfileId: traineeProfileId,
                supplementId: item.id,
                dosage: nil,
                dosageValue: item.defaultDosageValue,
                dosageUnit: item.resolvedDosageUnit,
                timing: nil,
                frequency: nil,
                note: nil
            )
            let loaded = try await nutritionService.fetchSupplementAssignmentsForCoach(
                coachProfileId: coachProfileId,
                traineeProfileId: traineeProfileId
            )
            await MainActor.run {
                assignments = loaded.sorted { $0.updatedAt > $1.updatedAt }
                onChanged(assignments)
                AppDesign.triggerSuccessHaptic()
            }
            return true
        } catch {
            if let msg = AppErrors.userMessageIfNeeded(for: error) {
                await MainActor.run { errorMessage = msg }
            }
            return false
        }
    }

    @MainActor
    private func updateAssignment(
        _ draft: SupplementEditDraft,
        payload: SupplementEditPayload
    ) async throws {
        let normalizedDosageValue = payload.dosageValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : payload.dosageValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDosage = composeLegacyDosage(value: normalizedDosageValue, unit: payload.dosageUnit)
        let normalizedTiming = payload.timing.isEmpty ? nil : payload.timing
        let normalizedFrequency = payload.frequency.isEmpty ? nil : payload.frequency
        let normalizedNote = payload.note.isEmpty ? nil : payload.note

        _ = try await nutritionService.updateSupplementAssignment(
            assignmentId: draft.id,
            dosage: normalizedDosage,
            dosageValue: normalizedDosageValue,
            dosageUnit: payload.dosageUnit,
            timing: normalizedTiming,
            frequency: normalizedFrequency,
            note: normalizedNote
        )
        let loaded = try await nutritionService.fetchSupplementAssignmentsForCoach(
            coachProfileId: coachProfileId,
            traineeProfileId: traineeProfileId
        )
        await MainActor.run {
            assignments = loaded.sorted { $0.updatedAt > $1.updatedAt }
            onChanged(assignments)
            AppDesign.triggerSuccessHaptic()
        }
    }

    private var filteredCatalog: [SportsSupplementCatalogItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return catalog }
        return catalog.filter { item in
            item.name.localizedCaseInsensitiveContains(query)
                || item.description.localizedCaseInsensitiveContains(query)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            AppTablerIcon("search-default")
                .foregroundStyle(AppColors.accent)
            TextField("Поиск добавки", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .font(.subheadline)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(AppColors.accent.opacity(0.28), lineWidth: 1)
        )
    }

    private func removeAssignment(_ assignment: TraineeSportsSupplementAssignment) async {
        await MainActor.run {
            isMutatingAssignment = true
            mutatingSupplementId = assignment.supplementId
            mutatingMessage = "Удаляю добавку"
        }
        defer {
            Task { @MainActor in
                isMutatingAssignment = false
                mutatingSupplementId = nil
            }
        }
        do {
            try await nutritionService.deleteSupplementAssignment(assignmentId: assignment.id)
            let loaded = try await nutritionService.fetchSupplementAssignmentsForCoach(
                coachProfileId: coachProfileId,
                traineeProfileId: traineeProfileId
            )
            await MainActor.run {
                assignments = loaded.sorted { $0.updatedAt > $1.updatedAt }
                onChanged(assignments)
                AppDesign.triggerSelectionHaptic()
            }
        } catch {
            if let msg = AppErrors.userMessageIfNeeded(for: error) {
                await MainActor.run { errorMessage = msg }
            }
        }
    }

    private func openEditSheetFromMenu(for assignment: TraineeSportsSupplementAssignment) {
        let draft = SupplementEditDraft(
            id: assignment.id,
            supplementId: assignment.supplementId,
            supplementName: assignment.supplementName,
            dosageValue: assignment.dosageValue ?? parsedDosageValueFallback(assignment.dosage) ?? "",
            dosageUnit: assignment.dosageUnit,
            timing: assignment.timing ?? "",
            frequency: assignment.frequency ?? "",
            note: assignment.note ?? ""
        )

        Task { @MainActor in
            // Let context menu fully dismiss before presenting sheet.
            try? await Task.sleep(nanoseconds: 180_000_000)
            editingDraft = draft
            showEditSheet = true
        }
    }

    private func parsedDosageValueFallback(_ legacyDosage: String?) -> String? {
        guard let legacyDosage else { return nil }
        let trimmed = legacyDosage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let firstToken = trimmed.split(separator: " ").first.map(String.init) ?? ""
        let normalized = firstToken.replacingOccurrences(of: ",", with: ".")
        return Double(normalized) == nil ? nil : firstToken
    }

    private func composeLegacyDosage(value: String?, unit: SupplementDosageUnit?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        guard let unit else { return value }
        return "\(value) \(unit.displayName)"
    }

    @ViewBuilder
    private func typeChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            let chipBackground = isSelected ? AppColors.accent : AppColors.secondarySystemGroupedBackground
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? AppColors.white : AppColors.label)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(chipBackground, in: Capsule())
        }
        .buttonStyle(PressableButtonStyle(cornerRadius: 20))
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

    private var supplementsAssignedSkeleton: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonLine(width: 150, height: 12)
                    SkeletonLine(width: 90, height: 10)
                    HStack(spacing: 8) {
                        SkeletonLine(width: 90, height: 10)
                        SkeletonLine(width: 110, height: 10)
                        SkeletonLine(width: 80, height: 10)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.tertiarySystemFill, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var supplementsCatalogSkeleton: some View {
        VStack(alignment: .leading, spacing: 8) {
            SkeletonBlock(height: 42, cornerRadius: 10)
            ForEach(0..<3, id: \.self) { _ in
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonLine(width: 140, height: 12)
                        SkeletonLine(width: 80, height: 10)
                        SkeletonLine(width: 190, height: 10)
                    }
                    Spacer()
                    SkeletonBlock(width: 14, height: 14, cornerRadius: 7)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.tertiarySystemFill, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

private struct SupplementAssignmentEditScreen: View {
    @MainActor
    final class FormModel: ObservableObject {
        @Published var dosageValue: String
        @Published var dosageUnit: SupplementDosageUnit?
        @Published var timing: String
        @Published var frequency: String
        @Published var note: String

        init(dosageValue: String, dosageUnit: SupplementDosageUnit?, timing: String, frequency: String, note: String) {
            self.dosageValue = dosageValue
            self.dosageUnit = dosageUnit
            self.timing = timing
            self.frequency = frequency
            self.note = note
        }
    }

    let supplementName: String
    let initialDosageValue: String
    let initialDosageUnit: SupplementDosageUnit?
    let initialTiming: String
    let initialFrequency: String
    let initialNote: String
    let onSave: @MainActor (CoachSupplementsEditorSheet.SupplementEditPayload) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var form: FormModel
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        supplementName: String,
        initialDosageValue: String,
        initialDosageUnit: SupplementDosageUnit?,
        initialTiming: String,
        initialFrequency: String,
        initialNote: String,
        onSave: @escaping @MainActor (CoachSupplementsEditorSheet.SupplementEditPayload) async throws -> Void
    ) {
        self.supplementName = supplementName
        self.initialDosageValue = initialDosageValue
        self.initialDosageUnit = initialDosageUnit
        self.initialTiming = initialTiming
        self.initialFrequency = initialFrequency
        self.initialNote = initialNote
        self.onSave = onSave
        _form = StateObject(
            wrappedValue: FormModel(
                dosageValue: initialDosageValue,
                dosageUnit: initialDosageUnit,
                timing: initialTiming,
                frequency: initialFrequency,
                note: initialNote
            )
        )
    }

    var body: some View {
        MainSheet(
            title: "Параметры добавки",
            onBack: { dismiss() },
            trailing: {
                if isSaving {
                    ProgressView().scaleEffect(0.9)
                } else {
                    Button("Сохранить") { submit() }
                        .fontWeight(.regular)
                }
            },
            content: {
                ScrollView {
                    VStack(spacing: 0) {
                        SettingsCard(title: supplementName) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Все поля необязательны. Заполняйте только то, что важно для назначения.")
                                    .font(.footnote)
                                    .foregroundStyle(AppColors.secondaryLabel)
                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Значение дозировки")
                                            .font(.caption)
                                            .foregroundStyle(AppColors.secondaryLabel)
                                        TextField("500", text: $form.dosageValue)
                                            .font(.subheadline)
                                            .keyboardType(.decimalPad)
                                            .textFieldStyle(.plain)
                                            .formInputStyle()
                                            .onChange(of: form.dosageValue) { _, newValue in
                                                let sanitized = sanitizeDosageValueInput(newValue)
                                                if sanitized != newValue {
                                                    form.dosageValue = sanitized
                                                }
                                            }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Единица")
                                            .font(.caption)
                                            .foregroundStyle(AppColors.secondaryLabel)
                                        Menu {
                                            Button("Не выбрано") { form.dosageUnit = nil }
                                            ForEach(SupplementDosageUnit.allCases) { unit in
                                                Button(unit.displayName) { form.dosageUnit = unit }
                                            }
                                        } label: {
                                            HStack {
                                                Text(form.dosageUnit?.displayName ?? "Не выбрано")
                                                    .font(.subheadline)
                                                    .foregroundStyle(AppColors.label)
                                                    .lineLimit(1)
                                                Spacer(minLength: 8)
                                                AppTablerIcon("chevron.down")
                                                    .appIcon(.s14)
                                                    .foregroundStyle(AppColors.secondaryLabel)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .formInputStyle()
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                Text("Введите только число, например 500 или 2.5")
                                    .font(.caption2)
                                    .foregroundStyle(AppColors.secondaryLabel)
                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Время приема")
                                            .font(.caption)
                                            .foregroundStyle(AppColors.secondaryLabel)
                                        TextField("После завтрака", text: $form.timing)
                                            .font(.subheadline)
                                            .textFieldStyle(.plain)
                                            .formInputStyle()
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Частота")
                                            .font(.caption)
                                            .foregroundStyle(AppColors.secondaryLabel)
                                        TextField("Ежедневно", text: $form.frequency)
                                            .font(.subheadline)
                                            .textFieldStyle(.plain)
                                            .formInputStyle()
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    Spacer(minLength: 0)
                                }
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Заметка")
                                        .font(.caption)
                                        .foregroundStyle(AppColors.secondaryLabel)
                                    TextEditor(text: $form.note)
                                        .font(.subheadline)
                                        .frame(minHeight: 120)
                                        .scrollContentBackground(.hidden)
                                        .formInputStyle()
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
            }
        )
    }

    private func submit() {
        let currentDosageValue = form.dosageValue
        let currentDosageUnit = form.dosageUnit
        let currentTiming = form.timing
        let currentFrequency = form.frequency
        let currentNote = form.note
        let payload = CoachSupplementsEditorSheet.SupplementEditPayload(
            dosageValue: currentDosageValue,
            dosageUnit: currentDosageUnit,
            timing: currentTiming,
            frequency: currentFrequency,
            note: currentNote
        )
        errorMessage = nil
        isSaving = true
        Task { @MainActor in
            do {
                try await onSave(payload)
                isSaving = false
                dismiss()
            } catch {
                let message = AppErrors.userMessageIfNeeded(for: error) ?? "Не удалось сохранить параметры добавки"
                isSaving = false
                errorMessage = message
            }
        }
    }

    private func sanitizeDosageValueInput(_ raw: String) -> String {
        var text = raw.replacingOccurrences(of: ",", with: ".")
        text = text.filter { $0.isNumber || $0 == "." }
        if let dot = text.firstIndex(of: ".") {
            let before = text[..<text.index(after: dot)]
            let after = text[text.index(after: dot)...].replacingOccurrences(of: ".", with: "")
            text = String(before) + after
        }
        return text
    }
}

private struct EditNutritionPlanSheet: View {
    let initialDraft: NutritionPlanDraft
    let canEditWeight: Bool
    let lockedWeightKg: Double
    let onSave: (Double, Double, Double, Double, String?) async throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var weightKg: Double
    @State private var weightText: String
    @State private var proteinPerKg: Double
    @State private var fatPerKg: Double
    @State private var carbsPerKg: Double
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        initialDraft: NutritionPlanDraft,
        canEditWeight: Bool,
        lockedWeightKg: Double,
        onSave: @escaping (Double, Double, Double, Double, String?) async throws -> Void
    ) {
        self.initialDraft = initialDraft
        self.canEditWeight = canEditWeight
        self.lockedWeightKg = lockedWeightKg
        self.onSave = onSave
        let initialWeight: Double
        if canEditWeight {
            initialWeight = max(0.1, initialDraft.weightKg ?? lockedWeightKg)
        } else {
            initialWeight = max(0.1, lockedWeightKg)
        }
        _weightKg = State(initialValue: initialWeight)
        let initialRounded = (initialWeight * 10).rounded() / 10
        _weightText = State(initialValue: initialRounded.measurementFormatted)
        _proteinPerKg = State(initialValue: initialDraft.proteinPerKg > 0 ? initialDraft.proteinPerKg : 0.1)
        _fatPerKg = State(initialValue: initialDraft.fatPerKg > 0 ? initialDraft.fatPerKg : 0.1)
        _carbsPerKg = State(initialValue: initialDraft.carbsPerKg > 0 ? initialDraft.carbsPerKg : 0.1)
    }

    var body: some View {
        MainSheet(
            title: "Питание",
            onBack: { dismiss() },
            trailing: {
                if isSaving {
                    ProgressView()
                        .scaleEffect(0.9)
                } else {
                    Button("Сохранить") {
                        submit()
                    }
                    .disabled(!canSave)
                }
            },
            content: {
                ScrollView {
                    VStack(spacing: 0) {
                        SettingsCard(title: "Расчёт") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Нормы на кг веса (Б/Ж/У).")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.secondaryLabel)
                                Text("Значения считаются автоматически.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.secondaryLabel)
                                
                                if canEditWeight {
                                    weightKeyboardInput
                                } else {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Вес для расчёта")
                                            .font(.caption)
                                            .foregroundStyle(AppColors.secondaryLabel)
                                        Text("\(lockedWeightKg.measurementFormatted) кг")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(AppColors.label)
                                    }
                                }

                                MacroTripleInputRow(
                                    proteinPerKg: $proteinPerKg,
                                    fatPerKg: $fatPerKg,
                                    carbsPerKg: $carbsPerKg
                                )
                            }
                        }

                        SettingsCard(title: "Итог") {
                            NutritionPreviewCard(preview: nutritionPreview)
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
            }
        )
    }

    private var canSave: Bool {
        weightKg > 0 && proteinPerKg > 0 && fatPerKg > 0 && carbsPerKg > 0
    }

    private var nutritionPreview: NutritionPreviewModel {
        NutritionPreviewModel(
            weightKg: weightKg,
            proteinPerKg: proteinPerKg,
            fatPerKg: fatPerKg,
            carbsPerKg: carbsPerKg
        )
    }

    private func submit() {
        errorMessage = nil
        isSaving = true

        Task {
            do {
                // Поле комментария временно убрано из UI: всегда отправляем `nil`.
                try await onSave(weightKg, proteinPerKg, fatPerKg, carbsPerKg, nil)
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                let message = AppErrors.userMessageIfNeeded(for: error) ?? "Не удалось сохранить питание"
                await MainActor.run {
                    isSaving = false
                    ToastCenter.shared.error(from: error, fallback: "Не удалось сохранить питание")
                    errorMessage = message
                }
            }
        }
    }

    private var weightKeyboardInput: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Вес, кг")
                .font(.caption)
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
