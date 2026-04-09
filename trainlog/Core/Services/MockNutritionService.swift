//
//  MockNutritionService.swift
//  TrainLog
//

import Foundation

final class MockNutritionService: NutritionServiceProtocol {
    private var storage: [NutritionPlan]
    private var coachProfilesById: [String: Profile]
    private var supplementCatalog: [SportsSupplementCatalogItem]
    private var supplementAssignments: [TraineeSportsSupplementAssignment]

    init(plans: [NutritionPlan] = [], coachProfiles: [Profile] = []) {
        self.storage = plans
        self.coachProfilesById = Dictionary(uniqueKeysWithValues: coachProfiles.map { ($0.id, $0) })
        self.supplementCatalog = [
            SportsSupplementCatalogItem(id: "supp_vit_d3", name: "Vitamin D3", type: .vitamin, description: "Поддержка уровня витамина D", isActive: true, sortOrder: 1, defaultDosageUnit: .capsule),
            SportsSupplementCatalogItem(id: "supp_omega_3", name: "Omega-3", type: .other, description: "Поддержка рациона по жирным кислотам", isActive: true, sortOrder: 2, defaultDosageUnit: .capsule),
            SportsSupplementCatalogItem(id: "supp_magnesium", name: "Magnesium", type: .mineral, description: "Минерал для повседневного баланса", isActive: true, sortOrder: 3, defaultDosageUnit: .milligram),
            SportsSupplementCatalogItem(id: "supp_creatine", name: "Creatine Monohydrate", type: .sportsNutrition, description: "Популярная спортивная добавка", isActive: true, sortOrder: 4, defaultDosageUnit: .gram)
        ]
        self.supplementAssignments = []
    }

    func fetchNutritionPlan(coachProfileId: String, traineeProfileId: String) async throws -> NutritionPlan? {
        try await Task.sleep(nanoseconds: 120_000_000)
        return storage.first {
            $0.coachProfileId == coachProfileId && $0.traineeProfileId == traineeProfileId
        }
    }

    func fetchNutritionPlansForTrainee(traineeProfileId: String) async throws -> TraineeNutritionPlansFeed {
        try await Task.sleep(nanoseconds: 120_000_000)
        let plans = storage
            .filter { $0.traineeProfileId == traineeProfileId }
            .sorted { $0.updatedAt > $1.updatedAt }
        let coaches = plans.compactMap { coachProfilesById[$0.coachProfileId] }
        return TraineeNutritionPlansFeed(plans: plans, coachProfiles: coaches)
    }

    private func buildPlan(
        id: String,
        coachProfileId: String,
        traineeProfileId: String,
        weightKg: Double?,
        proteinPerKg: Double,
        fatPerKg: Double,
        carbsPerKg: Double,
        comment: String?,
        existingCreatedAt: Date?
    ) throws -> NutritionPlan {
        guard let weightKg, weightKg > 0 else {
            throw APIResponseError(
                statusCode: 422,
                errorMessage: "Нужен вес",
                backendMessage: "Для расчёта питания нужно указать вес подопечного",
                validationMessages: [],
                backendCode: "weight_required"
            )
        }
        let proteinGrams = proteinPerKg * weightKg
        let fatGrams = fatPerKg * weightKg
        let carbsGrams = carbsPerKg * weightKg
        let calories = Int((proteinGrams * 4 + fatGrams * 9 + carbsGrams * 4).rounded())
        let now = Date()
        return NutritionPlan(
            id: id,
            coachProfileId: coachProfileId,
            traineeProfileId: traineeProfileId,
            weightKgUsed: weightKg,
            proteinPerKg: proteinPerKg,
            fatPerKg: fatPerKg,
            carbsPerKg: carbsPerKg,
            proteinGrams: proteinGrams,
            fatGrams: fatGrams,
            carbsGrams: carbsGrams,
            calories: calories,
            comment: comment,
            createdAt: existingCreatedAt ?? now,
            updatedAt: now
        )
    }

    func createNutritionPlan(
        coachProfileId: String,
        traineeProfileId: String,
        weightKg: Double?,
        proteinPerKg: Double,
        fatPerKg: Double,
        carbsPerKg: Double,
        comment: String?
    ) async throws -> NutritionPlan {
        try await Task.sleep(nanoseconds: 120_000_000)
        let plan = try buildPlan(
            id: UUID().uuidString,
            coachProfileId: coachProfileId,
            traineeProfileId: traineeProfileId,
            weightKg: weightKg,
            proteinPerKg: proteinPerKg,
            fatPerKg: fatPerKg,
            carbsPerKg: carbsPerKg,
            comment: comment,
            existingCreatedAt: nil
        )
        storage.removeAll {
            $0.coachProfileId == plan.coachProfileId && $0.traineeProfileId == plan.traineeProfileId
        }
        storage.append(plan)
        return plan
    }

    func updateNutritionPlan(
        planId: String,
        coachProfileId: String,
        traineeProfileId: String,
        weightKg: Double?,
        proteinPerKg: Double,
        fatPerKg: Double,
        carbsPerKg: Double,
        comment: String?
    ) async throws -> NutritionPlan {
        try await Task.sleep(nanoseconds: 120_000_000)
        let existingCreatedAt = storage.first(where: { $0.id == planId })?.createdAt
        let plan = try buildPlan(
            id: planId,
            coachProfileId: coachProfileId,
            traineeProfileId: traineeProfileId,
            weightKg: weightKg,
            proteinPerKg: proteinPerKg,
            fatPerKg: fatPerKg,
            carbsPerKg: carbsPerKg,
            comment: comment,
            existingCreatedAt: existingCreatedAt
        )
        storage.removeAll { $0.id == planId }
        storage.removeAll {
            $0.coachProfileId == plan.coachProfileId && $0.traineeProfileId == plan.traineeProfileId
        }
        storage.append(plan)
        return plan
    }

    // MARK: - Sports supplements

    func fetchSupplementCatalog(type: SportsSupplementType?) async throws -> [SportsSupplementCatalogItem] {
        try await Task.sleep(nanoseconds: 80_000_000)
        let items = supplementCatalog.filter { item in
            guard item.isActive else { return false }
            guard let type else { return true }
            return item.type == type
        }
        return items.sorted {
            let lhsOrder = $0.sortOrder ?? Int.max
            let rhsOrder = $1.sortOrder ?? Int.max
            if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func fetchSupplementAssignmentsForCoach(coachProfileId: String, traineeProfileId: String) async throws -> [TraineeSportsSupplementAssignment] {
        try await Task.sleep(nanoseconds: 80_000_000)
        return supplementAssignments
            .filter { $0.coachProfileId == coachProfileId && $0.traineeProfileId == traineeProfileId }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func fetchSupplementAssignmentsForTrainee(traineeProfileId: String) async throws -> [TraineeSportsSupplementAssignment] {
        try await Task.sleep(nanoseconds: 80_000_000)
        return supplementAssignments
            .filter { $0.traineeProfileId == traineeProfileId }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func createSupplementAssignment(
        coachProfileId: String,
        traineeProfileId: String,
        supplementId: String,
        dosage: String?,
        dosageValue: String?,
        dosageUnit: SupplementDosageUnit?,
        timing: String?,
        frequency: String?,
        note: String?
    ) async throws -> TraineeSportsSupplementAssignment {
        try await Task.sleep(nanoseconds: 80_000_000)
        guard let item = supplementCatalog.first(where: { $0.id == supplementId && $0.isActive }) else {
            throw APIResponseError(
                statusCode: 422,
                errorMessage: "Добавка не найдена",
                backendMessage: "Выбранная добавка отсутствует в каталоге",
                validationMessages: [],
                backendCode: "supplement_not_found"
            )
        }

        if let existing = supplementAssignments.first(where: {
            $0.coachProfileId == coachProfileId &&
            $0.traineeProfileId == traineeProfileId &&
            $0.supplementId == supplementId
        }) {
            return existing
        }

        let now = Date()
        let created = TraineeSportsSupplementAssignment(
            id: UUID().uuidString,
            coachProfileId: coachProfileId,
            traineeProfileId: traineeProfileId,
            supplementId: item.id,
            supplementName: item.name,
            supplementType: item.type,
            supplementDescription: item.description,
            dosage: dosage,
            dosageValue: dosageValue,
            dosageUnit: dosageUnit,
            timing: timing,
            frequency: frequency,
            note: note,
            createdAt: now,
            updatedAt: now
        )
        supplementAssignments.append(created)
        return created
    }

    func updateSupplementAssignment(
        assignmentId: String,
        dosage: String?,
        dosageValue: String?,
        dosageUnit: SupplementDosageUnit?,
        timing: String?,
        frequency: String?,
        note: String?
    ) async throws -> TraineeSportsSupplementAssignment {
        try await Task.sleep(nanoseconds: 80_000_000)
        guard let idx = supplementAssignments.firstIndex(where: { $0.id == assignmentId }) else {
            throw APIResponseError(
                statusCode: 404,
                errorMessage: "Назначение не найдено",
                backendMessage: nil,
                validationMessages: [],
                backendCode: "assignment_not_found"
            )
        }
        let old = supplementAssignments[idx]
        let updated = TraineeSportsSupplementAssignment(
            id: old.id,
            coachProfileId: old.coachProfileId,
            traineeProfileId: old.traineeProfileId,
            supplementId: old.supplementId,
            supplementName: old.supplementName,
            supplementType: old.supplementType,
            supplementDescription: old.supplementDescription,
            dosage: dosage,
            dosageValue: dosageValue,
            dosageUnit: dosageUnit ?? old.dosageUnit,
            timing: timing,
            frequency: frequency,
            note: note,
            createdAt: old.createdAt,
            updatedAt: Date()
        )
        supplementAssignments[idx] = updated
        return updated
    }

    func deleteSupplementAssignment(assignmentId: String) async throws {
        try await Task.sleep(nanoseconds: 80_000_000)
        supplementAssignments.removeAll { $0.id == assignmentId }
    }
}
