//
//  MeasurementChartsView.swift
//  TrainLog
//

import SwiftUI
import Charts

// MARK: - Main charts list (group reused by MeasurementsAndChartsScreen)

enum ChartsMetricGroup: String, CaseIterable {
    case weightHeight = "Вес и рост"
    case upper = "Верх"
    case torso = "Торс"
    case lower = "Низ"

    var types: [MeasurementType] {
        switch self {
        case .weightHeight: return [.weight, .height]
        case .upper: return [.neck, .shoulders, .leftBiceps, .rightBiceps]
        case .torso: return [.waist, .belly, .chest]
        case .lower: return [.leftThigh, .rightThigh, .hips, .buttocks, .leftCalf, .rightCalf]
        }
    }
}

/// Сетка тайлов графиков без hero и без внешнего `ScrollView` — для встраивания (экран «Прогресс»).
struct MeasurementChartsGridContent: View {
    let measurements: [Measurement]
    let goals: [Goal]
    /// Для экрана «Замеры и графики»: только заголовок группы, без подзаголовка и иконки справа.
    var compactSectionChrome: Bool = false

    @State private var displayMode: ChartDisplayMode = .line
    @State private var chartColorIndex: Int = 0
    @State private var chartPeriod: ChartPeriod = .all

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        ForEach(ChartsMetricGroup.allCases, id: \.rawValue) { group in
            let availableTypes = group.types.filter(hasData(for:))
            if !availableTypes.isEmpty {
                ContentCard(
                    title: group.rawValue,
                    description: compactSectionChrome ? "" : chartGroupSubtitle(group),
                    trailing: compactSectionChrome ? nil : .icon("chart.xyaxis.line")
                ) {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(availableTypes, id: \.id) { type in
                            NavigationLink {
                                ChartDetailView(
                                    type: type,
                                    measurements: measurements,
                                    goals: goals.filter { $0.measurementType == type.rawValue },
                                    displayMode: $displayMode,
                                    chartColorIndex: $chartColorIndex,
                                    chartPeriod: $chartPeriod
                                )
                            } label: {
                                chartMetricTile(for: type)
                            }
                            .buttonStyle(PressableButtonStyle(cornerRadius: 12))
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    private func chartGroupSubtitle(_ group: ChartsMetricGroup) -> String {
        switch group {
        case .weightHeight: return "Вес и рост по истории замеров."
        case .upper: return "Шея, плечи и бицепсы."
        case .torso: return "Талия, живот и грудь."
        case .lower: return "Бёдра, ягодицы, бедра и икры."
        }
    }

    private func hasData(for type: MeasurementType) -> Bool {
        measurements.contains { $0.value(for: type) != nil }
    }

    private func chartMetricTile(for type: MeasurementType) -> some View {
        let latestValue = measurements
            .compactMap { m -> (Double, Date)? in
                guard let v = m.value(for: type) else { return nil }
                return (v, m.date)
            }
            .max(by: { $0.1 < $1.1 })
        return GridActionTile {
            Text(type.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.label)
                .lineLimit(1)
            Text(latestValue.map { "\($0.0.measurementFormatted) \(type.unit)" } ?? "Нет данных")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppColors.label)
                .lineLimit(1)
        } trailing: {
            AppTablerIcon("chevron-right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppColors.tertiaryLabel)
        }
    }
}

struct MeasurementChartsView: View {
    let profile: Profile
    let measurements: [Measurement]
    let goals: [Goal]
    /// Когда false, вид не оборачивается в NavigationStack (для push из ClientCardView у тренера).
    var embedInNavigationStack: Bool = true

    private var content: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroCard
                    .padding(.bottom, AppDesign.blockSpacing)

                MeasurementChartsGridContent(measurements: measurements, goals: goals)
            }
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .background(AppColors.systemGroupedBackground)
        .navigationTitle("Графики")
        .navigationBarTitleDisplayMode(.inline)
    }

    var body: some View {
        if embedInNavigationStack {
            NavigationStack {
                content
            }
        } else {
            content
        }
    }

    private var heroCard: some View {
        HeroCard(
            icon: "chart.bar.fill",
            title: "Графики",
            headline: "Динамика замеров",
            description: "Откройте нужную метрику, чтобы увидеть динамику и сверить ее с целями.",
            accent: AppColors.profileAccent
        )
        .padding(.horizontal, AppDesign.cardPadding)
        .padding(.top, AppDesign.blockSpacing)
    }
}

// MARK: - Меню «Вид и цвет» (только на экране детали графика)

/// Период отображения графика (относительно последней даты в данных или свои даты).
enum ChartPeriod: String, CaseIterable, Hashable {
    case week = "Неделя"
    case month = "Месяц"
    case year = "Год"
    case all = "Всё время"
    case custom = "Свои даты"

    var days: Int? {
        switch self {
        case .week: return 7
        case .month: return 30
        case .year: return 365
        case .all, .custom: return nil
        }
    }
}

enum ChartDisplayMode: String, CaseIterable, Hashable {
    case line = "Линия"
}

struct ChartDetailView: View {
    let type: MeasurementType
    let measurements: [Measurement]
    let goals: [Goal]

    @Binding var displayMode: ChartDisplayMode
    @Binding var chartColorIndex: Int
    @Binding var chartPeriod: ChartPeriod
    @Environment(\.dismiss) private var dismiss

    @State private var customDateFrom: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customDateTo: Date = Date()
    @State private var showAllValues = false

    private var chartColor: Color { Self.chartColorOptions[chartColorIndex] }

    static let chartColorOptions: [Color] = [
        AppColors.accent,
        AppColors.genderMale,
        AppColors.visitsOneTimeDebt,
        AppColors.profileAccent,
        AppColors.visitsOneTimePaid,
        AppColors.genderFemale
    ]

    private var allPoints: [ChartPoint] {
        measurements
            .compactMap { m -> ChartPoint? in
                guard let v = m.value(for: type) else { return nil }
                return ChartPoint(id: m.id, date: m.date, value: v)
            }
            .sorted { $0.date < $1.date }
    }

    private var points: [ChartPoint] {
        guard !allPoints.isEmpty else { return [] }
        if chartPeriod == .custom {
            return allPoints.filter { $0.date >= customDateFrom && $0.date <= customDateTo }
        }
        guard let lastDate = allPoints.last?.date else { return [] }
        guard let days = chartPeriod.days else { return allPoints }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: lastDate)!
        return allPoints.filter { $0.date >= start }
    }

    private var chartYDomain: ClosedRange<Double> {
        guard !points.isEmpty else { return 0...1 }
        let minV = points.map(\.value).min()!
        let maxV = points.map(\.value).max()!
        if minV == maxV {
            let pad = max(abs(minV) * 0.1, 1.0)
            return (minV - pad)...(maxV + pad)
        }
        let span = max(maxV - minV, 1.0)
        return (minV - span * 0.05)...(maxV + span * 0.1)
    }

    private var chartXDomain: ClosedRange<Double> {
        guard !points.isEmpty else { return -0.5...0.5 }
        return -0.5...(Double(points.count) - 0.5)
    }

    private func shortDateLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .ru
        f.dateFormat = "d MMM"
        return f.string(from: date)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if allPoints.isEmpty {
                    emptyState
                } else {
                    periodBlock
                    if points.isEmpty {
                        noDataForPeriodBlock
                    } else {
                        chartBlock
                    }
                    goalsBlock
                }
            }
            .padding(.horizontal, AppDesign.cardPadding)
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .background(AdaptiveScreenBackground())
        .navigationTitle(type.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackToolbarButton(action: { dismiss() })
            }
        }
        .onAppear {
            chartPeriod = .all
            displayMode = .line
        }
        .environment(\.locale, .ru)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            AppTablerIcon("grid-dashboard-circle")
                .appIcon(.s44)
                .foregroundStyle(.secondary)
            Text("Нет данных")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Добавьте замеры с метрикой «\(type.displayName)», чтобы построить график.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppDesign.cardPadding)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var periodBlock: some View {
        VStack(spacing: 10) {
            Picker("Период", selection: $chartPeriod) {
                Text("Неделя").tag(ChartPeriod.week)
                Text("Месяц").tag(ChartPeriod.month)
                Text("Год").tag(ChartPeriod.year)
                Text("Всё").tag(ChartPeriod.all)
                Text("Свои").tag(ChartPeriod.custom)
            }
            .pickerStyle(.segmented)
            if chartPeriod == .custom {
                DatePicker("От", selection: $customDateFrom, displayedComponents: .date)
                DatePicker("До", selection: $customDateTo, displayedComponents: .date)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
        .padding(.top, AppDesign.blockSpacing)
    }

    private var noDataForPeriodBlock: some View {
        VStack(spacing: 8) {
            AppTablerIcon("calendar-filled")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Нет данных за период")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            Text("Выберите другой период или добавьте замеры за эти даты.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
        .padding(.top, AppDesign.blockSpacing)
    }

    private var chartBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(type.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    showAllValues.toggle()
                } label: {
                    Text(showAllValues ? "Скрыть значения" : "Показать значения")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            Chart(Array(points.enumerated()), id: \.element.id) { index, p in
                LineMark(
                    x: .value("Индекс", index),
                    y: .value(type.displayName, p.value)
                )
                .foregroundStyle(chartColor)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                PointMark(
                    x: .value("Индекс", index),
                    y: .value(type.displayName, p.value)
                )
                .foregroundStyle(chartColor)
                .symbolSize(showAllValues ? 80 : 40)
                .annotation(position: .top, spacing: 2) {
                    if showAllValues {
                        Text(p.value.measurementFormatted)
                            .font(.caption2)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .chartXScale(domain: chartXDomain)
            .chartYScale(domain: chartYDomain)
            .chartXAxis {
                AxisMarks(values: .stride(by: 1)) { value in
                    AxisValueLabel {
                        if let i = value.as(Int.self), i >= 0, i < points.count {
                            Text(shortDateLabel(points[i].date))
                                .font(.caption2)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                        .foregroundStyle(Color.primary.opacity(0.06))
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisValueLabel()
                        .foregroundStyle(.secondary)
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                        .foregroundStyle(Color.primary.opacity(0.06))
                }
            }
            .chartPlotStyle { plotArea in
                plotArea
                    .padding(.leading, 24)
                    .padding(.trailing, 8)
                    .padding(.top, 8)
                    .padding(.bottom, AppDesign.sectionSpacing)
            }
            .frame(height: 220)
            .clipped()
        }
        .padding(AppDesign.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
        .padding(.top, AppDesign.blockSpacing)
    }

    private var goalsBlock: some View {
        SettingsCard(title: "Цели") {
            if goals.isEmpty {
                Text("Нет целей по этой метрике")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(goals.sorted { $0.targetDate < $1.targetDate }.enumerated()), id: \.element.id) { index, goal in
                        ActionBlockRow(
                            icon: "map-pin",
                            title: "\(goal.targetValue.measurementFormatted) \(type.unit)",
                            value: goal.targetDate.formatted(.dateTime.day().month().year())
                        )
                        if index != goals.count - 1 {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
            }
        }
        .padding(.top, AppDesign.blockSpacing)
    }
}

private struct ChartPoint: Identifiable {
    let id: String
    let date: Date
    let value: Double
}

#Preview {
    MeasurementChartsView(
        profile: Profile(id: "1", userId: "u1", type: .trainee, name: "Мой дневник"),
        measurements: [],
        goals: []
    )
}