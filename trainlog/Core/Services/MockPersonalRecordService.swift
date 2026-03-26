import Foundation

final class MockPersonalRecordService: PersonalRecordServiceProtocol {
    private var recordsByProfile: [String: [PersonalRecord]] = [:]

    func fetchRecords(profileId: String) async throws -> [PersonalRecord] {
        recordsByProfile[profileId, default: []]
    }

    func saveRecord(
        profileId: String,
        id: String?,
        recordDate: Date,
        sourceType: PersonalRecordSourceType,
        activitySlug: String?,
        activityName: String?,
        activityType: String?,
        notes: String?,
        metrics: [PersonalRecordMetric]
    ) async throws -> PersonalRecord {
        let newRecord = PersonalRecord(
            id: id ?? UUID().uuidString,
            profileId: profileId,
            createdByProfileId: profileId,
            recordDate: recordDate,
            sourceType: sourceType,
            activityName: activityName ?? activitySlug ?? "Рекорд",
            activityType: activityType,
            notes: notes,
            metrics: metrics,
            createdAt: Date(),
            updatedAt: Date()
        )
        var current = recordsByProfile[profileId, default: []]
        current.removeAll { $0.id == newRecord.id }
        current.append(newRecord)
        recordsByProfile[profileId] = current
        return newRecord
    }

    func deleteRecord(profileId: String, recordId: String) async throws {
        recordsByProfile[profileId, default: []].removeAll { $0.id == recordId }
    }

    func fetchActivities() async throws -> [RecordActivity] {
        [
            RecordActivity(slug: "bench-press", name: "Жим лежа", activityType: "strength", defaultMetrics: [.weight, .reps], displayOrder: 10),
            RecordActivity(slug: "run", name: "Бег", activityType: "cardio", defaultMetrics: [.distance, .duration], displayOrder: 20),
        ]
    }
}
