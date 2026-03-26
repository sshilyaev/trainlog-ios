//
//  MeasurementsListView.swift
//  TrainLog
//

import SwiftUI

struct MeasurementsListView: View {
    let profile: Profile
    let measurements: [Measurement]
    /// Только просмотр: без добавления, гайда, деталей и удаления.
    var readOnly: Bool = false
    /// Вложенный в существующий `NavigationStack` (экран «Замеры и графики»).
    var embedsNavigationStack: Bool = true
    var onAddMeasurement: () -> Void = {}
    var onDeleteMeasurement: (Measurement) -> Void = { _ in }

    @State private var showMeasurementGuideSheet = false

    private var sorted: [Measurement] {
        measurements.sorted { $0.date > $1.date }
    }

    private var lastMeasurement: Measurement? {
        sorted.first
    }

    private var groupedByDay: [(String, [Measurement])] {
        let calendar = Calendar.current
        let now = Date()
        return Dictionary(grouping: sorted) { calendar.startOfDay(for: $0.date) }
            .sorted { $0.key > $1.key }
            .map { (dayStart, items) in
                let title = sectionTitle(for: dayStart, calendar: calendar, now: now)
                return (title, items.sorted { $0.date > $1.date })
            }
    }

    /// Заголовки секций для режима «только просмотр»: без дублирования даты в карточках — дата только здесь, читабельно.
    private var readOnlyGroupedByDay: [(String, [Measurement])] {
        let calendar = Calendar.current
        return Dictionary(grouping: sorted) { calendar.startOfDay(for: $0.date) }
            .sorted { $0.key > $1.key }
            .map { (dayStart, items) in
                let title = readOnlySectionTitle(for: dayStart, calendar: calendar)
                return (title, items.sorted { $0.date > $1.date })
            }
    }

    private func readOnlySectionTitle(for dayStart: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(dayStart) { return "Сегодня" }
        if calendar.isDateInYesterday(dayStart) { return "Вчера" }
        return dayStart.formattedRuMedium
    }

    private func sectionTitle(for dayStart: Date, calendar: Calendar, now: Date) -> String {
        if calendar.isDateInToday(dayStart) { return "Сегодня" }
        if calendar.isDateInYesterday(dayStart) { return "Вчера" }
        return dayStart.formattedRuList
    }

    var body: some View {
        Group {
            if embedsNavigationStack {
                NavigationStack { listContent }
            } else {
                listContent
            }
        }
        .sheet(isPresented: $showMeasurementGuideSheet) {
            NavigationStack {
                MeasurementGuideView()
                    .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .sheetPresentationStyle()
        }
    }

    private var listContent: some View {
        ScrollView {
            Group {
                if measurements.isEmpty {
                    if readOnly {
                        readOnlyEmptyState
                    } else {
                        emptyState
                    }
                } else if readOnly {
                    readOnlyGroupedList
                } else {
                    interactiveContent
                }
            }
            .padding(.horizontal, readOnly ? AppDesign.cardPadding : 0)
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .background(AdaptiveScreenBackground())
        .navigationTitle(readOnly ? "История замеров" : "Замеры")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var interactiveContent: some View {
        VStack(spacing: 0) {
            lastMeasurementCard
            measurementGuideButton
            addButton
            historySection
        }
    }

    private var readOnlyGroupedList: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(readOnlyGroupedByDay.enumerated()), id: \.offset) { _, pair in
                let (sectionTitle, items) = pair
                VStack(alignment: .leading, spacing: 10) {
                    Text(sectionTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(spacing: 10) {
                        ForEach(items) { m in
                            readOnlyMeasurementCard(m, showTime: readOnlyShouldShowTime(m, in: items))
                        }
                    }
                }
            }
        }
        .padding(.top, AppDesign.blockSpacing)
    }

    private var readOnlyEmptyState: some View {
        VStack(spacing: 16) {
            AppTablerIcon("pencil-scale")
                .appIcon(.s44)
                .foregroundStyle(AppColors.accent.opacity(0.85))
            Text("Пока нет замеров")
                .font(.headline)
            Text("Добавляйте замеры через вкладку «Прогресс», чтобы здесь появилась история.")
                .font(.subheadline)
                .foregroundStyle(AppColors.secondaryLabel)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.top, AppDesign.blockSpacing)
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)
            AppTablerIcon("pencil-scale")
                .appIcon(.s44)
                .foregroundStyle(AppColors.accent.opacity(0.8))
                .emptyStateIconPulse()
            Text("Пока нет замеров")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Добавьте первый замер — так вы сможете отслеживать прогресс и строить графики.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            measurementGuideButton
            Button(action: onAddMeasurement) {
                Label("Добавить замер", appIcon: "plus-circle")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(AppColors.accent, in: Capsule())
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.top, 8)
            .emptyStateCtaAppear(delay: 0.25)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }

    private var lastMeasurementCard: some View {
        Group {
            if let last = lastMeasurement {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        AppTablerIcon("award-medal")
                            .font(.title3)
                            .foregroundStyle(AppColors.accent)
                        Text("Последний замер")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(last.date.formattedRuDayMonth)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                    measurementMetricsRow(measurement: last, maxItems: 5, expandedLines: false)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppDesign.cardPadding)
                .background(
                    LinearGradient(
                        colors: [
                            AppColors.accent.opacity(0.12),
                            AppColors.accent.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppDesign.cornerRadius)
                        .stroke(AppColors.accent.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal, AppDesign.cardPadding)
                .padding(.top, AppDesign.blockSpacing)
            }
        }
    }

    private var addButton: some View {
        Button(action: onAddMeasurement) {
            HStack(spacing: 10) {
                AppTablerIcon("plus-circle")
                    .font(.title3)
                Text("Добавить замер")
                    .font(.headline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppColors.accent, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.horizontal, AppDesign.cardPadding)
        .padding(.top, measurements.isEmpty ? 0 : AppDesign.blockSpacing)
    }

    private var measurementGuideButton: some View {
        Button {
            showMeasurementGuideSheet = true
        } label: {
            WideActionButtonToOneColumn(
                icon: "sparkle-ai-01",
                title: "Как правильно делать замеры",
                subtitle: "",
                iconColor: AppColors.secondaryLabel,
                chevronColor: AppColors.tertiaryLabel
            )
        }
        .buttonStyle(PressableButtonStyle(cornerRadius: AppDesign.cornerRadius))
        .padding(.horizontal, AppDesign.cardPadding)
        .padding(.top, AppDesign.blockSpacing)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("История")
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.horizontal, AppDesign.cardPadding)
                .padding(.top, 24)
            ForEach(Array(groupedByDay.enumerated()), id: \.offset) { _, pair in
                let (sectionTitle, items) = pair
                VStack(alignment: .leading, spacing: 8) {
                    Text(sectionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, AppDesign.cardPadding)
                    ForEach(items) { m in
                        interactiveMeasurementCard(m)
                    }
                }
            }
        }
    }

    /// Время не показываем, если в день один замер или время ровно 00:00 (часто только дата без времени суток).
    private func readOnlyShouldShowTime(_ m: Measurement, in dayItems: [Measurement]) -> Bool {
        guard dayItems.count > 1 else { return false }
        let cal = Calendar.current
        let h = cal.component(.hour, from: m.date)
        let min = cal.component(.minute, from: m.date)
        return !(h == 0 && min == 0)
    }

    private func readOnlyMeasurementCard(_ m: Measurement, showTime: Bool) -> some View {
        ListActionRow(
            verticalPadding: 12,
            horizontalPadding: 12,
            cornerRadius: AppDesign.cornerRadius,
            isInteractive: false
        ) {
            VStack(alignment: .leading, spacing: 10) {
                if showTime {
                    Text(m.date.formattedRuTime)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.secondaryLabel)
                }
                readOnlyMetricsTable(m)
                if let note = m.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(AppColors.tertiaryLabel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// Пары «название — значение», вес и рост первыми, дальше по порядку enum.
    private func readOnlyMetricPairs(for m: Measurement) -> [(String, String)] {
        var rows: [(String, String)] = []
        let ordered: [MeasurementType] = [.weight, .height] + MeasurementType.allCases.filter { $0 != .weight && $0 != .height }
        for type in ordered {
            guard let v = m.value(for: type) else { continue }
            rows.append((type.displayName, "\(v.measurementFormatted) \(type.unit)"))
        }
        return rows
    }

    private static let readOnlyMetricsGridColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    private func readOnlyMetricsTable(_ m: Measurement) -> some View {
        let pairs = readOnlyMetricPairs(for: m)
        return LazyVGrid(columns: Self.readOnlyMetricsGridColumns, alignment: .leading, spacing: 10) {
            ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                VStack(alignment: .leading, spacing: 3) {
                    Text(pair.0)
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(pair.1)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func interactiveMeasurementCard(_ m: Measurement) -> some View {
        NavigationLink {
            MeasurementDetailView(
                measurement: m,
                onDelete: { onDeleteMeasurement(m) }
            )
        } label: {
            ListActionRow {
                measurementMetricsRow(measurement: m, maxItems: 4, expandedLines: false)
            } trailing: {
                AppTablerIcon("chevron-right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppDesign.cardPadding)
        .padding(.bottom, 6)
        .contextMenu {
            Button(role: .destructive) {
                onDeleteMeasurement(m)
            } label: {
                Label("Удалить", appIcon: "delete-dustbin-01")
            }
        }
    }

    private func measurementMetricsRow(measurement: Measurement, maxItems: Int, expandedLines: Bool) -> some View {
        let items = MeasurementType.allCases.compactMap { type -> String? in
            guard let v = measurement.value(for: type) else { return nil }
            return "\(type.displayName): \(v.measurementFormatted) \(type.unit)"
        }
        let shown = Array(items.prefix(maxItems))
        let text = shown.joined(separator: "  ·  ")
        return Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .lineLimit(expandedLines ? 12 : 2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MeasurementDetailView: View {
    let measurement: Measurement
    var onDelete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    private var dateFormatted: String {
        let f = DateFormatter()
        f.dateStyle = .long
        f.locale = .ru
        return f.string(from: measurement.date)
    }

    private var valueRows: [(String, String)] {
        MeasurementType.allCases.compactMap { type in
            guard let value = measurement.value(for: type) else { return nil }
            return (type.displayName, "\(value.measurementFormatted) \(type.unit)")
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    if !valueRows.isEmpty {
                        ForEach(Array(valueRows.enumerated()), id: \.offset) { index, row in
                            ActionBlockRow(icon: "pencil-scale", title: row.0, value: row.1)
                            if index != valueRows.count - 1 {
                                Divider()
                                    .padding(.leading, 52)
                            }
                        }
                    }
                }
                .actionBlockStyle()

                if valueRows.isEmpty {
                    EmptyStateView(
                        icon: "pencil-scale",
                        title: "Нет измерений",
                        description: "В этом замере нет заполненных значений"
                    )
                    .padding(.vertical, AppDesign.sectionSpacing)
                }

            }
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .background(AdaptiveScreenBackground())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(dateFormatted)
                    .font(.headline)
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    BackToolbarButton(action: { dismiss() })
                }
            }
            if onDelete != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        onDelete?()
                        dismiss()
                    } label: {
                        Label("Удалить", appIcon: "delete-dustbin-01")
                    }
                }
            }
        }
    }
}

#Preview {
    MeasurementsListView(
        profile: Profile(id: "1", userId: "u1", type: .trainee, name: "Мой дневник"),
        measurements: [],
        readOnly: true
    )
}
