import Foundation

struct RewardedAdResult {
    let adProvider: String
    let externalEventId: String
}

protocol RewardedAdServiceProtocol {
    /// Возвращает данные для reward-claim только если просмотр завершён и награда подтверждена.
    func presentRewardedAd() async throws -> RewardedAdResult
}

enum RewardedAdError: LocalizedError {
    case cancelled
    case unavailable

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Просмотр прерван. Награда не начислена."
        case .unavailable:
            return "Реклама сейчас недоступна. Попробуйте позже."
        }
    }
}

final class DevMockRewardedAdService: RewardedAdServiceProtocol {
    func presentRewardedAd() async throws -> RewardedAdResult {
        try await Task.sleep(nanoseconds: 900_000_000)
        return RewardedAdResult(
            adProvider: "dev_mock",
            externalEventId: UUID().uuidString
        )
    }
}

/// Placeholder для прод-провайдера. Реальный SDK добавим отдельным шагом.
final class YandexRewardedAdService: RewardedAdServiceProtocol {
    func presentRewardedAd() async throws -> RewardedAdResult {
        throw RewardedAdError.unavailable
    }
}

final class HybridRewardedAdService: RewardedAdServiceProtocol {
    private let primary: RewardedAdServiceProtocol
    private let fallback: RewardedAdServiceProtocol

    init(primary: RewardedAdServiceProtocol, fallback: RewardedAdServiceProtocol) {
        self.primary = primary
        self.fallback = fallback
    }

    func presentRewardedAd() async throws -> RewardedAdResult {
        do {
            return try await primary.presentRewardedAd()
        } catch {
            return try await fallback.presentRewardedAd()
        }
    }
}

