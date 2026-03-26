//
//  APIGoalService.swift
//  TrainLog
//

import Foundation

final class APIGoalService: GoalServiceProtocol {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    convenience init(baseURL: URL, getIDToken: @escaping (_ forceRefresh: Bool) async -> String?) {
        self.init(client: APIClient(baseURL: baseURL, getIDToken: getIDToken))
    }

    func fetchGoals(profileId: String) async throws -> [Goal] {
        struct ListResponse: Decodable {
            let goals: [Goal]
        }
        let res: ListResponse = try await client.request(
            path: "api/v1/goals",
            query: ["profileId": profileId],
            useDateTimeDecoder: true
        )
        return res.goals.sorted { $0.targetDate < $1.targetDate }
    }

    func saveGoal(_ goal: Goal) async throws {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        let targetDateStr = fmt.string(from: goal.targetDate)
        if goal.id.isEmpty {
            struct CreateBody: Encodable {
                let profileId: String
                let measurementType: String
                let targetValue: Double
                let targetDate: String
            }
            let body = CreateBody(
                profileId: goal.profileId,
                measurementType: goal.measurementType,
                targetValue: goal.targetValue,
                targetDate: targetDateStr
            )
            _ = try await client.request(path: "api/v1/goals", method: "POST", body: body, useDateTimeDecoder: true) as Goal
        } else {
            struct PatchBody: Encodable {
                let measurementType: String?
                let targetValue: Double?
                let targetDate: String?
            }
            let body = PatchBody(
                measurementType: goal.measurementType,
                targetValue: goal.targetValue,
                targetDate: targetDateStr
            )
            _ = try await client.request(path: "api/v1/goals/\(goal.id)", method: "PATCH", body: body, useDateTimeDecoder: true) as Goal
        }
    }

    func deleteGoal(_ goal: Goal) async throws {
        try await client.requestNoContent(path: "api/v1/goals/\(goal.id)", method: "DELETE")
    }

    func deleteAllGoals(profileId: String) async throws {
        let list = try await fetchGoals(profileId: profileId)
        for g in list {
            try await client.requestNoContent(path: "api/v1/goals/\(g.id)", method: "DELETE")
        }
    }
}
