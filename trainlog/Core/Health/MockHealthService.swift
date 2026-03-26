import Foundation

final class MockHealthService: HealthServiceProtocol {
    var isAvailable: Bool = true
    var stubAuthorization: HealthAuthorizationState = .authorized

    func authorizationStatus() async -> HealthAuthorizationState {
        stubAuthorization
    }

    func requestAuthorization() async throws -> HealthAuthorizationState {
        if stubAuthorization == .notDetermined {
            stubAuthorization = .authorized
        }
        return stubAuthorization
    }

    func fetchDashboardSummary(referenceDate: Date) async throws -> HealthDashboardSummary {
        guard stubAuthorization == .authorized else { throw HealthServiceError.accessDenied }
        let seed = seededDay(referenceDate)
        let steps = 7200 + (seed % 3800)
        let energy = 470 + (seed % 260)
        let workoutsCount = 2 + (seed % 4)
        let workoutMinutes = 120 + (seed % 140)
        let sleep = 6.1 + Double(seed % 17) / 10.0
        let stepsTrend = Double((seed % 19) - 9)
        let energyTrend = Double((seed % 15) - 7)
        let workoutTrend = Double((seed % 13) - 6)
        return HealthDashboardSummary(
            stepsToday: steps,
            activeEnergyKcalToday: energy,
            workoutsLast7DaysCount: workoutsCount,
            workoutsLast7DaysMinutes: workoutMinutes,
            sleepLastNightHours: sleep,
            stepsTrendPercentVsPrev7Days: stepsTrend,
            energyTrendPercentVsPrev7Days: energyTrend,
            workoutMinutesTrendPercentVsPrev7Days: workoutTrend,
            updatedAt: Date()
        )
    }

    func fetchDetailSummary(period: HealthPeriod, referenceDate: Date) async throws -> HealthDetailSummary {
        guard stubAuthorization == .authorized else { throw HealthServiceError.accessDenied }
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: referenceDate)
        let start = calendar.date(byAdding: .day, value: -(period.rawValue - 1), to: end) ?? end
        let seed = seededDay(referenceDate)
        var day = start
        var rows: [HealthDailySummary] = []
        for i in 0..<period.rawValue {
            let mixed = i + seed
            let steps = 5600 + ((mixed * 173) % 5200)
            let energy = 360 + ((mixed * 37) % 330)
            let minutes = (mixed % 3 == 0) ? 50 : ((mixed % 5 == 0) ? 30 : ((mixed % 7 == 0) ? 20 : 0))
            let workouts = minutes > 0 ? 1 : 0
            let sleep = 5.9 + Double((mixed * 7) % 26) / 10.0
            rows.append(
                HealthDailySummary(
                    date: day,
                    steps: steps,
                    activeEnergyKcal: energy,
                    workoutMinutes: minutes,
                    workoutsCount: workouts,
                    sleepHours: sleep
                )
            )
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        }
        return HealthDetailSummary(
            period: period,
            days: rows,
            totalSteps: rows.reduce(0) { $0 + $1.steps },
            totalActiveEnergyKcal: rows.reduce(0) { $0 + $1.activeEnergyKcal },
            totalWorkoutMinutes: rows.reduce(0) { $0 + $1.workoutMinutes },
            totalWorkouts: rows.reduce(0) { $0 + $1.workoutsCount },
            averageSleepHours: rows.compactMap(\.sleepHours).average,
            updatedAt: Date()
        )
    }

    private func seededDay(_ date: Date) -> Int {
        Int(date.timeIntervalSince1970 / 86_400)
    }
}

private extension Array where Element == Double {
    var average: Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}

