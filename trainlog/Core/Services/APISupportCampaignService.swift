import Foundation

final class APISupportCampaignService: SupportCampaignServiceProtocol {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func fetchCampaign() async throws -> SupportCampaignResponse {
        let dto: SupportCampaignResponseDTO = try await client.request(
            path: "api/v1/support/campaign",
            useDateTimeDecoder: true
        )
        return SupportCampaignResponse(dto: dto)
    }

    func createNewCampaign(goalType: SupportCampaignGoalType?) async throws -> SupportCampaignResponse {
        let body: [String: Any]
        if let goalType {
            body = ["goalType": goalType.rawValue]
        } else {
            body = [:]
        }
        let dto: SupportCampaignResponseDTO = try await client.request(
            path: "api/v1/support/campaign/new",
            method: "POST",
            jsonBody: body,
            useDateTimeDecoder: true
        )
        return SupportCampaignResponse(dto: dto)
    }

    func claimReward(adProvider: String, externalEventId: String, rewardValueKg: Double) async throws -> SupportCampaignResponse {
        let body: [String: Any] = [
            "adProvider": adProvider,
            "externalEventId": externalEventId,
            "rewardValueKg": rewardValueKg,
        ]
        let dto: SupportCampaignResponseDTO = try await client.request(
            path: "api/v1/support/campaign/reward-claim",
            method: "POST",
            jsonBody: body,
            useDateTimeDecoder: true
        )
        return SupportCampaignResponse(dto: dto)
    }
}

