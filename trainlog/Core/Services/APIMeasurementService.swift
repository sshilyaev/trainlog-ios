//
//  APIMeasurementService.swift
//  TrainLog
//

import Foundation

final class APIMeasurementService: MeasurementServiceProtocol {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    convenience init(baseURL: URL, getIDToken: @escaping (_ forceRefresh: Bool) async -> String?) {
        self.init(client: APIClient(baseURL: baseURL, getIDToken: getIDToken))
    }

    func fetchMeasurements(profileId: String) async throws -> [Measurement] {
        struct ListResponse: Decodable {
            let measurements: [Measurement]
        }
        let res: ListResponse = try await client.request(
            path: "api/v1/profiles/\(profileId)/measurements",
            useDateTimeDecoder: true
        )
        return res.measurements.sorted { $0.date > $1.date }
    }

    func saveMeasurement(_ measurement: Measurement) async throws {
        struct CreateBody: Encodable {
            let date: String
            let weight: Double?
            let height: Double?
            let neck: Double?
            let shoulders: Double?
            let leftBiceps: Double?
            let rightBiceps: Double?
            let waist: Double?
            let belly: Double?
            let chest: Double?
            let leftThigh: Double?
            let rightThigh: Double?
            let hips: Double?
            let buttocks: Double?
            let leftCalf: Double?
            let rightCalf: Double?
            let note: String?
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        let dateStr = fmt.string(from: measurement.date)
        if measurement.id.isEmpty {
            let body = CreateBody(
                date: dateStr,
                weight: measurement.weight,
                height: measurement.height,
                neck: measurement.neck,
                shoulders: measurement.shoulders,
                leftBiceps: measurement.leftBiceps,
                rightBiceps: measurement.rightBiceps,
                waist: measurement.waist,
                belly: measurement.belly,
                chest: measurement.chest,
                leftThigh: measurement.leftThigh,
                rightThigh: measurement.rightThigh,
                hips: measurement.hips,
                buttocks: measurement.buttocks,
                leftCalf: measurement.leftCalf,
                rightCalf: measurement.rightCalf,
                note: measurement.note
            )
            _ = try await client.request(path: "api/v1/profiles/\(measurement.profileId)/measurements", method: "POST", body: body, useDateTimeDecoder: true) as Measurement
        } else {
            struct PatchBody: Encodable {
                let date: String?
                let weight: Double?
                let height: Double?
                let neck: Double?
                let shoulders: Double?
                let leftBiceps: Double?
                let rightBiceps: Double?
                let waist: Double?
                let belly: Double?
                let chest: Double?
                let leftThigh: Double?
                let rightThigh: Double?
                let hips: Double?
                let buttocks: Double?
                let leftCalf: Double?
                let rightCalf: Double?
                let note: String?
            }
            let body = PatchBody(
                date: dateStr,
                weight: measurement.weight,
                height: measurement.height,
                neck: measurement.neck,
                shoulders: measurement.shoulders,
                leftBiceps: measurement.leftBiceps,
                rightBiceps: measurement.rightBiceps,
                waist: measurement.waist,
                belly: measurement.belly,
                chest: measurement.chest,
                leftThigh: measurement.leftThigh,
                rightThigh: measurement.rightThigh,
                hips: measurement.hips,
                buttocks: measurement.buttocks,
                leftCalf: measurement.leftCalf,
                rightCalf: measurement.rightCalf,
                note: measurement.note
            )
            _ = try await client.request(path: "api/v1/profiles/\(measurement.profileId)/measurements/\(measurement.id)", method: "PATCH", body: body, useDateTimeDecoder: true) as Measurement
        }
    }

    func deleteMeasurement(_ measurement: Measurement) async throws {
        try await client.requestNoContent(path: "api/v1/profiles/\(measurement.profileId)/measurements/\(measurement.id)", method: "DELETE")
    }

    func deleteAllMeasurements(profileId: String) async throws {
        let list = try await fetchMeasurements(profileId: profileId)
        for m in list {
            try await client.requestNoContent(path: "api/v1/profiles/\(profileId)/measurements/\(m.id)", method: "DELETE")
        }
    }
}
