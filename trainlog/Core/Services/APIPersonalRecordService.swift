import Foundation

final class APIPersonalRecordService: PersonalRecordServiceProtocol {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func fetchRecords(profileId: String) async throws -> [PersonalRecord] {
        struct ListResponse: Decodable {
            let records: [PersonalRecord]
        }
        let response: ListResponse = try await client.request(
            path: "api/v1/profiles/\(profileId)/records",
            useDateTimeDecoder: true
        )
        return response.records.sorted { $0.recordDate > $1.recordDate }
    }

    func fetchActivities() async throws -> [RecordActivity] {
        struct ActivitiesResponse: Decodable {
            let activities: [RecordActivity]
        }
        let response: ActivitiesResponse = try await client.request(
            path: "api/v1/records/activities",
            useDateTimeDecoder: true
        )
        return response.activities.sorted { $0.displayOrder < $1.displayOrder }
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
        struct MetricBody: Encodable {
            let metricType: String
            let value: Double
            let unit: String
        }
        struct Body: Encodable {
            let recordDate: String
            let sourceType: String
            let activitySlug: String?
            let activityName: String?
            let activityType: String?
            let notes: String?
            let metrics: [MetricBody]
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let body = Body(
            recordDate: formatter.string(from: recordDate),
            sourceType: sourceType.rawValue,
            activitySlug: activitySlug,
            activityName: activityName,
            activityType: activityType,
            notes: notes,
            metrics: metrics.map {
                MetricBody(
                    metricType: $0.metricType.rawValue,
                    value: $0.value,
                    unit: $0.unit
                )
            }
        )

        if let id, !id.isEmpty {
            return try await client.request(
                path: "api/v1/profiles/\(profileId)/records/\(id)",
                method: "PATCH",
                body: body,
                useDateTimeDecoder: true
            )
        }

        return try await client.request(
            path: "api/v1/profiles/\(profileId)/records",
            method: "POST",
            body: body,
            useDateTimeDecoder: true
        )
    }

    func deleteRecord(profileId: String, recordId: String) async throws {
        try await client.requestNoContent(path: "api/v1/profiles/\(profileId)/records/\(recordId)", method: "DELETE")
    }
}
