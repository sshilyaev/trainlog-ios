//
//  APIVisitService.swift
//  TrainLog
//

import Foundation

final class APIVisitService: VisitServiceProtocol {
    private let client: APIClient
    private var visitsCache: [String: (visits: [Visit], expiresAt: Date)] = [:]
    private let cacheTTL: TimeInterval = 30

    init(client: APIClient) {
        self.client = client
    }

    convenience init(baseURL: URL, getIDToken: @escaping (_ forceRefresh: Bool) async -> String?) {
        self.init(client: APIClient(baseURL: baseURL, getIDToken: getIDToken))
    }

    private func cacheKey(coachProfileId: String, traineeProfileId: String) -> String {
        "visits:\(coachProfileId):\(traineeProfileId)"
    }

    private func invalidateVisits(coachProfileId: String, traineeProfileId: String) {
        visitsCache.removeValue(forKey: cacheKey(coachProfileId: coachProfileId, traineeProfileId: traineeProfileId))
    }

    func fetchVisits(coachProfileId: String, traineeProfileId: String) async throws -> [Visit] {
        let key = cacheKey(coachProfileId: coachProfileId, traineeProfileId: traineeProfileId)
        if let cached = visitsCache[key], cached.expiresAt > Date() {
            return cached.visits
        }
        struct ListResponse: Decodable {
            let visits: [Visit]
        }
        let res: ListResponse = try await client.request(
            path: "api/v1/visits",
            query: ["coachProfileId": coachProfileId, "traineeProfileId": traineeProfileId],
            useDateTimeDecoder: true
        )
        let visits = res.visits.sorted { $0.date > $1.date }
        visitsCache[key] = (visits, Date().addingTimeInterval(cacheTTL))
        return visits
    }

    func createVisit(coachProfileId: String, traineeProfileId: String, date: Date, paymentStatus: String? = nil, membershipId: String? = nil, idempotencyKey: String? = nil) async throws -> Visit {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        struct CreateBody: Encodable {
            let coachProfileId: String
            let traineeProfileId: String
            let date: String
            let paymentStatus: String?
            let membershipId: String?
            let idempotencyKey: String?
        }
        let body = CreateBody(
            coachProfileId: coachProfileId,
            traineeProfileId: traineeProfileId,
            date: fmt.string(from: date),
            paymentStatus: paymentStatus,
            membershipId: membershipId,
            idempotencyKey: idempotencyKey
        )
        let visit: Visit = try await client.request(
            path: "api/v1/visits",
            method: "POST",
            body: body,
            useDateTimeDecoder: true
        )
        invalidateVisits(coachProfileId: coachProfileId, traineeProfileId: traineeProfileId)
        return visit
    }

    func updateVisit(_ visit: Visit) async throws {
        if visit.status == .cancelled {
            try await cancelVisit(visit)
            return
        }
        if visit.paymentStatus == .debt, let mId = visit.membershipId, !mId.isEmpty {
            try await markVisitPaidWithMembership(visit, membershipId: mId)
        }
    }

    /// На API создание визита уже «приход»; отдельного mark done нет.
    func markVisitDone(_ visit: Visit) async throws {
        if visit.status == .done { return }
        throw APIResponseError(
            statusCode: 400,
            errorMessage: "Отметить приход нужно при создании визита",
            backendMessage: nil,
            validationMessages: [],
            backendCode: nil
        )
    }

    /// Если визит уже создан как долг — погашаем через PATCH с membershipId.
    func markVisitDoneWithMembership(_ visit: Visit, membershipId: String) async throws {
        if visit.status == .done { return }
        if visit.paymentStatus == .debt {
            try await markVisitPaidWithMembership(visit, membershipId: membershipId)
            return
        }
        throw APIResponseError(
            statusCode: 400,
            errorMessage: "Используйте создание визита для отметки прихода",
            backendMessage: nil,
            validationMessages: [],
            backendCode: nil
        )
    }

    func markVisitPaid(_ visit: Visit) async throws {
        guard visit.paymentStatus == .debt else { return }
        struct PatchBody: Encodable {
            let paymentStatus: String
        }
        try await client.requestNoContent(
            path: "api/v1/visits/\(visit.id)",
            method: "PATCH",
            body: PatchBody(paymentStatus: "paid")
        )
        invalidateVisits(coachProfileId: visit.coachProfileId, traineeProfileId: visit.traineeProfileId)
    }

    func markVisitPaidWithMembership(_ visit: Visit, membershipId: String) async throws {
        guard visit.paymentStatus == .debt else { return }
        struct PatchBody: Encodable {
            let membershipId: String
        }
        try await client.requestNoContent(
            path: "api/v1/visits/\(visit.id)",
            method: "PATCH",
            body: PatchBody(membershipId: membershipId)
        )
        invalidateVisits(coachProfileId: visit.coachProfileId, traineeProfileId: visit.traineeProfileId)
    }

    func cancelVisit(_ visit: Visit) async throws {
        struct PatchBody: Encodable {
            let status: String
        }
        try await client.requestNoContent(
            path: "api/v1/visits/\(visit.id)",
            method: "PATCH",
            body: PatchBody(status: "cancelled")
        )
        invalidateVisits(coachProfileId: visit.coachProfileId, traineeProfileId: visit.traineeProfileId)
    }
}
