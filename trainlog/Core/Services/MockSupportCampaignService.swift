import Foundation

final class MockSupportCampaignService: SupportCampaignServiceProtocol {
    private var state: SupportCampaignState
    private var history: [SupportCampaignHistoryItem] = []
    private var rewardEventsTotal: Int = 0
    private var seenEventIds: Set<String> = []

    init() {
        state = Self.makeState(goalType: .loseWeight, savedClientsCount: 0)
    }

    func fetchCampaign() async throws -> SupportCampaignResponse {
        SupportCampaignResponse(
            campaign: state,
            history: history,
            meta: .init(rewardEventsTotal: rewardEventsTotal, isIdempotent: false, rewardEventId: nil)
        )
    }

    func createNewCampaign(goalType: SupportCampaignGoalType?) async throws -> SupportCampaignResponse {
        state = Self.makeState(goalType: goalType ?? (Bool.random() ? .loseWeight : .gainWeight), savedClientsCount: state.savedClientsCount)
        return try await fetchCampaign()
    }

    func claimReward(adProvider: String, externalEventId: String, rewardValueKg: Double) async throws -> SupportCampaignResponse {
        if seenEventIds.contains(externalEventId) {
            return SupportCampaignResponse(
                campaign: state,
                history: history,
                meta: .init(rewardEventsTotal: rewardEventsTotal, isIdempotent: true, rewardEventId: UUID().uuidString)
            )
        }
        seenEventIds.insert(externalEventId)
        rewardEventsTotal += 1

        let reward = max(0.1, min(5.0, rewardValueKg))
        switch state.goalType {
        case .loseWeight:
            state = SupportCampaignState(
                id: state.id,
                goalType: state.goalType,
                status: state.status,
                startWeightKg: state.startWeightKg,
                currentWeightKg: max(state.targetWeightKg, state.currentWeightKg - reward),
                targetWeightKg: state.targetWeightKg,
                savedClientsCount: state.savedClientsCount,
                updatedAt: Date()
            )
        case .gainWeight:
            state = SupportCampaignState(
                id: state.id,
                goalType: state.goalType,
                status: state.status,
                startWeightKg: state.startWeightKg,
                currentWeightKg: min(state.targetWeightKg, state.currentWeightKg + reward),
                targetWeightKg: state.targetWeightKg,
                savedClientsCount: state.savedClientsCount,
                updatedAt: Date()
            )
        }

        if state.progressFraction >= 0.999 {
            history.insert(
                SupportCampaignHistoryItem(
                    id: UUID().uuidString,
                    goalType: state.goalType,
                    startWeightKg: state.startWeightKg,
                    targetWeightKg: state.targetWeightKg,
                    createdAt: Date()
                ),
                at: 0
            )
            state = SupportCampaignState(
                id: state.id,
                goalType: state.goalType,
                status: .completed,
                startWeightKg: state.startWeightKg,
                currentWeightKg: state.targetWeightKg,
                targetWeightKg: state.targetWeightKg,
                savedClientsCount: state.savedClientsCount + 1,
                updatedAt: Date()
            )
        }

        return SupportCampaignResponse(
            campaign: state,
            history: history,
            meta: .init(rewardEventsTotal: rewardEventsTotal, isIdempotent: false, rewardEventId: UUID().uuidString)
        )
    }

    private static func makeState(goalType: SupportCampaignGoalType, savedClientsCount: Int) -> SupportCampaignState {
        switch goalType {
        case .loseWeight:
            let start = Double(Int.random(in: 80...120))
            let target = Double(Int(start) - Int.random(in: 6...15))
            return SupportCampaignState(
                id: UUID().uuidString,
                goalType: .loseWeight,
                status: .active,
                startWeightKg: start,
                currentWeightKg: start,
                targetWeightKg: max(45, target),
                savedClientsCount: savedClientsCount,
                updatedAt: Date()
            )
        case .gainWeight:
            let start = Double(Int.random(in: 50...80))
            let target = Double(Int(start) + Int.random(in: 4...12))
            return SupportCampaignState(
                id: UUID().uuidString,
                goalType: .gainWeight,
                status: .active,
                startWeightKg: start,
                currentWeightKg: start,
                targetWeightKg: min(120, target),
                savedClientsCount: savedClientsCount,
                updatedAt: Date()
            )
        }
    }
}

