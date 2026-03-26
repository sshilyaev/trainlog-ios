//
//  CoachStatisticsService.swift
//  TrainLog
//

import Foundation

/// Ответ API статистики тренера (GET /api/v1/profiles/{id}/statistics).
struct CoachStatisticsDTO: Decodable {
    let period: String
    let trainees: TraineesBlock
    let visits: VisitsBlock
    let memberships: MembershipsBlock

    struct TraineesBlock: Decodable {
        let activeCount: Int
        let newThisMonth: Int
    }

    struct VisitsBlock: Decodable {
        let thisMonth: Int
        let previousMonth: Int
        let total: Int
        /// По абонементу за выбранный месяц (опционально).
        let thisMonthBySubscription: Int?
        /// Разовые оплаченные визиты за выбранный месяц.
        let thisMonthOneTimePaid: Int?
        /// Разовые визиты в долг за выбранный месяц.
        let thisMonthOneTimeDebt: Int?
        /// Отменённые визиты за выбранный месяц.
        let thisMonthCancelled: Int?
        /// По абонементу за предыдущий месяц.
        let previousMonthBySubscription: Int?
        /// Разовые оплаченные визиты за предыдущий месяц.
        let previousMonthOneTimePaid: Int?
        /// Разовые визиты в долг за предыдущий месяц.
        let previousMonthOneTimeDebt: Int?
        /// Отменённые визиты за предыдущий месяц.
        let previousMonthCancelled: Int?
    }

    struct MembershipsBlock: Decodable {
        let activeCount: Int
        let endingSoonCount: Int
        let unlimitedCount: Int?
        let byVisitsCount: Int?
    }
}

protocol CoachStatisticsServiceProtocol: Sendable {
    func fetchStatistics(coachProfileId: String, month: String) async throws -> CoachStatisticsDTO
}
