import SwiftUI
import Charts

struct PersonalRecordExerciseDetailView: View {
    let exerciseName: String
    let records: [PersonalRecord]
    let readOnly: Bool

    @State private var selectedMetricType: PersonalRecordMetricType?
    @State private var period: DetailPeriod = .days90
    @State private var showAllValues = false

    private var availableMetricTypes: [PersonalRecordMetricType] {
        let set = Set(records.flatMap(\.metrics).map(\.metricType))
        return PersonalRecordMetricType.allCases.filter { set.contains($0) }
    }

    private var effectiveMetricType: PersonalRecordMetricType? {
        if let selectedMetricType { return selectedMetricType }
        return availableMetricTypes.first
    }

    private var filtered: [PersonalRecord] {
        let base = records.sorted { $0.recordDate < $1.recordDate }
        guard period != .all else { return base }
        let start = period.startDate(reference: Date())
        return base.filter { $0.recordDate >= start }
    }

    private var points: [Point] {
        guard let type = effectiveMetricType else { return [] }
        return filtered.compactMap { record in
            guard let m = record.metrics.first(where: { $0.metricType == type }) else { return nil }
            return Point(id: record.id + "-" + type.rawValue, date: record.recordDate, value: m.value)
        }
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

    private var bestValue: Double? {
        guard let type = effectiveMetricType else { return nil }
        return records
            .flatMap(\.metrics)
            .filter { $0.metricType == type }
            .map(\.value)
            .max()
    }

    private var lastValue: Double? {
        guard let type = effectiveMetricType else { return nil }
        return records
            .sorted { $0.recordDate > $1.recordDate }
            .compactMap { r in r.metrics.first(where: { $0.metricType == type })?.value }
            .first
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                hero

                if !availableMetricTypes.isEmpty {
                    chartSection
                }

                historySection
            }
            .padding(.top, AppDesign.blockSpacing)
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .background(AdaptiveScreenBackground())
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedMetricType == nil {
                selectedMetricType = availableMetricTypes.first
            }
        }
    }

    private var hero: some View {
        HeroCard(
            icon: "chart.bar.fill",
            title: exerciseName,
            headline: "Прогресс по упражнению",
            description: "Выберите показатель и посмотрите динамику. PR отмечается как максимальное значение (для времени это может быть не всегда корректно).",
            accent: AppColors.profileAccent
        )
        .padding(.horizontal, AppDesign.cardPadding)
    }

    private var chartSection: some View {
        SettingsCard(title: nil) {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Menu {
                        ForEach(availableMetricTypes) { type in
                            Button {
                                selectedMetricType = type
                            } label: {
                                if effectiveMetricType == type {
                                    Label(type.title, systemImage: "checkmark")
                                } else {
                                    Text(type.title)
                                }
                            }
                        }
                    } label: {
                        chip(title: effectiveMetricType?.title ?? "Показатель", icon: "filter-horizontal")
                            .frame(maxWidth: .infinity)
                    }

                    Menu {
                        ForEach(DetailPeriod.allCases) { p in
                            Button {
                                period = p
                            } label: {
                                if period == p {
                                    Label(p.title, systemImage: "checkmark")
                                } else {
                                    Text(p.title)
                                }
                            }
                        }
                    } label: {
                        chip(title: period.title, icon: "calendar-default")
                            .frame(maxWidth: .infinity)
                    }
                }

                if points.isEmpty {
                    Text("Недостаточно данных для графика.")
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                } else {
                    HStack {
                        Text(effectiveMetricType?.title ?? "График")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.label)
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
                            y: .value("Значение", p.value)
                        )
                        .foregroundStyle(AppColors.profileAccent)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        PointMark(
                            x: .value("Индекс", index),
                            y: .value("Значение", p.value)
                        )
                        .foregroundStyle(AppColors.profileAccent)
                        .symbolSize(showAllValues ? 80 : 40)
                        .annotation(position: .top, spacing: 2) {
                            if showAllValues {
                                Text(p.value.measurementFormatted)
                                    .font(.caption2)
                                    .foregroundStyle(AppColors.label)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
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
                        AxisMarks(values: .automatic(desiredCount: 5)) { _ in
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

                bestAndLastRow
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chip(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            AppTablerIcon(icon)
                .foregroundStyle(AppColors.secondaryLabel)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.label)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(AppColors.separator.opacity(0.25), lineWidth: 0.5)
        )
    }

    // chartCard removed (merged into chartSection)

    private var bestAndLastRow: some View {
        let unit = effectiveMetricType?.defaultUnit ?? ""
        return InfoValueTripleRow(
            items: [
                InfoValueItem(
                    title: "PR",
                    value: bestValue.map { "\($0.measurementFormatted) \(unit)" } ?? "—"
                ),
                InfoValueItem(
                    title: "Последнее",
                    value: lastValue.map { "\($0.measurementFormatted) \(unit)" } ?? "—"
                ),
                InfoValueItem(
                    title: "Записей",
                    value: "\(records.count)"
                ),
            ],
            chipSize: .standard
        )
    }

    private var historySection: some View {
        SettingsCard(title: "История") {
            VStack(spacing: 8) {
                ForEach(records.sorted { $0.recordDate > $1.recordDate }) { record in
                    ListActionRow(
                        verticalPadding: 10,
                        horizontalPadding: 12,
                        cornerRadius: AppDesign.cornerRadius,
                        isInteractive: false
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(record.recordDate.formattedRuShort)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppColors.label)
                                Spacer()
                            }

                            Text(record.metrics.map { "\($0.metricType.title): \($0.value.measurementFormatted) \($0.metricType.defaultUnit ?? $0.unit)" }.joined(separator: "  ·  "))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(AppColors.secondaryLabel)
                                .lineLimit(2)

                            if let notes = record.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundStyle(AppColors.secondaryLabel)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
        }
    }
}

private enum DetailPeriod: String, CaseIterable, Identifiable {
    case days30
    case days90
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .days30: return "30 дней"
        case .days90: return "90 дней"
        case .all: return "Всё время"
        }
    }

    func startDate(reference: Date) -> Date {
        let calendar = Calendar.current
        switch self {
        case .all:
            return .distantPast
        case .days30:
            return calendar.date(byAdding: .day, value: -30, to: reference) ?? reference
        case .days90:
            return calendar.date(byAdding: .day, value: -90, to: reference) ?? reference
        }
    }
}

private struct Point: Identifiable {
    let id: String
    let date: Date
    let value: Double
}

