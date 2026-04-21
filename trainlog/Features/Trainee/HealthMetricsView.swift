import SwiftUI

struct HealthMetricsView: View {
    let service: HealthServiceProtocol
    var isDemoMode: Bool = false

    @State private var authorizationState: HealthAuthorizationState = .notDetermined
    @State private var dashboard: HealthDashboardSummary?
    @State private var detail: HealthDetailSummary?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var ringReveal: Double = 0
    @State private var demoRefreshCounter = 0

    var body: some View {
        ScrollView {
            VStack(spacing: AppDesign.sectionSpacing) {
                heroCard

                if authorizationState == .authorized {
                    refreshActionButton
                }

                if isDemoMode {
                    SettingsCard(title: "Режим данных") {
                        Text("Включён демо-режим. Кнопка «Обновить» каждый раз подгружает новый набор выдуманных данных.")
                            .appTypography(.caption)
                            .foregroundStyle(AppColors.secondaryLabel)
                    }
                }

                contentByState
            }
            .padding(.top, AppDesign.sectionSpacing)
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .background(AdaptiveScreenBackground())
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var heroCard: some View {
        HeroCard(
            icon: "shield-check",
            title: "Apple Health",
            headline: "Здоровье и активность",
            description: "Шаги, энергия, сон и тренировки в одной сводке.",
            accent: AppColors.visitsBySubscription
        )
        .padding(.horizontal, AppDesign.cardPadding)
    }

    private var refreshActionButton: some View {
        Button {
            Task { await load() }
        } label: {
            HStack(spacing: 10) {
                AppTablerIcon("arrow-refresh-horizontal")
                    .appTypography(.numericMetric)
                Text("Обновить")
                    .appTypography(.sectionTitle)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppColors.accent, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(isLoading)
        .padding(.horizontal, AppDesign.cardPadding)
    }

    @ViewBuilder
    private var contentByState: some View {
        if isLoading {
            LoadingBlockView(message: "Загружаю данные Apple Health…")
        } else {
            switch authorizationState {
            case .notAvailable:
                accessStateCard(
                    icon: "troubleshoot",
                    title: "Apple Health недоступно",
                    description: "На этом устройстве нельзя получить метрики HealthKit"
                )
            case .notDetermined:
                accessStateCard(
                    icon: "shield-check",
                    title: "Подключите Apple Health",
                    description: "После подключения появится расширенная аналитика шагов, энергии, тренировок и сна",
                    actionTitle: "Подключить Apple Health",
                    action: { Task { await requestAccess() } }
                )
            case .denied:
                accessStateCard(
                    icon: "shield",
                    title: "Доступ не выдан",
                    description: "Разрешите доступ к данным в настройках iOS, затем обновите экран",
                    actionTitle: "Проверить доступ",
                    action: { Task { await requestAccess() } }
                )
            case .authorized:
                if let detail {
                    metricsContent(detail: detail, dashboard: dashboard)
                } else if let errorMessage {
                    EmptyStateView(
                        icon: "shield",
                        title: "Не удалось загрузить",
                        description: errorMessage
                    ) {
                        Button("Повторить") {
                            Task { await load() }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                } else {
                    EmptyStateView(
                        icon: "shield-check",
                        title: "Нет данных",
                        description: "Apple Health не вернул данные за доступный период"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func metricsContent(detail: HealthDetailSummary, dashboard: HealthDashboardSummary?) -> some View {
        sevenDayMiniDashboard(detail: detail)
        trendCard(dashboard: dashboard)
        metricTiles(detail: detail, dashboard: dashboard)
        activityRingsCard(detail: detail, dashboard: dashboard)
    }

    private func activityRingsCard(detail: HealthDetailSummary, dashboard: HealthDashboardSummary?) -> some View {
        let stepsToday = dashboard?.stepsToday ?? (detail.days.last?.steps ?? 0)
        let energyToday = dashboard?.activeEnergyKcalToday ?? (detail.days.last?.activeEnergyKcal ?? 0)
        let workoutToday = detail.days.last?.workoutMinutes ?? 0

        let stepsGoal = 10_000.0
        let energyGoal = 600.0
        let workoutGoal = 45.0

        let stepsProgress = min(Double(stepsToday) / stepsGoal, 1)
        let energyProgress = min(Double(energyToday) / energyGoal, 1)
        let workoutProgress = min(Double(workoutToday) / workoutGoal, 1)

        return SettingsCard(title: "Кольца активности") {
            VStack(spacing: 14) {
                ZStack {
                    activityRing(
                        progress: stepsProgress * ringReveal,
                        color: AppColors.genderMale,
                        lineWidth: 16,
                        size: 176
                    )
                    activityRing(
                        progress: energyProgress * ringReveal,
                        color: AppColors.visitsOneTimeDebt,
                        lineWidth: 13,
                        size: 140
                    )
                    activityRing(
                        progress: workoutProgress * ringReveal,
                        color: AppColors.visitsBySubscription,
                        lineWidth: 10,
                        size: 108
                    )
                    VStack(spacing: 3) {
                        Text("Сегодня")
                            .appTypography(.caption)
                            .foregroundStyle(AppColors.secondaryLabel)
                        Text("\(stepsToday)")
                            .appTypography(.numericMetric)
                        Text("шагов")
                            .appTypography(.caption)
                            .foregroundStyle(AppColors.secondaryLabel)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)

                HStack(spacing: 10) {
                    ringLegend(
                        color: AppColors.genderMale,
                        title: "Шаги",
                        subtitle: "\(stepsToday) / \(Int(stepsGoal))"
                    )
                    ringLegend(
                        color: AppColors.visitsOneTimeDebt,
                        title: "Энергия",
                        subtitle: "\(energyToday) / \(Int(energyGoal)) ккал"
                    )
                    ringLegend(
                        color: AppColors.visitsBySubscription,
                        title: "Тренировки",
                        subtitle: "\(workoutToday) / \(Int(workoutGoal)) мин"
                    )
                }
            }
        }
    }

    private func metricTiles(detail: HealthDetailSummary, dashboard: HealthDashboardSummary?) -> some View {
        SettingsCard(title: "Ключевые показатели") {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    metricTile(
                        title: "Шаги сегодня",
                        value: "\(dashboard?.stepsToday ?? detail.totalSteps)",
                        icon: "user-default",
                        color: AppColors.genderMale
                    )
                    metricTile(
                        title: "Энергия сегодня",
                        value: "\(dashboard?.activeEnergyKcalToday ?? detail.totalActiveEnergyKcal) ккал",
                        icon: "sparkle-ai-01",
                        color: AppColors.visitsOneTimeDebt
                    )
                }
                HStack(spacing: 10) {
                    metricTile(
                        title: "Тренировки 7д",
                        value: "\(dashboard?.workoutsLast7DaysMinutes ?? detail.totalWorkoutMinutes) мин",
                        icon: "user-default",
                        color: AppColors.visitsBySubscription
                    )
                    metricTile(
                        title: "Сон",
                        value: sleepText(from: detail, dashboard: dashboard),
                        icon: "bed.double.fill",
                        color: AppColors.accent
                    )
                }
            }
        }
    }

    private func metricTile(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                AppTablerIcon(icon)
                    .appTypography(.caption)
                Text(title)
                    .appTypography(.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
            }
            Text(value)
                .appTypography(.sectionTitle)
                .foregroundStyle(AppColors.label)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func sevenDayMiniDashboard(detail: HealthDetailSummary) -> some View {
        let days = Array(detail.days.suffix(7))
        let stepsTotal = days.reduce(0) { $0 + $1.steps }
        let energyTotal = days.reduce(0) { $0 + $1.activeEnergyKcal }
        let workoutTotal = days.reduce(0) { $0 + $1.workoutMinutes }
        let activeDays = days.filter { $0.steps > 0 || $0.workoutMinutes > 0 }.count
        let avgSteps = days.isEmpty ? 0 : stepsTotal / days.count
        let maxSteps = max(days.map(\.steps).max() ?? 1, 1)

        return SettingsCard(title: "Мини-дашборд: последние 7 дней") {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    miniKpi(title: "Шаги", value: "\(stepsTotal)", tint: AppColors.genderMale)
                    miniKpi(title: "Энергия", value: "\(energyTotal) ккал", tint: AppColors.visitsOneTimeDebt)
                    miniKpi(title: "Тренировки", value: "\(workoutTotal) мин", tint: AppColors.visitsBySubscription)
                }
                HStack {
                    Text("Среднее шагов: \(avgSteps)")
                        .appTypography(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                    Spacer()
                    Text("Активных дней: \(activeDays)/7")
                        .appTypography(.caption)
                        .foregroundStyle(AppColors.label)
                }

                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(days, id: \.date) { day in
                        let normalized = maxSteps > 0 ? Double(day.steps) / Double(maxSteps) : 0
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(AppColors.genderMale.opacity(0.9))
                                .frame(height: 8 + (38 * normalized * ringReveal))
                            Text(day.steps >= 10000 ? "\(day.steps / 1000)k" : "\(day.steps / 1000).\(max((day.steps % 1000) / 100, 0))k")
                                .appTypography(.caption)
                                .foregroundStyle(AppColors.secondaryLabel)
                            Text(shortDayLabel(day.date))
                                .appTypography(.caption)
                                .foregroundStyle(AppColors.tertiaryLabel)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 58)
            }
        }
    }

    @ViewBuilder
    private func trendCard(dashboard: HealthDashboardSummary?) -> some View {
        if let dashboard {
            SettingsCard(title: "Тренды к прошлой неделе") {
                VStack(spacing: 10) {
                    trendTile(
                        title: "Шаги",
                        value: dashboard.stepsTrendPercentVsPrev7Days,
                        tint: AppColors.genderMale,
                        icon: "user-default"
                    )
                    trendTile(
                        title: "Энергия",
                        value: dashboard.energyTrendPercentVsPrev7Days,
                        tint: AppColors.visitsOneTimeDebt,
                        icon: "sparkle-ai-01"
                    )
                    trendTile(
                        title: "Тренировки",
                        value: dashboard.workoutMinutesTrendPercentVsPrev7Days,
                        tint: AppColors.visitsBySubscription,
                        icon: "user-default"
                    )
                }
            }
        }
    }

    private func trendTile(title: String, value: Double?, tint: Color, icon: String) -> some View {
        let trend = value ?? 0
        let sign = trend > 0 ? "+" : ""
        let trendColor: Color = trend > 0 ? AppColors.visitsBySubscription : (trend < 0 ? AppColors.visitsCancelled : AppColors.secondaryLabel)
        let amplitude = min(abs(trend) / 20.0, 1.0)
        return VStack(spacing: 6) {
            HStack(spacing: 8) {
                AppTablerIcon(icon)
                    .appTypography(.caption)
                    .foregroundStyle(tint)
                Text(title)
                    .appTypography(.bodyEmphasis)
                Spacer()
                AppTablerIcon(trend > 0 ? "arrow.up.right" : (trend < 0 ? "arrow.down.right" : "minus"))
                    .appTypography(.caption)
                    .foregroundStyle(trendColor)
                Text("\(sign)\(Int(trend.rounded()))%")
                    .appTypography(.bodyEmphasis)
                    .foregroundStyle(trendColor)
            }
            GeometryReader { proxy in
                let width = proxy.size.width * amplitude
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.tertiarySystemFill.opacity(0.55))
                    Capsule()
                        .fill(trendColor.opacity(0.9))
                        .frame(width: width)
                }
            }
            .frame(height: 8)
        }
        .padding(10)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func activityRing(progress: Double, color: Color, lineWidth: CGFloat, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }

    private func ringLegend(color: Color, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title)
                    .appTypography(.caption)
                    .foregroundStyle(AppColors.label)
            }
            Text(subtitle)
                .appTypography(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func miniKpi(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .appTypography(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
            Text(value)
                .appTypography(.bodyEmphasis)
                .foregroundStyle(AppColors.label)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func shortDayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EE"
        return formatter.string(from: date).prefix(2).uppercased()
    }

    private func accessStateCard(
        icon: String,
        title: String,
        description: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        SettingsCard(title: "Доступ к данным") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    AppTablerIcon(icon)
                        .appTypography(.sectionTitle)
                        .foregroundStyle(AppColors.accent)
                    Text(title)
                        .appTypography(.sectionTitle)
                }
                Text(description)
                    .appTypography(.secondary)
                    .foregroundStyle(AppColors.secondaryLabel)
                if let actionTitle, let action {
                    MainActionButton(title: actionTitle, action: action)
                        .padding(.top, 2)
                }
            }
        }
    }

    private func sleepText(from detail: HealthDetailSummary, dashboard: HealthDashboardSummary?) -> String {
        if let value = dashboard?.sleepLastNightHours {
            return String(format: "%.1f ч", value)
        }
        if let value = detail.averageSleepHours {
            return String(format: "%.1f ч", value)
        }
        return "нет данных"
    }

    private func requestAccess() async {
        guard !isDemoMode else {
            await load()
            return
        }
        guard service.isAvailable else {
            await MainActor.run {
                authorizationState = .notAvailable
            }
            return
        }
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        do {
            let status = try await service.requestAuthorization()
            await MainActor.run { authorizationState = status }
            await load()
        } catch {
            await MainActor.run {
                isLoading = false
                if let msg = AppErrors.userMessageIfNeeded(for: error), !msg.isEmpty {
                    errorMessage = msg
                } else {
                    errorMessage = "Не удалось запросить доступ к Apple Health"
                }
            }
        }
    }

    private func load() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        if isDemoMode {
            await MainActor.run {
                demoRefreshCounter += 1
                authorizationState = .authorized
            }

            let referenceDate = Date().addingTimeInterval(TimeInterval(demoRefreshCounter * 86_400))
            do {
                async let dashboardValue = service.fetchDashboardSummary(referenceDate: referenceDate)
                async let detailValue = service.fetchDetailSummary(period: .days90, referenceDate: referenceDate)
                let (dashboardResult, detailResult) = try await (dashboardValue, detailValue)
                await MainActor.run {
                    dashboard = dashboardResult
                    detail = detailResult
                    isLoading = false
                    ringReveal = 0
                    withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) {
                        ringReveal = 1
                    }
                }
            } catch {
                await MainActor.run {
                    dashboard = nil
                    detail = nil
                    isLoading = false
                    errorMessage = "Не удалось загрузить демо-данные Apple Health"
                }
            }
            return
        }

        guard service.isAvailable else {
            await MainActor.run {
                authorizationState = .notAvailable
                dashboard = nil
                detail = nil
                isLoading = false
            }
            return
        }

        let status = await service.authorizationStatus()
        await MainActor.run { authorizationState = status }
        guard status == .authorized else {
            await MainActor.run {
                dashboard = nil
                detail = nil
                isLoading = false
            }
            return
        }

        do {
            async let dashboardValue = service.fetchDashboardSummary(referenceDate: Date())
            async let detailValue = service.fetchDetailSummary(period: .days90, referenceDate: Date())
            let (dashboardResult, detailResult) = try await (dashboardValue, detailValue)
            await MainActor.run {
                dashboard = dashboardResult
                detail = detailResult
                isLoading = false
                ringReveal = 0
                withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) {
                    ringReveal = 1
                }
            }
        } catch {
            await MainActor.run {
                dashboard = nil
                detail = nil
                isLoading = false
                if let msg = AppErrors.userMessageIfNeeded(for: error), !msg.isEmpty {
                    errorMessage = msg
                } else {
                    errorMessage = "Не удалось получить данные Apple Health"
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        HealthMetricsView(service: MockHealthService())
    }
}

