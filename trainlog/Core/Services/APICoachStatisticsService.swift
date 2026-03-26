//
//  APICoachStatisticsService.swift
//  TrainLog
//

import Foundation

@MainActor
final class APICoachStatisticsService: CoachStatisticsServiceProtocol {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func fetchStatistics(coachProfileId: String, month: String) async throws -> CoachStatisticsDTO {
        let path = "api/v1/profiles/\(coachProfileId)/statistics"
        let query: [String: String] = ["month": month]
        return try await client.request(path: path, query: query, useDateTimeDecoder: false)
    }
}
