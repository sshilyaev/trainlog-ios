//
//  MockCoachStatisticsService.swift
//  TrainLog
//

import Foundation

@MainActor
final class MockCoachStatisticsService: CoachStatisticsServiceProtocol {
    func fetchStatistics(coachProfileId: String, month: String) async throws -> CoachStatisticsDTO {
        CoachStatisticsDTO(
            period: month,
            trainees: .init(activeCount: 12, newThisMonth: 1),
            visits: .init(
                thisMonth: 45,
                previousMonth: 38,
                total: 1203,
                thisMonthBySubscription: 32,
                thisMonthOneTimePaid: 8,
                thisMonthOneTimeDebt: 5,
                thisMonthCancelled: 3,
                previousMonthBySubscription: 28,
                previousMonthOneTimePaid: 6,
                previousMonthOneTimeDebt: 4,
                previousMonthCancelled: 2
            ),
            memberships: .init(activeCount: 8, endingSoonCount: 2, unlimitedCount: 3, byVisitsCount: 5)
        )
    }
}
