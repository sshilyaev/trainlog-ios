import Foundation

enum HealthAuthorizationState: Equatable {
    case notAvailable
    case notDetermined
    case denied
    case authorized
}

enum HealthPeriod: Int, CaseIterable, Identifiable {
    case today = 1
    case days7 = 7
    case days30 = 30
    case days90 = 90

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .today: return "Сегодня"
        case .days7: return "7 дней"
        case .days30: return "30 дней"
        case .days90: return "90 дней"
        }
    }
}

struct HealthDashboardSummary: Equatable {
    let stepsToday: Int
    let activeEnergyKcalToday: Int
    let workoutsLast7DaysCount: Int
    let workoutsLast7DaysMinutes: Int
    let sleepLastNightHours: Double?
    let stepsTrendPercentVsPrev7Days: Double?
    let energyTrendPercentVsPrev7Days: Double?
    let workoutMinutesTrendPercentVsPrev7Days: Double?
    let updatedAt: Date
}

struct HealthDailySummary: Equatable, Identifiable {
    let date: Date
    let steps: Int
    let activeEnergyKcal: Int
    let workoutMinutes: Int
    let workoutsCount: Int
    let sleepHours: Double?

    var id: TimeInterval { date.timeIntervalSince1970 }
}

struct HealthDetailSummary: Equatable {
    let period: HealthPeriod
    let days: [HealthDailySummary]
    let totalSteps: Int
    let totalActiveEnergyKcal: Int
    let totalWorkoutMinutes: Int
    let totalWorkouts: Int
    let averageSleepHours: Double?
    let updatedAt: Date
}

enum HealthServiceError: Error, LocalizedError {
    case notAvailable
    case accessDenied
    case noData

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Apple Health недоступно на этом устройстве"
        case .accessDenied:
            return "Нет доступа к данным Apple Health. Разрешите доступ в настройках"
        case .noData:
            return "Пока нет данных Apple Health для выбранного периода"
        }
    }
}

protocol HealthServiceProtocol {
    var isAvailable: Bool { get }

    func authorizationStatus() async -> HealthAuthorizationState
    func requestAuthorization() async throws -> HealthAuthorizationState

    func fetchDashboardSummary(referenceDate: Date) async throws -> HealthDashboardSummary
    func fetchDetailSummary(period: HealthPeriod, referenceDate: Date) async throws -> HealthDetailSummary
}

