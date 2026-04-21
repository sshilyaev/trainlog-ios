//
//  APIMembershipService.swift
//  TrainLog
//

import Foundation

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

private let apiDateOnlyFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "UTC")
    return f
}()

final class APIMembershipService: MembershipServiceProtocol {
    private let client: APIClient
    private var membershipsCache: [String: (memberships: [Membership], expiresAt: Date)] = [:]
    private let cacheTTL: TimeInterval = 30

    init(client: APIClient) {
        self.client = client
    }

    convenience init(baseURL: URL, getIDToken: @escaping (_ forceRefresh: Bool) async -> String?) {
        self.init(client: APIClient(baseURL: baseURL, getIDToken: getIDToken))
    }

    private func cacheKeyCoachTrainee(coachProfileId: String, traineeProfileId: String) -> String {
        "memberships:coach:\(coachProfileId):\(traineeProfileId)"
    }

    private func cacheKeyTrainee(traineeProfileId: String) -> String {
        "memberships:trainee:\(traineeProfileId)"
    }

    private func invalidateMemberships(coachProfileId: String, traineeProfileId: String) {
        membershipsCache.removeValue(forKey: cacheKeyCoachTrainee(coachProfileId: coachProfileId, traineeProfileId: traineeProfileId))
        membershipsCache.removeValue(forKey: cacheKeyTrainee(traineeProfileId: traineeProfileId))
    }

    func invalidateMembershipsCache(coachProfileId: String, traineeProfileId: String) {
        invalidateMemberships(coachProfileId: coachProfileId, traineeProfileId: traineeProfileId)
    }

    func fetchActiveMembership(coachProfileId: String, traineeProfileId: String) async throws -> Membership? {
        let list = try await fetchMemberships(coachProfileId: coachProfileId, traineeProfileId: traineeProfileId)
        return list.first(where: { $0.isActive })
    }

    func fetchMemberships(coachProfileId: String, traineeProfileId: String) async throws -> [Membership] {
        let key = cacheKeyCoachTrainee(coachProfileId: coachProfileId, traineeProfileId: traineeProfileId)
        if let cached = membershipsCache[key], cached.expiresAt > Date() {
            return cached.memberships
        }
        let res: ListResponse = try await client.request(
            path: "api/v1/memberships",
            query: ["coachProfileId": coachProfileId, "traineeProfileId": traineeProfileId],
            useDateTimeDecoder: true
        )
        let list = mapDTOsToMemberships(res.memberships)
        membershipsCache[key] = (list, Date().addingTimeInterval(cacheTTL))
        return list
    }

    func fetchMembershipsForTrainee(traineeProfileId: String) async throws -> [Membership] {
        let key = cacheKeyTrainee(traineeProfileId: traineeProfileId)
        if let cached = membershipsCache[key], cached.expiresAt > Date() {
            return cached.memberships
        }
        let res: ListResponse = try await client.request(
            path: "api/v1/memberships",
            query: ["traineeProfileId": traineeProfileId],
            useDateTimeDecoder: true
        )
        let list = mapDTOsToMemberships(res.memberships)
        membershipsCache[key] = (list, Date().addingTimeInterval(cacheTTL))
        return list
    }

    private struct ListResponse: Decodable {
        let memberships: [MembershipDTO]
    }

    private func mapDTOsToMemberships(_ dtos: [MembershipDTO]) -> [Membership] {
        dtos.map { dto in
            let status = MembershipStatus(rawValue: dto.status) ?? .active
            let kind: MembershipKind = (dto.kind == "unlimited") ? .unlimited : .byVisits
            let startDate = dto.startDate.flatMap { apiDateOnlyFormatter.date(from: $0) }
            let endDate = dto.endDate.flatMap { apiDateOnlyFormatter.date(from: $0) }
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

    func createMembership(coachProfileId: String, traineeProfileId: String, kind: MembershipKind, totalSessions: Int?, startDate: Date?, endDate: Date?, priceRub: Int?) async throws -> Membership {
        struct CreateBody: Encodable {
            let coachProfileId: String
            let traineeProfileId: String
            let kind: String
            let totalSessions: Int?
            let startDate: String?
            let endDate: String?
            let freezeDays: Int?
            let priceRub: Int?
        }
        let body: CreateBody
        if kind == .unlimited, let start = startDate, let end = endDate {
            body = CreateBody(
                coachProfileId: coachProfileId,
                traineeProfileId: traineeProfileId,
                kind: "unlimited",
                totalSessions: nil,
                startDate: apiDateOnlyFormatter.string(from: start),
                endDate: apiDateOnlyFormatter.string(from: end),
                freezeDays: 0,
                priceRub: priceRub
            )
        } else {
            let total = max(1, totalSessions ?? 10)
            body = CreateBody(
                coachProfileId: coachProfileId,
                traineeProfileId: traineeProfileId,
                kind: "by_visits",
                totalSessions: total,
                startDate: nil,
                endDate: nil,
                freezeDays: nil,
                priceRub: priceRub
            )
        }
        let dto: MembershipDTO = try await client.request(
            path: "api/v1/memberships",
            method: "POST",
            body: body,
            useDateTimeDecoder: true
        )
        let status = MembershipStatus(rawValue: dto.status) ?? .active
        let dtoKind: MembershipKind = (dto.kind == "unlimited") ? .unlimited : .byVisits
        let dtoStart = dto.startDate.flatMap { apiDateOnlyFormatter.date(from: $0) }
        let dtoEnd = dto.endDate.flatMap { apiDateOnlyFormatter.date(from: $0) }
        let membership = Membership(
            id: dto.id,
            coachProfileId: dto.coachProfileId,
            traineeProfileId: dto.traineeProfileId,
            createdAt: dto.createdAt,
            kind: dtoKind,
            totalSessions: max(0, dto.totalSessions),
            usedSessions: max(0, dto.usedSessions),
            startDate: dtoStart,
            endDate: dtoEnd,
            freezeDays: max(0, dto.freezeDays ?? 0),
            priceRub: dto.priceRub,
            status: status,
            displayCode: dto.displayCode,
            closedManually: false
        )
        invalidateMemberships(coachProfileId: dto.coachProfileId, traineeProfileId: dto.traineeProfileId)
        return membership
    }

    func updateMembership(_ membership: Membership) async throws {
        struct PatchBody: Encodable {
            let status: String
            let freezeDays: Int
        }
        try await client.requestNoContent(
            path: "api/v1/memberships/\(membership.id)",
            method: "PATCH",
            body: PatchBody(
                status: membership.status.rawValue,
                freezeDays: max(0, membership.freezeDays)
            )
        )
        invalidateMemberships(coachProfileId: membership.coachProfileId, traineeProfileId: membership.traineeProfileId)
    }
}
