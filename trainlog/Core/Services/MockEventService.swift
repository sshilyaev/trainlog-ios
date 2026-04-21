//
//  MockEventService.swift
//  TrainLog
//

import Foundation

final class MockEventService: EventServiceProtocol {
    private var store: [Event] = []

    func fetchEvents(coachProfileId: String, traineeProfileId: String) async throws -> [Event] {
        store
            .filter { $0.coachProfileId == coachProfileId && $0.traineeProfileId == traineeProfileId }
            .sorted { $0.date > $1.date }
    }

    func createEvent(coachProfileId: String, traineeProfileId: String, title: String, date: Date, eventDescription: String?, remind: Bool, colorHex: String?, eventType: EventType, idempotencyKey: String? = nil) async throws -> Event {
        let e = Event(
            id: UUID().uuidString,
            coachProfileId: coachProfileId,
            traineeProfileId: traineeProfileId,
            title: title,
            date: date,
            eventDescription: eventDescription,
            remind: remind,
            colorHex: colorHex,
            eventType: eventType,
            isCancelled: false
        )
        store.append(e)
        return e
    }

    func updateEvent(_ event: Event) async throws {
        if let idx = store.firstIndex(where: { $0.id == event.id }) {
            store[idx] = event
        } else {
            store.append(event)
        }
    }

    func deleteEvent(_ event: Event) async throws {
        store.removeAll { $0.id == event.id }
    }
}
