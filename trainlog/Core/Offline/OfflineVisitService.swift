import Foundation

/// Обёртка над VisitServiceProtocol с поддержкой офлайн-создания визитов.
final class OfflineVisitService: VisitServiceProtocol {
    let wrapped: VisitServiceProtocol
    private let offlineEnabled: Bool

    init(wrapped: VisitServiceProtocol, offlineEnabled: Bool = AppConfig.enableOfflineMode) {
        self.wrapped = wrapped
        self.offlineEnabled = offlineEnabled
    }

    func fetchVisits(coachProfileId: String, traineeProfileId: String) async throws -> [Visit] {
        guard offlineEnabled else {
            return try await wrapped.fetchVisits(coachProfileId: coachProfileId, traineeProfileId: traineeProfileId)
        }

        // Если система уже знает, что сети нет — не ждём таймаутов, сразу читаем из кэша.
        if OfflineMode.shared.isOffline {
            if let snapshot = OfflineStore.shared.loadSnapshot() {
                let cached = snapshot.visitsByTrainee[traineeProfileId] ?? []
                let pending = pendingVisitsFromQueue(coachProfileId: coachProfileId, traineeProfileId: traineeProfileId)
                return mergeAndSortVisits(cached: cached, pending: pending)
            }
        }

        do {
            let visits = try await wrapped.fetchVisits(coachProfileId: coachProfileId, traineeProfileId: traineeProfileId)
            OfflineStore.shared.mergeVisitsForTrainee(traineeProfileId, visits: visits)
            return visits
        } catch {
            if let snapshot = OfflineStore.shared.loadSnapshot() {
                let cached = snapshot.visitsByTrainee[traineeProfileId] ?? []
                let pending = pendingVisitsFromQueue(coachProfileId: coachProfileId, traineeProfileId: traineeProfileId)
                return mergeAndSortVisits(cached: cached, pending: pending)
            }
            throw error
        }
    }

    /// Визиты из очереди операций createVisit для данного подопечного.
    private func pendingVisitsFromQueue(coachProfileId: String, traineeProfileId: String) -> [Visit] {
        struct Payload: Decodable {
            let coachProfileId: String
            let traineeProfileId: String
            let date: Date
            let paymentStatus: String?
            let membershipId: String?
            let idempotencyKey: String
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let operations = OfflineStore.shared.loadOperations()
        var result: [Visit] = []
        for op in operations where op.type == .createVisit {
            guard let payload = try? decoder.decode(Payload.self, from: op.payload),
                  payload.traineeProfileId == traineeProfileId else { continue }
            let v = Visit(
                id: payload.idempotencyKey,
                coachProfileId: payload.coachProfileId,
                traineeProfileId: payload.traineeProfileId,
                createdAt: Date(),
                date: payload.date,
                status: .planned,
                paymentStatus: .unpaid,
                membershipId: nil,
                membershipDisplayCode: nil
            )
            result.append(v)
        }
        return result
    }

    private func mergeAndSortVisits(cached: [Visit], pending: [Visit]) -> [Visit] {
        let cachedIds = Set(cached.map(\.id))
        let pendingOnly = pending.filter { !cachedIds.contains($0.id) }
        return (cached + pendingOnly).sorted { $0.date > $1.date }
    }

    func createVisit(coachProfileId: String, traineeProfileId: String, date: Date, paymentStatus: String?, membershipId: String?, idempotencyKey: String? = nil) async throws -> Visit {
        guard offlineEnabled else {
            return try await wrapped.createVisit(coachProfileId: coachProfileId, traineeProfileId: traineeProfileId, date: date, paymentStatus: paymentStatus, membershipId: membershipId, idempotencyKey: idempotencyKey)
        }

        // В офлайне не ждём таймаутов API — сразу создаём локально и кладём операцию в очередь.
        if OfflineMode.shared.isOffline {
            return createLocalVisitAndEnqueue(
                coachProfileId: coachProfileId,
                traineeProfileId: traineeProfileId,
                date: date,
                paymentStatus: paymentStatus,
                membershipId: membershipId
            )
        }

        do {
            let v = try await wrapped.createVisit(coachProfileId: coachProfileId, traineeProfileId: traineeProfileId, date: date, paymentStatus: paymentStatus, membershipId: membershipId, idempotencyKey: idempotencyKey)
            return v
        } catch {
            return createLocalVisitAndEnqueue(
                coachProfileId: coachProfileId,
                traineeProfileId: traineeProfileId,
                date: date,
                paymentStatus: paymentStatus,
                membershipId: membershipId
            )
        }
    }

    private func createLocalVisitAndEnqueue(
        coachProfileId: String,
        traineeProfileId: String,
        date: Date,
        paymentStatus: String?,
        membershipId: String?
    ) -> Visit {
        let localId = UUID().uuidString
        let localVisit = Visit(
            id: localId,
            coachProfileId: coachProfileId,
            traineeProfileId: traineeProfileId,
            createdAt: Date(),
            date: date,
            status: .planned,
            paymentStatus: .unpaid,
            membershipId: nil,
            membershipDisplayCode: nil
        )

        struct Payload: Codable {
            let coachProfileId: String
            let traineeProfileId: String
            let date: Date
            let paymentStatus: String?
            let membershipId: String?
            let idempotencyKey: String
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payload = Payload(
            coachProfileId: coachProfileId,
            traineeProfileId: traineeProfileId,
            date: date,
            paymentStatus: paymentStatus,
            membershipId: membershipId,
            idempotencyKey: localId
        )
        if let data = try? encoder.encode(payload) {
            let op = OfflineOperation(type: .createVisit, payload: data)
            OfflineStore.shared.enqueue(op)
        }
        return localVisit
    }

    // Пробрасываем остальные методы.
    func updateVisit(_ visit: Visit) async throws {
        try await wrapped.updateVisit(visit)
    }

    func markVisitDone(_ visit: Visit) async throws {
        try await wrapped.markVisitDone(visit)
    }

    func markVisitDoneWithMembership(_ visit: Visit, membershipId: String) async throws {
        try await wrapped.markVisitDoneWithMembership(visit, membershipId: membershipId)
    }

    func markVisitPaid(_ visit: Visit) async throws {
        try await wrapped.markVisitPaid(visit)
    }

    func markVisitPaidWithMembership(_ visit: Visit, membershipId: String) async throws {
        try await wrapped.markVisitPaidWithMembership(visit, membershipId: membershipId)
    }

    func cancelVisit(_ visit: Visit) async throws {
        try await wrapped.cancelVisit(visit)
    }
}

