//
//  Membership.swift
//  TrainLog
//

import Foundation

enum MembershipStatus: String, Codable, CaseIterable {
    case active
    case finished
    case cancelled
}

/// Тип абонемента: по количеству посещений или безлимитный по дням.
enum MembershipKind: String, Codable, CaseIterable {
    /// По количеству занятий (totalSessions, usedSessions).
    case byVisits
    /// Безлимитный до даты окончания (startDate, endDate, freezeDays).
    case unlimited
}

/// Абонемент: либо по количеству посещений, либо безлимитный до даты окончания.
struct Membership: Identifiable, Codable, Equatable {
    let id: String
    let coachProfileId: String
    let traineeProfileId: String
    let createdAt: Date
    var kind: MembershipKind

    /// Только для kind == .byVisits: всего занятий.
    var totalSessions: Int
    /// Списанно посещений (для обоих типов).
    var usedSessions: Int

    /// Только для kind == .unlimited: начало действия.
    var startDate: Date?
    /// Только для kind == .unlimited: плановое окончание.
    var endDate: Date?
    /// Только для kind == .unlimited: дней заморозки; фактическое окончание = endDate + freezeDays.
    var freezeDays: Int

    var priceRub: Int?
    var status: MembershipStatus
    var displayCode: String?
    /// Завершён досрочно по действию тренера (закрыть абонемент).
    var closedManually: Bool

    init(
        id: String,
        coachProfileId: String,
        traineeProfileId: String,
        createdAt: Date = Date(),
        kind: MembershipKind,
        totalSessions: Int = 0,
        usedSessions: Int = 0,
        startDate: Date? = nil,
        endDate: Date? = nil,
        freezeDays: Int = 0,
        priceRub: Int? = nil,
        status: MembershipStatus = .active,
        displayCode: String? = nil,
        closedManually: Bool = false
    ) {
        self.id = id
        self.coachProfileId = coachProfileId
        self.traineeProfileId = traineeProfileId
        self.createdAt = createdAt
        self.kind = kind
        self.totalSessions = max(0, totalSessions)
        self.usedSessions = max(0, usedSessions)
        self.startDate = startDate
        self.endDate = endDate
        self.freezeDays = max(0, freezeDays)
        self.priceRub = priceRub
        self.status = status
        self.displayCode = displayCode
        self.closedManually = closedManually
    }

    /// Осталось занятий (только для .byVisits).
    var remainingSessions: Int {
        guard kind == .byVisits else { return 0 }
        return max(0, totalSessions - usedSessions)
    }

    /// Фактическая дата окончания с учётом заморозки (только для .unlimited).
    var effectiveEndDate: Date? {
        guard kind == .unlimited, let end = endDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: freezeDays, to: end) ?? end
    }

    /// Абонемент действует.
    var isActive: Bool {
        guard status == .active else { return false }
        switch kind {
        case .byVisits:
            return remainingSessions > 0
        case .unlimited:
            guard let start = startDate, let end = effectiveEndDate else { return false }
            let calendar = Calendar.current
            let now = calendar.startOfDay(for: Date())
            let startDay = calendar.startOfDay(for: start)
            let endDay = calendar.startOfDay(for: end)
            return now >= startDay && now <= endDay
        }
    }

    /// Можно ли списать визит с датой `visitDate` на этот абонемент.
    func canAccept(visitDate: Date) -> Bool {
        guard status == .active else { return false }
        switch kind {
        case .byVisits:
            return remainingSessions > 0
        case .unlimited:
            guard let start = startDate, let end = effectiveEndDate else { return false }
            let calendar = Calendar.current
            let day = calendar.startOfDay(for: visitDate)
            let startDay = calendar.startOfDay(for: start)
            let endDay = calendar.startOfDay(for: end)
            return day >= startDay && day <= endDay
        }
    }
}
