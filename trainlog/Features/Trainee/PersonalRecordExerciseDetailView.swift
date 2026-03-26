import SwiftUI
import Charts

struct PersonalRecordExerciseDetailView: View {
    let exerciseName: String
    let records: [PersonalRecord]
    let readOnly: Bool

    @State private var selectedMetricType: PersonalRecordMetricType?
    @State private var period: DetailPeriod = .days90

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
                    metricAndPeriodRow
                    chartCard
                    bestAndLastRow
                }

                historySection
            }
            .padding(.horizontal, AppDesign.cardPadding)
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
    }

    private var metricAndPeriodRow: some View {
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
            }

            Spacer()
        }
        .padding(.top, 2)
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

    private var chartCard: some View {
        SettingsCard(title: nil) {
            VStack(alignment: .leading, spacing: 10) {
                if points.isEmpty {
                    Text("Недостаточно данных для графика.")
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                } else {
                    Chart(points) { p in
                        LineMark(
                            x: .value("Дата", p.date),
                            y: .value("Значение", p.value)
                        )
                        .foregroundStyle(AppColors.profileAccent)

                        PointMark(
                            x: .value("Дата", p.date),
                            y: .value("Значение", p.value)
                        )
                        .foregroundStyle(AppColors.profileAccent)
                    }
                    .frame(height: 180)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisGridLine().foregroundStyle(AppColors.separator.opacity(0.25))
                            AxisTick().foregroundStyle(AppColors.separator.opacity(0.35))
                            AxisValueLabel()
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisGridLine().foregroundStyle(AppColors.separator.opacity(0.25))
                            AxisTick().foregroundStyle(AppColors.separator.opacity(0.35))
                            AxisValueLabel()
                        }
                    }
                }
            }
        }
    }

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

