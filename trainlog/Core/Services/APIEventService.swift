//
//  APIEventService.swift
//  TrainLog
//

import Foundation

final class APIEventService: EventServiceProtocol {
    private let client: APIClient
    private var eventsCache: [String: (events: [Event], expiresAt: Date)] = [:]
    private let cacheTTL: TimeInterval = 30

    init(client: APIClient) {
        self.client = client
    }

    convenience init(baseURL: URL, getIDToken: @escaping (_ forceRefresh: Bool) async -> String?) {
        self.init(client: APIClient(baseURL: baseURL, getIDToken: getIDToken))
    }

    private func cacheKey(coachProfileId: String, traineeProfileId: String) -> String {
        "events:\(coachProfileId):\(traineeProfileId)"
    }

    private func invalidateEvents(coachProfileId: String, traineeProfileId: String) {
        eventsCache.removeValue(forKey: cacheKey(coachProfileId: coachProfileId, traineeProfileId: traineeProfileId))
    }

    func fetchEvents(coachProfileId: String, traineeProfileId: String) async throws -> [Event] {
        let key = cacheKey(coachProfileId: coachProfileId, traineeProfileId: traineeProfileId)
        if let cached = eventsCache[key], cached.expiresAt > Date() {
            return cached.events
        }
        struct ListResponse: Decodable {
            let events: [Event]
        }
        let res: ListResponse = try await client.request(
            path: "api/v1/events",
            query: ["coachProfileId": coachProfileId, "traineeProfileId": traineeProfileId],
            useDateTimeDecoder: true
        )
        let events = res.events.sorted { $0.periodStart > $1.periodStart }
        eventsCache[key] = (events, Date().addingTimeInterval(cacheTTL))
        return events
    }

    func createEvent(
        coachProfileId: String,
        traineeProfileId: String,
        title: String,
        date: Date,
        mode: EventMode,
        periodStart: Date?,
        periodEnd: Date?,
        eventDescription: String?,
        remind: Bool,
        colorHex: String?,
        eventType: EventType,
        freezeMembership: Bool,
        idempotencyKey: String? = nil
    ) async throws -> Event {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        struct CreateBody: Encodable {
            let coachProfileId: String
            let traineeProfileId: String
            let title: String
            let mode: String
            let date: String
            let periodStart: String?
            let periodEnd: String?
            let description: String?
            let remind: Bool
            let colorHex: String?
            let eventType: String
            let freezeMembership: Bool
            let idempotencyKey: String?
        }
        let body = CreateBody(
            coachProfileId: coachProfileId,
            traineeProfileId: traineeProfileId,
            title: title,
            mode: mode.rawValue,
            date: fmt.string(from: date),
            periodStart: periodStart.map { fmt.string(from: $0) },
            periodEnd: periodEnd.map { fmt.string(from: $0) },
            description: eventDescription,
            remind: remind,
            colorHex: colorHex,
            eventType: eventType.rawValue,
            freezeMembership: freezeMembership,
            idempotencyKey: idempotencyKey
        )
        let event: Event = try await client.request(path: "api/v1/events", method: "POST", body: body, useDateTimeDecoder: true)
        invalidateEvents(coachProfileId: coachProfileId, traineeProfileId: traineeProfileId)
        return event
    }

    func updateEvent(_ event: Event) async throws {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        struct PatchBody: Encodable {
            let title: String?
            let mode: String?
            let date: String?
            let periodStart: String?
            let periodEnd: String?
            let description: String?
            let remind: Bool?
            let colorHex: String?
            let eventType: String?
            let freezeMembership: Bool?
            let isCancelled: Bool?
        }
        let body = PatchBody(
            title: event.title,
            mode: event.mode.rawValue,
            date: fmt.string(from: event.date),
            periodStart: fmt.string(from: event.periodStart),
            periodEnd: fmt.string(from: event.periodEnd),
            description: event.eventDescription,
            remind: event.remind,
            colorHex: event.colorHex,
            eventType: event.eventType.rawValue,
            freezeMembership: event.freezeMembership,
            isCancelled: event.isCancelled
        )
        _ = try await client.request(path: "api/v1/events/\(event.id)", method: "PATCH", body: body, useDateTimeDecoder: true) as Event
        invalidateEvents(coachProfileId: event.coachProfileId, traineeProfileId: event.traineeProfileId)
    }

    func deleteEvent(_ event: Event) async throws {
        try await client.requestNoContent(path: "api/v1/events/\(event.id)", method: "DELETE")
        invalidateEvents(coachProfileId: event.coachProfileId, traineeProfileId: event.traineeProfileId)
    }
}
