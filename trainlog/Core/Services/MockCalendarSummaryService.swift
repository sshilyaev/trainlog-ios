//
//  MockCalendarSummaryService.swift
//  TrainLog
//

import Foundation

final class MockCalendarSummaryService: CalendarSummaryServiceProtocol {
    func fetchCardSummary(
        coachProfileId: String,
        traineeProfileId: String,
        calendarFrom: Date?,
        calendarTo: Date?
    ) async throws -> CardSummaryResponse {
        let profile = Profile(id: traineeProfileId, userId: "", type: .trainee, name: "Mock")
        return CardSummaryResponse(profile: profile, visits: [], events: [], memberships: [])
    }

    func fetchCalendar(
        coachProfileId: String,
        traineeProfileId: String,
        from: Date,
        to: Date
    ) async throws -> CalendarFeedResponse {
        CalendarFeedResponse(visits: [], events: [])
    }
}
