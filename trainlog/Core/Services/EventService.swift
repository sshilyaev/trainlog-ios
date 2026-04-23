//
//  EventService.swift
//  TrainLog
//

import Foundation

protocol EventServiceProtocol {
    func fetchEvents(coachProfileId: String, traineeProfileId: String) async throws -> [Event]
    func createEvent(
        coachProfileId: String,
        traineeProfileId: String,
        title: String,
        date: Date,
        mode: EventMode,
        periodStart: Date?,
        periodEnd: Date?,
        periodType: EventPeriodType?,
        eventDescription: String?,
        remind: Bool,
        colorHex: String?,
        eventType: EventType,
        freezeMembership: Bool,
        idempotencyKey: String?
    ) async throws -> Event
    func updateEvent(_ event: Event) async throws
    func deleteEvent(_ event: Event) async throws
}
