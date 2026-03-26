//
//  EventService.swift
//  TrainLog
//

import Foundation

protocol EventServiceProtocol {
    func fetchEvents(coachProfileId: String, traineeProfileId: String) async throws -> [Event]
    func createEvent(coachProfileId: String, traineeProfileId: String, title: String, date: Date, eventDescription: String?, remind: Bool, colorHex: String?, idempotencyKey: String?) async throws -> Event
    func updateEvent(_ event: Event) async throws
    func deleteEvent(_ event: Event) async throws
}
