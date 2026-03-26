//
//  APINutritionService.swift
//  TrainLog
//

import Foundation

final class APINutritionService: NutritionServiceProtocol {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func fetchNutritionPlan(coachProfileId: String, traineeProfileId: String) async throws -> NutritionPlan? {
        struct ListResponse: Decodable {
            let nutritionPlans: [NutritionPlan]
        }

        let response: ListResponse = try await client.request(
            path: "api/v1/nutrition-plans",
            query: [
                "coachProfileId": coachProfileId,
                "traineeProfileId": traineeProfileId
            ],
            useDateTimeDecoder: true
        )
        return response.nutritionPlans.first
    }

    func fetchNutritionPlansForTrainee(traineeProfileId: String) async throws -> TraineeNutritionPlansFeed {
        struct FeedResponse: Decodable {
            let nutritionPlans: [NutritionPlan]
            let coachProfiles: [Profile]
        }

        let response: FeedResponse = try await client.request(
            path: "api/v1/nutrition-plans",
            query: [
                "traineeProfileId": traineeProfileId,
                "as": "trainee",
                "embed": "coachProfiles"
            ],
            useDateTimeDecoder: true
        )
        return TraineeNutritionPlansFeed(plans: response.nutritionPlans, coachProfiles: response.coachProfiles)
    }

    private func buildJSONBody(
        coachProfileId: String,
        traineeProfileId: String,
        weightKg: Double?,
        proteinPerKg: Double,
        fatPerKg: Double,
        carbsPerKg: Double,
        comment: String?
    ) -> [String: Any] {
        var jsonBody: [String: Any] = [
            "coachProfileId": coachProfileId,
            "traineeProfileId": traineeProfileId,
            "proteinPerKg": proteinPerKg,
            "fatPerKg": fatPerKg,
            "carbsPerKg": carbsPerKg
        ]
        if let weightKg {
            jsonBody["weightKg"] = weightKg
        }
        // Комментарий: если nil, НЕ отправляем поле, чтобы PATCH/POST не затирал существующий комментарий.
        if let comment {
            jsonBody["comment"] = comment
        }
        return jsonBody
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
        return try await client.request(
            path: "api/v1/nutrition-plans",
            method: "POST",
            jsonBody: buildJSONBody(
                coachProfileId: coachProfileId,
                traineeProfileId: traineeProfileId,
                weightKg: weightKg,
                proteinPerKg: proteinPerKg,
                fatPerKg: fatPerKg,
                carbsPerKg: carbsPerKg,
                comment: comment
            ),
            useDateTimeDecoder: true
        )
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
        // OpenAPI contract for PATCH /nutrition-plans/{id} does not include coachProfileId/traineeProfileId.
        // Keep method signature for call-site compatibility, but do not send these fields.
        var body: [String: Any] = [
            "proteinPerKg": proteinPerKg,
            "fatPerKg": fatPerKg,
            "carbsPerKg": carbsPerKg
        ]
        if let weightKg {
            body["weightKg"] = weightKg
        }
        if let comment {
            body["comment"] = comment
        }

        return try await client.request(
            path: "api/v1/nutrition-plans/\(planId)",
            method: "PATCH",
            jsonBody: body,
            useDateTimeDecoder: true
        )
    }

    // MARK: - Sports supplements

    func fetchSupplementCatalog(type: SportsSupplementType?) async throws -> [SportsSupplementCatalogItem] {
        struct CatalogResponse: Decodable {
            let supplements: [SportsSupplementCatalogItem]
        }

        var query: [String: String] = [:]
        if let type {
            query["type"] = type.rawValue
        }

        let response: CatalogResponse = try await client.request(
            path: "api/v1/supplements/catalog",
            query: query.isEmpty ? nil : query,
            useDateTimeDecoder: true
        )
        return response.supplements
            .filter(\.isActive)
            .sorted {
                let lhsOrder = $0.sortOrder ?? Int.max
                let rhsOrder = $1.sortOrder ?? Int.max
                if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    func fetchSupplementAssignmentsForCoach(coachProfileId: String, traineeProfileId: String) async throws -> [TraineeSportsSupplementAssignment] {
        struct AssignmentsResponse: Decodable {
            let assignments: [TraineeSportsSupplementAssignment]
        }
        let response: AssignmentsResponse = try await client.request(
            path: "api/v1/supplements/assignments",
            query: [
                "coachProfileId": coachProfileId,
                "traineeProfileId": traineeProfileId
            ],
            useDateTimeDecoder: true
        )
        return response.assignments.sorted { $0.updatedAt > $1.updatedAt }
    }

    func fetchSupplementAssignmentsForTrainee(traineeProfileId: String) async throws -> [TraineeSportsSupplementAssignment] {
        struct AssignmentsResponse: Decodable {
            let assignments: [TraineeSportsSupplementAssignment]
        }
        let response: AssignmentsResponse = try await client.request(
            path: "api/v1/supplements/assignments",
            query: [
                "traineeProfileId": traineeProfileId,
                "as": "trainee"
            ],
            useDateTimeDecoder: true
        )
        return response.assignments.sorted { $0.updatedAt > $1.updatedAt }
    }

    func createSupplementAssignment(
        coachProfileId: String,
        traineeProfileId: String,
        supplementId: String,
        dosage: String?,
        timing: String?,
        frequency: String?,
        note: String?
    ) async throws -> TraineeSportsSupplementAssignment {
        var body: [String: Any] = [
            "coachProfileId": coachProfileId,
            "traineeProfileId": traineeProfileId,
            "supplementId": supplementId
        ]
        if let dosage, !dosage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { body["dosage"] = dosage }
        if let timing, !timing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { body["timing"] = timing }
        if let frequency, !frequency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { body["frequency"] = frequency }
        if let note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { body["note"] = note }

        return try await client.request(
            path: "api/v1/supplements/assignments",
            method: "POST",
            jsonBody: body,
            useDateTimeDecoder: true
        )
    }

    func updateSupplementAssignment(
        assignmentId: String,
        dosage: String?,
        timing: String?,
        frequency: String?,
        note: String?
    ) async throws -> TraineeSportsSupplementAssignment {
        struct UpdateBody: Encodable {
            let dosage: String
            let timing: String
            let frequency: String
            let note: String
        }

        // Send a stable typed body instead of [String: Any] + JSONSerialization.
        // Empty strings are accepted by backend and normalized to null there.
        let body = UpdateBody(
            dosage: dosage ?? "",
            timing: timing ?? "",
            frequency: frequency ?? "",
            note: note ?? ""
        )

        let response: TraineeSportsSupplementAssignment = try await client.request(
            path: "api/v1/supplements/assignments/\(assignmentId)",
            method: "PATCH",
            body: body,
            useDateTimeDecoder: true
        )
        return response
    }

    func deleteSupplementAssignment(assignmentId: String) async throws {
        try await client.requestNoContent(
            path: "api/v1/supplements/assignments/\(assignmentId)",
            method: "DELETE"
        )
    }
}
