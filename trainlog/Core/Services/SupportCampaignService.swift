import Foundation

protocol SupportCampaignServiceProtocol {
    func fetchCampaign() async throws -> SupportCampaignResponse
    func createNewCampaign(goalType: SupportCampaignGoalType?) async throws -> SupportCampaignResponse
    func claimReward(adProvider: String, externalEventId: String, rewardValueKg: Double) async throws -> SupportCampaignResponse
}

enum SupportCampaignGoalType: String, Codable, CaseIterable {
    case loseWeight = "lose_weight"
    case gainWeight = "gain_weight"

    var title: String {
        switch self {
        case .loseWeight: return "Снижение веса"
        case .gainWeight: return "Набор веса"
        }
    }
}

enum SupportCampaignStatus: String, Codable {
    case active
    case completed
}

struct SupportCampaignState: Equatable {
    let id: String
    let goalType: SupportCampaignGoalType
    let status: SupportCampaignStatus
    let startWeightKg: Double
    let currentWeightKg: Double
    let targetWeightKg: Double
    let savedClientsCount: Int
    let updatedAt: Date

    var progressFraction: Double {
        switch goalType {
        case .loseWeight:
            let total = max(0.1, startWeightKg - targetWeightKg)
            let done = startWeightKg - currentWeightKg
            return min(1.0, max(0.0, done / total))
        case .gainWeight:
            let total = max(0.1, targetWeightKg - startWeightKg)
            let done = currentWeightKg - startWeightKg
            return min(1.0, max(0.0, done / total))
        }
    }
}

struct SupportCampaignHistoryItem: Equatable, Identifiable {
    let id: String
    let goalType: SupportCampaignGoalType
    let startWeightKg: Double
    let targetWeightKg: Double
    let createdAt: Date
}

struct SupportCampaignMeta: Equatable {
    let rewardEventsTotal: Int
    let isIdempotent: Bool
    let rewardEventId: String?
}

struct SupportCampaignResponse: Equatable {
    let campaign: SupportCampaignState
    let history: [SupportCampaignHistoryItem]
    let meta: SupportCampaignMeta
}

// MARK: - DTO

struct SupportCampaignResponseDTO: Decodable {
    let campaign: SupportCampaignStateDTO
    let history: [SupportCampaignHistoryItemDTO]
    let meta: SupportCampaignMetaDTO
}

struct SupportCampaignStateDTO: Decodable {
    let id: String
    let goalType: SupportCampaignGoalType
    let status: SupportCampaignStatus
    let startWeightKg: Double
    let currentWeightKg: Double
    let targetWeightKg: Double
    let savedClientsCount: Int
    let updatedAt: Date
}

struct SupportCampaignHistoryItemDTO: Decodable {
    let id: String
    let goalType: SupportCampaignGoalType
    let startWeightKg: Double
    let targetWeightKg: Double
    let createdAt: Date
}

struct SupportCampaignMetaDTO: Decodable {
    let rewardEventsTotal: Int
    let idempotent: Bool
    let rewardEventId: String?
}

extension SupportCampaignResponse {
    init(dto: SupportCampaignResponseDTO) {
        self.campaign = SupportCampaignState(
            id: dto.campaign.id,
            goalType: dto.campaign.goalType,
            status: dto.campaign.status,
            startWeightKg: dto.campaign.startWeightKg,
            currentWeightKg: dto.campaign.currentWeightKg,
            targetWeightKg: dto.campaign.targetWeightKg,
            savedClientsCount: dto.campaign.savedClientsCount,
            updatedAt: dto.campaign.updatedAt
        )
        self.history = dto.history.map {
            SupportCampaignHistoryItem(
                id: $0.id,
                goalType: $0.goalType,
                startWeightKg: $0.startWeightKg,
                targetWeightKg: $0.targetWeightKg,
                createdAt: $0.createdAt
            )
        }
        self.meta = SupportCampaignMeta(
            rewardEventsTotal: dto.meta.rewardEventsTotal,
            isIdempotent: dto.meta.idempotent,
            rewardEventId: dto.meta.rewardEventId
        )
    }
}

