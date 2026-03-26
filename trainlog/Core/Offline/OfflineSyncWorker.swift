import Foundation

/// Простейший воркер синхронизации очереди офлайн-операций.
final class OfflineSyncWorker {
    static let shared = OfflineSyncWorker()

    private init() {}

    func syncAllIfNeeded(visitService: VisitServiceProtocol) async {
        guard AppConfig.enableOfflineMode else { return }

        let operations = OfflineStore.shared.loadOperations()
        guard !operations.isEmpty else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for op in operations {
            do {
                switch op.type {
                case .createVisit:
                    struct Payload: Codable {
                        let coachProfileId: String
                        let traineeProfileId: String
                        let date: Date
                        let paymentStatus: String?
                        let membershipId: String?
                        let idempotencyKey: String
                    }
                    guard let payload = try? decoder.decode(Payload.self, from: op.payload) else {
                        OfflineStore.shared.removeOperation(id: op.id)
                        continue
                    }

                    // Здесь важно: используем API-сервис и передаём idempotencyKey для идемпотентности.
                    _ = try await visitService.createVisit(
                        coachProfileId: payload.coachProfileId,
                        traineeProfileId: payload.traineeProfileId,
                        date: payload.date,
                        paymentStatus: payload.paymentStatus,
                        membershipId: payload.membershipId,
                        idempotencyKey: payload.idempotencyKey
                    )

                    OfflineStore.shared.removeOperation(id: op.id)
                }
            } catch {
                // Оставляем операцию в очереди, можно инкрементировать retryCount при надобности.
                continue
            }
        }
    }
}

