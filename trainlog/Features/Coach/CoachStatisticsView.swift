//
//  CoachStatisticsView.swift
//  TrainLog
//

import SwiftUI
import Charts

/// Экран «Статистика» для тренера (открывается с экрана подопечных): визуализация по данным API (period, trainees, visits, memberships).
struct CoachStatisticsView: View {
    let coachProfileId: String
    let statisticsService: CoachStatisticsServiceProtocol

    @State private var stats: CoachStatisticsDTO?
    /// Для периода > 1 месяц: массив по месяцам от старого к новому (первый — самый ранний).
    @State private var statsForPeriod: [CoachStatisticsDTO] = []
    @State private var selectedMonth: Date = Date()
    @State private var periodMonths: Int = 3
    @State private var showVisitsChartValues = false
    @State private var showVisitsBySubscription = true
    @State private var showVisitsOneTimePaid = true
    @State private var showVisitsOneTimeDebt = true
    @State private var showVisitsCancelled = true
    @State private var showVisitsFilterSheet = false
    @State private var isLoading = true
    @State private var hasInitialLoadFinished = false
    @State private var errorMessage: String?

    private let calendar = Calendar.current

    private var monthParameter: String {
        let c = calendar.dateComponents([.year, .month], from: selectedMonth)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 1)
    }

    private var periodTitle: String {
        let f = DateFormatter()
        f.locale = .ru
        f.dateFormat = "LLLL yyyy"
        return f.string(from: selectedMonth).capitalized
    }

    /// Подпись к блоку метрик: один месяц или диапазон «февраль – апрель 2026».
    private var metricsPeriodLabel: String {
        if periodMonths <= 1 {
            return periodTitle.lowercased()
        }
        guard let start = calendar.date(byAdding: .month, value: -(periodMonths - 1), to: selectedMonth) else {
            return periodTitle.lowercased()
        }
        let monthFmt = DateFormatter()
        monthFmt.locale = .ru
        monthFmt.dateFormat = "LLLL"
        let startStr = monthFmt.string(from: start).capitalized
        let endStr = monthFmt.string(from: selectedMonth).capitalized
        let yStart = calendar.component(.year, from: start)
        let yEnd = calendar.component(.year, from: selectedMonth)
        if yStart == yEnd {
            return "\(startStr) – \(endStr) \(yEnd)"
        }
        return "\(startStr) \(yStart) – \(endStr) \(yEnd)"
    }

    var body: some View {
        Group {
            if isLoading && !hasInitialLoadFinished {
                CoachStatisticsSkeletonView()
            } else if let stats {
                ScrollView {
                    VStack(spacing: 0) {
                        periodPicker
                        visitsChartCard(stats)
                        metricsGrid(stats)
                            .id(
                                "metrics-\(monthParameter)-\(periodMonths)-\(metricsTraineesValue(stats))-\(metricsMembershipsValue(stats))"
                            )
                        endingSoonCard(stats)
                            .id("ending-\(monthParameter)-\(stats.memberships.endingSoonCount)")
                    }
                    .padding(.horizontal, AppDesign.cardPadding)
            .padding(.bottom, AppDesign.sectionSpacing)
                }
            } else if !isLoading {
                VStack(spacing: 20) {
                    ContentUnavailableView(
                        "Статистика пока недоступна",
                        image: "tabler-outline-grid-dashboard-circle",
                        description: Text(errorMessage ?? "Попробуйте обновить позже.")
                    )
                    Button("Повторить") {
                        errorMessage = nil
                        Task { await load() }
                    }
                    .buttonStyle(.borderedProminent)
                    Text("Данные обновляются не чаще чем раз в 5 минут.")
                        .appTypography(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppDesign.cardPadding)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 24)
            } else {
                AppColors.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(AdaptiveScreenBackground())
        .overlay {
            if isLoading && hasInitialLoadFinished {
                LoadingOverlayView(message: "Загружаю")
            }
        }
        .navigationTitle("Статистика")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "\(monthParameter)-\(periodMonths)") { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showVisitsFilterSheet) {
            MainSheet(
                title: "Типы посещений",
                onBack: { showVisitsFilterSheet = false },
                trailing: {
                    Button("Готово") { showVisitsFilterSheet = false }
                        .fontWeight(.regular)
                },
                content: {
                    List {
                        Section("Типы посещений на графике") {
                            visitsFilterRow(
                                title: "По абонементу",
                                color: AppColors.visitsBySubscription,
                                isOn: $showVisitsBySubscription
                            )
                            visitsFilterRow(
                                title: "Разовые (оплаченные)",
                                color: AppColors.visitsOneTimePaid,
                                isOn: $showVisitsOneTimePaid
                            )
                            visitsFilterRow(
                                title: "Разовые (в долг)",
                                color: AppColors.visitsOneTimeDebt,
                                isOn: $showVisitsOneTimeDebt
                            )
                            visitsFilterRow(
                                title: "Отменённые",
                                color: AppColors.visitsCancelled,
                                isOn: $showVisitsCancelled
                            )
                        }
                    }
                }
            )
            .mainSheetPresentation(.half)
        }
    }

    private var periodPicker: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                AppTablerIcon("calendar-default")
                    .foregroundStyle(AppColors.accent)
                Text("Период")
                    .appTypography(.secondary)
                    .foregroundStyle(.secondary)
                Spacer()
                MonthPicker(selection: $selectedMonth)
                    .labelsHidden()
            }
            Picker("", selection: $periodMonths) {
                Text("1 месяц").tag(1)
                Text("3 месяца").tag(3)
                Text("6 месяцев").tag(6)
            }
            .pickerStyle(.segmented)
            Text("Обновляется не чаще чем раз в 5 минут")
                .appTypography(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, AppDesign.cardPadding)
        .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
        .padding(.top, AppDesign.blockSpacing)
    }

    private func visitsChartCard(_ s: CoachStatisticsDTO) -> some View {
        let points = visitsChartDataForDisplay(s)
        let isEmptyVisits = points.allSatisfy { $0.value == 0 }
        let typeOrder: [String: Int] = [
            "По абонементу": 0,
            "Разовые (в долг)": 1,
            "Разовые (оплаченные)": 2,
            "Отменённые": 3
        ]
        let typeColor: [String: Color] = [
            "По абонементу": AppColors.visitsBySubscription,
            "Разовые (в долг)": AppColors.visitsOneTimeDebt.opacity(0.9),
            "Разовые (оплаченные)": AppColors.visitsOneTimePaid,
            "Отменённые": AppColors.visitsCancelled
        ]

        struct MonthLabelItem: Identifiable {
            let id: String
            let monthLabel: String
            let orderedParts: [(type: String, value: Int)]
            let total: Int
        }

        // Одна подпись на столбик: "24 / 7 / 2 / 4" цветами серий.
        var monthOrder: [String] = []
        var byMonth: [String: [String: Int]] = [:]
        for p in points {
            if !monthOrder.contains(p.monthLabel) { monthOrder.append(p.monthLabel) }
            byMonth[p.monthLabel, default: [:]][p.type] = p.value
        }
        let monthLabels: [MonthLabelItem] = monthOrder.map { month in
            let values = byMonth[month, default: [:]]
            let parts = values
                .sorted { (typeOrder[$0.key] ?? 0) < (typeOrder[$1.key] ?? 0) }
                .map { (type: $0.key, value: $0.value) }
                .filter { $0.value > 0 }
            let total = parts.reduce(0) { $0 + $1.value }
            return MonthLabelItem(id: month, monthLabel: month, orderedParts: parts, total: total)
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                AppTablerIcon("calendar-filled")
                    .appTypography(.body)
                    .foregroundStyle(AppColors.accent)
                Text("Посещения")
                    .appTypography(.bodyEmphasis)
                    .foregroundStyle(.primary)
                Spacer()
            }
            if !isEmptyVisits {
                HStack(spacing: 8) {
                    Button {
                        showVisitsFilterSheet = true
                    } label: {
                        Label("Фильтр", appIcon: "filter-horizontal")
                            .appTypography(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        showVisitsChartValues.toggle()
                    } label: {
                        Text(showVisitsChartValues ? "Скрыть значения" : "Показать значения")
                            .appTypography(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            if isEmptyVisits {
                VStack(spacing: 10) {
                    AppTablerIcon("calendar-filled")
                        .appIcon(.s32)
                        .foregroundStyle(AppColors.accent.opacity(0.85))
                        .symbolRenderingMode(.hierarchical)
                    Text("Пока нет посещений")
                        .appTypography(.bodyEmphasis)
                        .foregroundStyle(.primary)
                    Text("Начните отмечать посещения у подопечных — и здесь появится динамика по месяцам.")
                        .appTypography(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: 12))
            } else {
                Chart {
                    ForEach(points) { point in
                        BarMark(
                            x: .value("Месяц", point.monthLabel),
                            y: .value("Визиты", point.value)
                        )
                        .foregroundStyle(by: .value("Тип", point.type))
                        .cornerRadius(6)
                    }
                    // Подписи значений над каждым столбиком.
                    if showVisitsChartValues {
                        ForEach(monthLabels) { item in
                            if item.total > 0 {
                                PointMark(
                                    x: .value("Месяц", item.monthLabel),
                                    y: .value("Визиты", item.total)
                                )
                                .opacity(0.0)
                                .annotation(position: .top, alignment: .center) {
                                    HStack(spacing: 0) {
                                        ForEach(Array(item.orderedParts.enumerated()), id: \.offset) { i, part in
                                            Text("\(part.value)")
                                                .appTypography(.caption)
                                                .foregroundStyle(typeColor[part.type] ?? .primary)
                                            if i != item.orderedParts.count - 1 {
                                                Text(" ")
                                                    .appTypography(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppColors.secondarySystemGroupedBackground.opacity(0.5), in: Capsule())
                                    .overlay(
                                        Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                                    )
                                    .offset(y: -2)
                                }
                            }
                        }
                    }
                }
                .chartForegroundStyleScale([
                    "По абонементу": AppColors.visitsBySubscription,
                    "Разовые (в долг)": AppColors.visitsOneTimeDebt.opacity(0.9),
                    "Разовые (оплаченные)": AppColors.visitsOneTimePaid,
                    "Отменённые": AppColors.visitsCancelled
                ])
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 6))
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                    }
                }
                .frame(height: 200)
            }
            VStack(alignment: .leading, spacing: 8) {
                // Подписи-значения над графиком для текущего месяца
                if periodMonths == 1 {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        visitsSummaryPill(
                            title: "Абонемент",
                            value: s.visits.thisMonthBySubscription ?? 0,
                            color: AppColors.visitsBySubscription
                        )
                        visitsSummaryPill(
                            title: "Разовые опл",
                            value: (s.visits.thisMonthOneTimePaid ?? 0),
                            color: AppColors.visitsOneTimePaid
                        )
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        visitsSummaryPill(
                            title: "Разовые долг",
                            value: (s.visits.thisMonthOneTimeDebt ?? 0),
                            color: AppColors.visitsOneTimeDebt
                        )
                        visitsSummaryPill(
                            title: "Отменённые",
                            value: (s.visits.thisMonthCancelled ?? 0),
                            color: AppColors.visitsCancelled
                        )
                    }
                }
                HStack(spacing: 16) {
                    visitsTrendLabel(current: s.visits.thisMonth, previous: s.visits.previousMonth)
                    Spacer()
                    Text("Всего: \(s.visits.total)")
                        .appTypography(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(AppDesign.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
        .padding(.top, AppDesign.blockSpacing)
    }

    private struct VisitsChartPoint: Identifiable {
        let id = UUID()
        let monthLabel: String
        let type: String
        let value: Int
    }

    private func visitsChartDataForDisplay(_ s: CoachStatisticsDTO) -> [VisitsChartPoint] {
        let base: [VisitsChartPoint]
        if periodMonths > 1, !statsForPeriod.isEmpty {
            base = visitsChartDataFromPeriod(statsForPeriod)
        } else {
            base = visitsChartData(s)
        }
        return base.filter { point in
            switch point.type {
            case "По абонементу":
                return showVisitsBySubscription
            case "Разовые (в долг)":
                return showVisitsOneTimeDebt
            case "Разовые (оплаченные)":
                return showVisitsOneTimePaid
            case "Отменённые":
                return showVisitsCancelled
            default:
                return true
            }
        }
    }

    private func visitsChartData(_ s: CoachStatisticsDTO) -> [VisitsChartPoint] {
        let prevLabel = previousMonthTitle
        let currLabel = periodTitle.split(separator: " ").first.map(String.init) ?? "Текущий"
        let prevBySub = s.visits.previousMonthBySubscription ?? 0
        let prevOnePaid = s.visits.previousMonthOneTimePaid ?? 0
        let prevOneDebt = s.visits.previousMonthOneTimeDebt ?? 0
        let prevCancelled = s.visits.previousMonthCancelled ?? 0
        let currBySub = s.visits.thisMonthBySubscription ?? 0
        let currOnePaid = s.visits.thisMonthOneTimePaid ?? 0
        let currOneDebt = s.visits.thisMonthOneTimeDebt ?? 0
        let currCancelled = s.visits.thisMonthCancelled ?? 0
        return [
            VisitsChartPoint(monthLabel: prevLabel, type: "По абонементу", value: prevBySub),
            VisitsChartPoint(monthLabel: prevLabel, type: "Разовые (оплаченные)", value: prevOnePaid),
            VisitsChartPoint(monthLabel: prevLabel, type: "Разовые (в долг)", value: prevOneDebt),
            VisitsChartPoint(monthLabel: prevLabel, type: "Отменённые", value: prevCancelled),
            VisitsChartPoint(monthLabel: currLabel, type: "По абонементу", value: currBySub),
            VisitsChartPoint(monthLabel: currLabel, type: "Разовые (оплаченные)", value: currOnePaid),
            VisitsChartPoint(monthLabel: currLabel, type: "Разовые (в долг)", value: currOneDebt),
            VisitsChartPoint(monthLabel: currLabel, type: "Отменённые", value: currCancelled)
        ]
    }

    private func visitsChartDataFromPeriod(_ arr: [CoachStatisticsDTO]) -> [VisitsChartPoint] {
        var points: [VisitsChartPoint] = []
        for dto in arr {
            let label = monthLabelFromYearMonth(dto.period)
            let bySub = dto.visits.thisMonthBySubscription ?? 0
            let onePaid = dto.visits.thisMonthOneTimePaid ?? 0
            let oneDebt = dto.visits.thisMonthOneTimeDebt ?? 0
            let cancelled = dto.visits.thisMonthCancelled ?? 0
            points.append(VisitsChartPoint(monthLabel: label, type: "По абонементу", value: bySub))
            points.append(VisitsChartPoint(monthLabel: label, type: "Разовые (оплаченные)", value: onePaid))
            points.append(VisitsChartPoint(monthLabel: label, type: "Разовые (в долг)", value: oneDebt))
            points.append(VisitsChartPoint(monthLabel: label, type: "Отменённые", value: cancelled))
        }
        return points
    }

    private func monthLabelFromYearMonth(_ yearMonth: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone.current
        guard let date = fmt.date(from: yearMonth) else { return yearMonth }
        let f = DateFormatter()
        f.locale = .ru
        f.dateFormat = "LLL"
        return f.string(from: date).capitalized
    }

    private var previousMonthTitle: String {
        guard let prev = calendar.date(byAdding: .month, value: -1, to: selectedMonth) else { return "Прошлый" }
        let f = DateFormatter()
        f.locale = .ru
        f.dateFormat = "LLLL"
        return f.string(from: prev).capitalized
    }

    @ViewBuilder
    private func visitsTrendLabel(current: Int, previous: Int) -> some View {
        let diff = current - previous
        if diff > 0 {
            Label("+\(diff) к прошлому месяцу", appIcon: "arrow-up-right")
                .appTypography(.caption)
                .foregroundStyle(AppColors.genderMale)
        } else if diff < 0 {
            Label("\(diff) к прошлому месяцу", appIcon: "arrow-down-right")
                .appTypography(.caption)
                .foregroundStyle(Color.gray)
        } else {
            Text("Без изменений")
                .appTypography(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func visitsFilterChip(title: String, color: Color, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(title)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isOn.wrappedValue ? AppColors.secondarySystemGroupedBackground : AppColors.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func visitsFilterRow(title: String, color: Color, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text(title)
            }
        }
    }

    private func visitsSummaryPill(title: String, value: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .appTypography(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .appTypography(.caption)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.secondarySystemGroupedBackground)
        )
    }

    private func metricsTraineesValue(_ s: CoachStatisticsDTO) -> Int {
        s.trainees.uniqueWithVisitsInPeriod ?? s.trainees.activeCount
    }

    private func metricsMembershipsValue(_ s: CoachStatisticsDTO) -> Int {
        s.memberships.createdInPeriod ?? s.memberships.activeCount
    }

    private func metricsGrid(_ s: CoachStatisticsDTO) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Показатели за \(metricsPeriodLabel)")
                .appTypography(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
            HStack(alignment: .top, spacing: AppDesign.blockSpacing) {
                StatMetricCard(
                    icon: "user-default",
                    title: "Подопечных",
                    value: "\(metricsTraineesValue(s))",
                    hintTitle: "Подопечные",
                    hintMessage: "Количество уникальных подопечных с хотя бы одним завершённым посещением за выбранный период."
                )
                .frame(maxWidth: .infinity)
                .id("trainees-\(monthParameter)-\(periodMonths)-\(metricsTraineesValue(s))")
                StatMetricCard(
                    icon: "tag",
                    title: "Абонементов",
                    value: "\(metricsMembershipsValue(s))",
                    hintTitle: "Абонементы",
                    hintMessage: "Количество абонементов, созданных в выбранный период."
                )
                .frame(maxWidth: .infinity)
                .id("memberships-\(monthParameter)-\(periodMonths)-\(metricsMembershipsValue(s))")
            }
        }
        .padding(.top, AppDesign.blockSpacing)
    }

    @ViewBuilder
    private func endingSoonCard(_ s: CoachStatisticsDTO) -> some View {
        if s.memberships.endingSoonCount > 0 {
            HStack(spacing: 12) {
                AppTablerIcon("message-exclamation")
                    .appTypography(.screenTitle)
                    .foregroundStyle(AppColors.visitsOneTimeDebt)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Скоро заканчиваются")
                        .appTypography(.secondary)
                        .foregroundStyle(.primary)
                    Text("\(s.memberships.endingSoonCount) абонемент(ов) — осталось 1–2 занятия или окончание в ближайшие 14 дней")
                        .appTypography(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(AppDesign.cardPadding)
            .background(AppColors.visitsOneTimeDebt.opacity(0.08), in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
            .padding(.top, AppDesign.blockSpacing)
        }
    }

    private func load() async {
        let requestedMonth = monthParameter
        let requestedPeriod = periodMonths
        let requestedMonthDate = selectedMonth

        await MainActor.run { isLoading = true; errorMessage = nil }
        defer {
            Task { @MainActor in
                isLoading = false
                hasInitialLoadFinished = true
            }
        }
        do {
            // График и нижний ряд: месяц в календаре + длина окна; метрики «подопечные/абонементы» — за то же окно (см. API `months`).
            let monthSnapshot = try await statisticsService.fetchStatistics(
                coachProfileId: coachProfileId,
                month: requestedMonth,
                periodMonths: requestedPeriod
            )
            try Task.checkCancellation()

            if requestedPeriod > 1 {
                var series: [CoachStatisticsDTO] = []
                for i in 0..<requestedPeriod {
                    guard let monthDate = calendar.date(byAdding: .month, value: -i, to: requestedMonthDate),
                          let startOfMonth = calendar.dateInterval(of: .month, for: monthDate)?.start else { break }
                    let comps = calendar.dateComponents([.year, .month], from: startOfMonth)
                    let ym = String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 1)
                    if ym == requestedMonth {
                        series.append(monthSnapshot)
                    } else {
                        let r = try await statisticsService.fetchStatistics(
                            coachProfileId: coachProfileId,
                            month: ym,
                            periodMonths: 1
                        )
                        series.append(r)
                        try Task.checkCancellation()
                    }
                }
                let ordered = series.reversed()
                await MainActor.run {
                    guard requestedMonth == monthParameter,
                          requestedPeriod == periodMonths,
                          calendar.isDate(requestedMonthDate, equalTo: selectedMonth, toGranularity: .month)
                    else { return }
                    statsForPeriod = Array(ordered)
                    stats = monthSnapshot
                }
            } else {
                await MainActor.run {
                    guard requestedMonth == monthParameter,
                          requestedPeriod == periodMonths,
                          calendar.isDate(requestedMonthDate, equalTo: selectedMonth, toGranularity: .month)
                    else { return }
                    statsForPeriod = [monthSnapshot]
                    stats = monthSnapshot
                }
            }
        } catch is CancellationError {
            // Пользователь сменил месяц/период — не показываем ошибку.
        } catch {
            await MainActor.run {
                guard requestedMonth == monthParameter, requestedPeriod == periodMonths else { return }
                if let msg = AppErrors.userMessageIfNeeded(for: error) {
                    stats = nil
                    statsForPeriod = []
                    errorMessage = msg
                }
            }
        }
    }
}

// MARK: - Выбор месяца (компактный)

private struct MonthPicker: View {
    @Binding var selection: Date
    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: 4) {
            Button {
                if let prev = calendar.date(byAdding: .month, value: -1, to: selection) {
                    selection = prev
                }
            } label: {
                AppTablerIcon("chevron-left")
                    .appTypography(.bodyEmphasis)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
            }
            Text(monthYearString(selection))
                .appTypography(.secondary)
                .foregroundStyle(.primary)
                .frame(minWidth: 140)
            Button {
                guard let next = calendar.date(byAdding: .month, value: 1, to: selection) else { return }
                let now = Date()
                if next <= now || calendar.isDate(next, equalTo: now, toGranularity: .month) {
                    selection = next
                }
            } label: {
                AppTablerIcon("chevron-right")
                    .appTypography(.bodyEmphasis)
                    .foregroundStyle(canSelectNextMonth ? .secondary : .tertiary)
                    .frame(width: 36, height: 36)
            }
            .disabled(!canSelectNextMonth)
        }
    }

    private var canSelectNextMonth: Bool {
        guard let next = calendar.date(byAdding: .month, value: 1, to: selection) else { return false }
        return next <= Date()
    }

    private func monthYearString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .ru
        f.dateFormat = "LLLL yyyy"
        return f.string(from: date).capitalized
    }
}

// MARK: - Карточка одного показателя

private struct StatMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let hintTitle: String
    let hintMessage: String

    @State private var infoButtonFrame: CGRect = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                HStack(spacing: 8) {
                    AppTablerIcon(icon)
                        .appTypography(.body)
                        .foregroundStyle(AppColors.accent)
                    Text(title)
                        .appTypography(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 6)
                infoHintButton
            }
            Text(value)
                .appTypography(.screenTitle)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 112, alignment: .topLeading)
        .padding(AppDesign.cardPadding)
        .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
        .onPreferenceChange(InfoButtonFramePreferenceKey.self) { frame in
            guard frame.width > 0, frame.height > 0 else { return }
            infoButtonFrame = frame
        }
    }

    private var infoHintButton: some View {
        Button {
            guard infoButtonFrame.width > 0, infoButtonFrame.height > 0 else { return }
            InfoHintPopupPresenter.shared.show(
                title: hintTitle,
                message: hintMessage,
                anchorRect: infoButtonFrame,
                preferredSide: .right,
                width: 280
            )
        } label: {
            AppTablerIcon("info.circle")
                .appTypography(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
        }
        .buttonStyle(.plain)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        key: InfoButtonFramePreferenceKey.self,
                        value: proxy.frame(in: .global)
                    )
            }
        )
    }
}

private struct InfoButtonFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next.width > 0, next.height > 0 {
            value = next
        }
    }
}

#Preview {
    NavigationStack {
        CoachStatisticsView(
            coachProfileId: "preview",
            statisticsService: MockCoachStatisticsService()
        )
    }
}
