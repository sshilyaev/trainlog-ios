import Foundation

protocol PersonalRecordServiceProtocol {
    func fetchRecords(profileId: String) async throws -> [PersonalRecord]
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
    ) async throws -> PersonalRecord
    func deleteRecord(profileId: String, recordId: String) async throws
    func fetchActivities() async throws -> [RecordActivity]
}
