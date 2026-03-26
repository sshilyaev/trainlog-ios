import Foundation

#if canImport(HealthKit)
import HealthKit

final class HealthKitService: HealthServiceProtocol {
    private let store = HKHealthStore()
    private let calendar = Calendar.current

    private var readTypes: Set<HKObjectType> {
        var set: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) { set.insert(steps) }
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { set.insert(energy) }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { set.insert(sleep) }
        return set
    }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func authorizationStatus() async -> HealthAuthorizationState {
        guard isAvailable else { return .notAvailable }
        guard let steps = HKObjectType.quantityType(forIdentifier: .stepCount) else { return .notAvailable }
        switch store.authorizationStatus(for: steps) {
        case .sharingAuthorized: return .authorized
        case .notDetermined: return .notDetermined
        case .sharingDenied: return .denied
        @unknown default: return .denied
        }
    }

    func requestAuthorization() async throws -> HealthAuthorizationState {
        guard isAvailable else { throw HealthServiceError.notAvailable }
        return try await withCheckedThrowingContinuation { continuation in
            store.requestAuthorization(toShare: [], read: readTypes) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                Task {
                    let status = await self.authorizationStatus()
                    continuation.resume(returning: status)
                }
            }
        }
    }

    func fetchDashboardSummary(referenceDate: Date = Date()) async throws -> HealthDashboardSummary {
        guard isAvailable else { throw HealthServiceError.notAvailable }
        let auth = await authorizationStatus()
        guard auth == .authorized else { throw HealthServiceError.accessDenied }

        let todayStart = calendar.startOfDay(for: referenceDate)
        let now = referenceDate

        let current7Start = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
        let previous7Start = calendar.date(byAdding: .day, value: -13, to: todayStart) ?? todayStart
        let previous7End = current7Start

        async let stepsToday = sumQuantity(.stepCount, unit: .count(), start: todayStart, end: now)
        async let energyToday = sumQuantity(.activeEnergyBurned, unit: .kilocalorie(), start: todayStart, end: now)

        async let stepsCurrent7 = sumQuantity(.stepCount, unit: .count(), start: current7Start, end: now)
        async let stepsPrevious7 = sumQuantity(.stepCount, unit: .count(), start: previous7Start, end: previous7End)

        async let energyCurrent7 = sumQuantity(.activeEnergyBurned, unit: .kilocalorie(), start: current7Start, end: now)
        async let energyPrevious7 = sumQuantity(.activeEnergyBurned, unit: .kilocalorie(), start: previous7Start, end: previous7End)

        async let workoutsCurrent7 = workouts(start: current7Start, end: now)
        async let workoutsPrevious7 = workouts(start: previous7Start, end: previous7End)

        async let sleepLastNight = lastNightSleepHours(referenceDate: referenceDate)

        let (sToday, eToday, sCurr7, sPrev7, eCurr7, ePrev7, wCurr7, wPrev7, sleep) =
            try await (stepsToday, energyToday, stepsCurrent7, stepsPrevious7, energyCurrent7, energyPrevious7, workoutsCurrent7, workoutsPrevious7, sleepLastNight)

        let currMinutes = Int(wCurr7.map(\.duration).reduce(0, +) / 60.0)
        let prevMinutes = Int(wPrev7.map(\.duration).reduce(0, +) / 60.0)

        return HealthDashboardSummary(
            stepsToday: Int(sToday.rounded()),
            activeEnergyKcalToday: Int(eToday.rounded()),
            workoutsLast7DaysCount: wCurr7.count,
            workoutsLast7DaysMinutes: currMinutes,
            sleepLastNightHours: sleep,
            stepsTrendPercentVsPrev7Days: trendPercent(current: sCurr7, previous: sPrev7),
            energyTrendPercentVsPrev7Days: trendPercent(current: eCurr7, previous: ePrev7),
            workoutMinutesTrendPercentVsPrev7Days: trendPercent(current: Double(currMinutes), previous: Double(prevMinutes)),
            updatedAt: Date()
        )
    }

    func fetchDetailSummary(period: HealthPeriod, referenceDate: Date = Date()) async throws -> HealthDetailSummary {
        guard isAvailable else { throw HealthServiceError.notAvailable }
        let auth = await authorizationStatus()
        guard auth == .authorized else { throw HealthServiceError.accessDenied }

        let endDay = calendar.startOfDay(for: referenceDate)
        let startDay = calendar.date(byAdding: .day, value: -(period.rawValue - 1), to: endDay) ?? endDay

        var days: [HealthDailySummary] = []
        var cursor = startDay
        for _ in 0..<period.rawValue {
            let next = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
            let dayStart = cursor
            let dayEnd = next
            async let steps = sumQuantity(.stepCount, unit: .count(), start: dayStart, end: dayEnd)
            async let energy = sumQuantity(.activeEnergyBurned, unit: .kilocalorie(), start: dayStart, end: dayEnd)
            async let dayWorkouts = workouts(start: dayStart, end: dayEnd)
            async let sleep = sleepHours(onDayStartingAt: dayStart)
            let (s, e, w, sl) = try await (steps, energy, dayWorkouts, sleep)
            let minutes = Int(w.map(\.duration).reduce(0, +) / 60.0)
            days.append(
                HealthDailySummary(
                    date: dayStart,
                    steps: Int(s.rounded()),
                    activeEnergyKcal: Int(e.rounded()),
                    workoutMinutes: minutes,
                    workoutsCount: w.count,
                    sleepHours: sl
                )
            )
            cursor = next
        }

        let totalSteps = days.reduce(0) { $0 + $1.steps }
        let totalEnergy = days.reduce(0) { $0 + $1.activeEnergyKcal }
        let totalMinutes = days.reduce(0) { $0 + $1.workoutMinutes }
        let totalWorkouts = days.reduce(0) { $0 + $1.workoutsCount }
        let sleepValues = days.compactMap(\.sleepHours)
        let avgSleep = sleepValues.isEmpty ? nil : sleepValues.reduce(0, +) / Double(sleepValues.count)

        return HealthDetailSummary(
            period: period,
            days: days,
            totalSteps: totalSteps,
            totalActiveEnergyKcal: totalEnergy,
            totalWorkoutMinutes: totalMinutes,
            totalWorkouts: totalWorkouts,
            averageSleepHours: avgSleep,
            updatedAt: Date()
        )
    }

    // MARK: - HealthKit helpers

    private func sumQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async throws -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let value = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func workouts(start: Date, end: Date) async throws -> [HKWorkout] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }
    }

    private func lastNightSleepHours(referenceDate: Date) async throws -> Double? {
        let dayStart = calendar.startOfDay(for: referenceDate)
        let sleepWindowStart = calendar.date(byAdding: .hour, value: -18, to: dayStart) ?? dayStart
        let sleepWindowEnd = calendar.date(byAdding: .hour, value: 12, to: dayStart) ?? referenceDate
        return try await sleepHours(start: sleepWindowStart, end: sleepWindowEnd)
    }

    private func sleepHours(onDayStartingAt dayStart: Date) async throws -> Double? {
        let start = calendar.date(byAdding: .hour, value: -6, to: dayStart) ?? dayStart
        let end = calendar.date(byAdding: .hour, value: 18, to: dayStart) ?? dayStart
        return try await sleepHours(start: start, end: end)
    }

    private func sleepHours(start: Date, end: Date) async throws -> Double? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let catSamples = (samples as? [HKCategorySample]) ?? []
                let asleepSeconds = catSamples.reduce(0.0) { partial, sample in
                    let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)
                    switch value {
                    case .asleepCore, .asleepDeep, .asleepREM, .asleepUnspecified:
                        return partial + sample.endDate.timeIntervalSince(sample.startDate)
                    default:
                        return partial
                    }
                }
                if asleepSeconds <= 0 {
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: asleepSeconds / 3600.0)
                }
            }
            store.execute(query)
        }
    }

    private func trendPercent(current: Double, previous: Double) -> Double? {
        guard previous > 0 else { return nil }
        return ((current - previous) / previous) * 100
    }
}

#else

final class HealthKitService: HealthServiceProtocol {
    var isAvailable: Bool { false }
    func authorizationStatus() async -> HealthAuthorizationState { .notAvailable }
    func requestAuthorization() async throws -> HealthAuthorizationState { .notAvailable }
    func fetchDashboardSummary(referenceDate: Date) async throws -> HealthDashboardSummary { throw HealthServiceError.notAvailable }
    func fetchDetailSummary(period: HealthPeriod, referenceDate: Date) async throws -> HealthDetailSummary { throw HealthServiceError.notAvailable }
}

#endif

