//
//  NutritionService.swift
//  TrainLog
//

import Foundation

protocol NutritionServiceProtocol {
    func fetchNutritionPlan(coachProfileId: String, traineeProfileId: String) async throws -> NutritionPlan?
    func fetchNutritionPlansForTrainee(traineeProfileId: String) async throws -> TraineeNutritionPlansFeed
    func createNutritionPlan(
        coachProfileId: String,
        traineeProfileId: String,
        weightKg: Double?,
        proteinPerKg: Double,
        fatPerKg: Double,
        carbsPerKg: Double,
        comment: String?
    ) async throws -> NutritionPlan
    func updateNutritionPlan(
        planId: String,
        coachProfileId: String,
        traineeProfileId: String,
        weightKg: Double?,
        proteinPerKg: Double,
        fatPerKg: Double,
        carbsPerKg: Double,
        comment: String?
    ) async throws -> NutritionPlan

    // MARK: - Sports supplements

    func fetchSupplementCatalog(type: SportsSupplementType?) async throws -> [SportsSupplementCatalogItem]
    func fetchSupplementAssignmentsForCoach(coachProfileId: String, traineeProfileId: String) async throws -> [TraineeSportsSupplementAssignment]
    func fetchSupplementAssignmentsForTrainee(traineeProfileId: String) async throws -> [TraineeSportsSupplementAssignment]
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
    ) async throws -> TraineeSportsSupplementAssignment
    func updateSupplementAssignment(
        assignmentId: String,
        dosage: String?,
        dosageValue: String?,
        dosageUnit: SupplementDosageUnit?,
        timing: String?,
        frequency: String?,
        note: String?
    ) async throws -> TraineeSportsSupplementAssignment
    func deleteSupplementAssignment(assignmentId: String) async throws
}
