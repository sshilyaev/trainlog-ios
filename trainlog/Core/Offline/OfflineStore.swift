import Foundation

enum OfflineOperationType: String, Codable {
    case createVisit
    // В будущем: createEvent, createTraineeProfile, createMeasurement
}

struct OfflineOperation: Codable, Identifiable {
    let id: UUID
    let type: OfflineOperationType
    let payload: Data
    let createdAt: Date
    var retryCount: Int

    init(type: OfflineOperationType, payload: Data) {
        self.id = UUID()
        self.type = type
        self.payload = payload
        self.createdAt = Date()
        self.retryCount = 0
    }
}

/// Снимок данных для офлайн-чтения (MVP).
struct OfflineCoachSnapshot: Codable {
    var trainees: [Profile]
    /// Связи тренер–подопечный для отображения списка офлайн.
    var links: [CoachTraineeLink]?
    var visitsByTrainee: [String: [Visit]]

    init(trainees: [Profile], links: [CoachTraineeLink]? = nil, visitsByTrainee: [String: [Visit]]) {
        self.trainees = trainees
        self.links = links
        self.visitsByTrainee = visitsByTrainee
    }
}

final class OfflineStore {
    static let shared = OfflineStore()

    private let operationsURL: URL
    private let snapshotURL: URL
    private let queue = DispatchQueue(label: "offline.store.queue", qos: .utility)

    private init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        operationsURL = dir.appendingPathComponent("offline_operations.json")
        snapshotURL = dir.appendingPathComponent("offline_snapshot.json")
    }

    // MARK: - Operations

    func loadOperations() -> [OfflineOperation] {
        queue.sync {
            guard let data = try? Data(contentsOf: operationsURL) else { return [] }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return (try? decoder.decode([OfflineOperation].self, from: data)) ?? []
        }
    }

    func saveOperations(_ ops: [OfflineOperation]) {
        queue.async {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(ops) {
                try? data.write(to: self.operationsURL, options: .atomic)
            }
        }
    }

    func enqueue(_ op: OfflineOperation) {
        var all = loadOperations()
        all.append(op)
        saveOperations(all)
    }

    func removeOperation(id: UUID) {
        var all = loadOperations()
        all.removeAll { $0.id == id }
        saveOperations(all)
    }

    // MARK: - Snapshot

    func loadSnapshot() -> OfflineCoachSnapshot? {
        queue.sync {
            guard let data = try? Data(contentsOf: snapshotURL) else { return nil }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try? decoder.decode(OfflineCoachSnapshot.self, from: data)
        }
    }

    func saveSnapshot(_ snapshot: OfflineCoachSnapshot) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        Task { @MainActor in
            let data = try? encoder.encode(snapshot)
            guard let data else { return }
            queue.async {
                try? data.write(to: self.snapshotURL, options: .atomic)
            }
        }
    }

    /// Обновляет список подопечных и связей в снимке (вызывать после успешной загрузки списка тренером).
    func updateSnapshotTraineesAndLinks(trainees: [Profile], links: [CoachTraineeLink]) {
        var snapshot = loadSnapshot() ?? OfflineCoachSnapshot(trainees: [], links: nil, visitsByTrainee: [:])
        snapshot.trainees = trainees
        snapshot.links = links
        saveSnapshot(snapshot)
    }

    /// Обновляет визиты одного подопечного в снимке (вызывать после успешной загрузки визитов).
    func mergeVisitsForTrainee(_ traineeProfileId: String, visits: [Visit]) {
        var snapshot = loadSnapshot() ?? OfflineCoachSnapshot(trainees: [], links: nil, visitsByTrainee: [:])
        snapshot.visitsByTrainee[traineeProfileId] = visits
        saveSnapshot(snapshot)
    }

    /// Полная очистка офлайн-данных (при выходе из аккаунта).
    func clearAll() {
        queue.async {
            try? FileManager.default.removeItem(at: self.operationsURL)
            try? FileManager.default.removeItem(at: self.snapshotURL)
        }
    }
}

