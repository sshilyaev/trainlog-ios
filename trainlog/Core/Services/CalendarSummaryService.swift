//
//  CalendarSummaryService.swift
//  TrainLog
//

import Foundation

/// Ответ card-summary: профиль, визиты, события и абонементы за период.
struct CardSummaryResponse {
    let profile: Profile
    let visits: [Visit]
    let events: [Event]
    let memberships: [Membership]
}

/// Ответ объединённого календаря: визиты и события за период.
struct CalendarFeedResponse {
    let visits: [Visit]
    let events: [Event]
}

protocol CalendarSummaryServiceProtocol {
    /// Один запрос вместо четырёх: профиль + визиты + события + абонементы. Период календаря — опционально (по умолчанию текущий месяц).
    func fetchCardSummary(
        coachProfileId: String,
        traineeProfileId: String,
        calendarFrom: Date?,
        calendarTo: Date?
    ) async throws -> CardSummaryResponse

    /// Один запрос вместо двух: визиты + события за период.
    func fetchCalendar(
        coachProfileId: String,
        traineeProfileId: String,
        from: Date,
        to: Date
    ) async throws -> CalendarFeedResponse
}

// MARK: - API implementation

private let calendarDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "UTC")
    return f
}()

/// DTO для memberships в card-summary (тот же формат, что в GET /memberships).
private struct MembershipDTO: Decodable {
    let id: String
    let coachProfileId: String
    let traineeProfileId: String
    let kind: String?
    let totalSessions: Int
    let usedSessions: Int
    let startDate: String?
    let endDate: String?
    let freezeDays: Int?
    let priceRub: Int?
    let status: String
    let displayCode: String?
    let createdAt: Date
}

private func mapDTOsToMemberships(_ dtos: [MembershipDTO]) -> [Membership] {
    dtos.map { dto in
        let status = MembershipStatus(rawValue: dto.status) ?? .active
        let kind: MembershipKind = (dto.kind == "unlimited") ? .unlimited : .byVisits
        let startDate = dto.startDate.flatMap { calendarDateFormatter.date(from: $0) }
        let endDate = dto.endDate.flatMap { calendarDateFormatter.date(from: $0) }
        let freezeDays = dto.freezeDays ?? 0
        return Membership(
            id: dto.id,
            coachProfileId: dto.coachProfileId,
            traineeProfileId: dto.traineeProfileId,
            createdAt: dto.createdAt,
            kind: kind,
            totalSessions: max(0, dto.totalSessions),
            usedSessions: max(0, dto.usedSessions),
            startDate: startDate,
            endDate: endDate,
            freezeDays: max(0, freezeDays),
            priceRub: dto.priceRub,
            status: status,
            displayCode: dto.displayCode,
            closedManually: false
        )
    }.sorted { $0.createdAt > $1.createdAt }
}

final class APICalendarSummaryService: CalendarSummaryServiceProtocol {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    convenience init(baseURL: URL, getIDToken: @escaping (_ forceRefresh: Bool) async -> String?) {
        self.init(client: APIClient(baseURL: baseURL, getIDToken: getIDToken))
    }

    func fetchCardSummary(
        coachProfileId: String,
        traineeProfileId: String,
        calendarFrom: Date?,
        calendarTo: Date?
    ) async throws -> CardSummaryResponse {
        var query: [String: String] = [:]
        if let from = calendarFrom {
            query["calendarFrom"] = calendarDateFormatter.string(from: from)
        }
        if let to = calendarTo {
            query["calendarTo"] = calendarDateFormatter.string(from: to)
        }
        struct RawResponse: Decodable {
            let profile: Profile
            let visits: [Visit]
            let events: [Event]
            let memberships: [MembershipDTO]
        }
        let path = "api/v1/coach-profiles/\(coachProfileId)/trainees/\(traineeProfileId)/card-summary"
        let res: RawResponse = try await client.request(
            path: path,
            query: query.isEmpty ? nil : query,
            useDateTimeDecoder: true
        )
        return CardSummaryResponse(
            profile: res.profile,
            visits: res.visits.sorted { $0.date > $1.date },
            events: res.events.sorted { $0.date > $1.date },
            memberships: mapDTOsToMemberships(res.memberships)
        )
    }

    func fetchCalendar(
        coachProfileId: String,
        traineeProfileId: String,
        from: Date,
        to: Date
    ) async throws -> CalendarFeedResponse {
        struct RawResponse: Decodable {
            let visits: [Visit]
            let events: [Event]
        }
        let res: RawResponse = try await client.request(
            path: "api/v1/calendar",
            query: [
                "coachProfileId": coachProfileId,
                "traineeProfileId": traineeProfileId,
                "from": calendarDateFormatter.string(from: from),
                "to": calendarDateFormatter.string(from: to)
            ],
            useDateTimeDecoder: true
        )
        return CalendarFeedResponse(
            visits: res.visits.sorted { $0.date > $1.date },
            events: res.events.sorted { $0.date > $1.date }
        )
    }
}
