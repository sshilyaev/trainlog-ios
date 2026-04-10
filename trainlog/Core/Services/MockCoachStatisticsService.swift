//
//  MockCoachStatisticsService.swift
//  TrainLog
//

import Foundation

@MainActor
final class MockCoachStatisticsService: CoachStatisticsServiceProtocol {
    func fetchStatistics(coachProfileId: String, month: String, periodMonths: Int) async throws -> CoachStatisticsDTO {
        // Разные цифры по месяцу и длине периода — чтобы в превью было видно смену.
        let h = abs(month.hashValue % 9)
        let pm = max(1, min(6, periodMonths))
        let activeTrainees = 8 + h
        let activeMemberships = 5 + (h % 5)
        let uniqueWithVisits = 4 + h + pm * 2
        let createdMemberships = 1 + (h % 5) + pm
        return CoachStatisticsDTO(
            period: month,
            trainees: .init(
                activeCount: activeTrainees,
                newThisMonth: max(0, h % 3),
                uniqueWithVisitsInPeriod: uniqueWithVisits
            ),
            visits: .init(
                thisMonth: 40 + h,
                previousMonth: 35 + h,
                total: 1100 + h * 10,
                thisMonthBySubscription: 32,
                thisMonthOneTimePaid: 8,
                thisMonthOneTimeDebt: 5,
                thisMonthCancelled: 3,
                previousMonthBySubscription: 28,
                previousMonthOneTimePaid: 6,
                previousMonthOneTimeDebt: 4,
                previousMonthCancelled: 2
            ),
            memberships: .init(
                activeCount: activeMemberships,
                endingSoonCount: h % 4,
                unlimitedCount: 2 + h % 3,
                byVisitsCount: 3 + h % 4,
                createdInPeriod: createdMemberships
            )
        )
    }
}
