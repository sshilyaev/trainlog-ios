//
//  APIManagedTraineeMergeService.swift
//  TrainLog
//

import Foundation

final class APIManagedTraineeMergeService: ManagedTraineeMergeServiceProtocol {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    convenience init(baseURL: URL, getIDToken: @escaping (_ forceRefresh: Bool) async -> String?) {
        self.init(client: APIClient(baseURL: baseURL, getIDToken: getIDToken))
    }

    func mergeManagedTrainee(coachProfileId: String, managedTraineeProfileId: String, realTraineeProfileId: String) async throws {
        guard !coachProfileId.isEmpty, !managedTraineeProfileId.isEmpty, !realTraineeProfileId.isEmpty else { return }
        if managedTraineeProfileId == realTraineeProfileId { return }

        struct MergeBody: Encodable {
            let coachProfileId: String
            let managedTraineeProfileId: String
            let realTraineeProfileId: String
        }
        let body = MergeBody(
            coachProfileId: coachProfileId,
            managedTraineeProfileId: managedTraineeProfileId,
            realTraineeProfileId: realTraineeProfileId
        )
        try await client.requestNoContent(path: "api/v1/profiles/merge", method: "POST", body: body)
    }
}
