//
//  MockMembershipService.swift
//  TrainLog
//

import Foundation

final class MockMembershipService: MembershipServiceProtocol {
    private var store: [Membership] = []

    func fetchActiveMembership(coachProfileId: String, traineeProfileId: String) async throws -> Membership? {
        store
            .filter { $0.coachProfileId == coachProfileId && $0.traineeProfileId == traineeProfileId }
            .sorted { $0.createdAt > $1.createdAt }
            .first(where: { $0.isActive })
    }

    func fetchMemberships(coachProfileId: String, traineeProfileId: String) async throws -> [Membership] {
        store
            .filter { $0.coachProfileId == coachProfileId && $0.traineeProfileId == traineeProfileId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func fetchMembershipsForTrainee(traineeProfileId: String) async throws -> [Membership] {
        store
            .filter { $0.traineeProfileId == traineeProfileId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func createMembership(coachProfileId: String, traineeProfileId: String, kind: MembershipKind, totalSessions: Int?, startDate: Date?, endDate: Date?, priceRub: Int?) async throws -> Membership {
        let existing = try await fetchMemberships(coachProfileId: coachProfileId, traineeProfileId: traineeProfileId)
        let existingOfKind = existing.filter { $0.kind == kind }
        let displayCode = Self.displayCode(kind: kind, number: existingOfKind.count + 1)
        let createdAt = Date()
        let m: Membership
        switch kind {
        case .byVisits:
            let total = max(1, totalSessions ?? 10)
            m = Membership(
                id: UUID().uuidString,
                coachProfileId: coachProfileId,
                traineeProfileId: traineeProfileId,
                createdAt: createdAt,
                kind: .byVisits,
                totalSessions: total,
                usedSessions: 0,
                priceRub: priceRub,
                status: .active,
                displayCode: displayCode,
                closedManually: false
            )
        case .unlimited:
            let start = startDate ?? createdAt
            let end = endDate ?? Calendar.current.date(byAdding: .day, value: 30, to: start)!
            m = Membership(
                id: UUID().uuidString,
                coachProfileId: coachProfileId,
                traineeProfileId: traineeProfileId,
                createdAt: createdAt,
                kind: .unlimited,
                totalSessions: 0,
                usedSessions: 0,
                startDate: start,
                endDate: end,
                freezeDays: 0,
                priceRub: priceRub,
                status: .active,
                displayCode: displayCode,
                closedManually: false
            )
        }
        store.append(m)
        return m
    }

    /// Безлимитный: Б1, Б2… По посещениям: А1, А2…
    private static func displayCode(kind: MembershipKind, number: Int) -> String {
        let n = max(1, number)
        return kind == .unlimited ? "Б\(n)" : "А\(n)"
    }

    func updateMembership(_ membership: Membership) async throws {
        if let idx = store.firstIndex(where: { $0.id == membership.id }) {
            store[idx] = membership
        } else {
            store.append(membership)
        }
    }

    func invalidateMembershipsCache(coachProfileId: String, traineeProfileId: String) {
        _ = coachProfileId
        _ = traineeProfileId
    }
}

