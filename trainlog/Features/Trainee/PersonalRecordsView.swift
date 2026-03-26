import SwiftUI

struct PersonalRecordsView: View {
    let profile: Profile
    let service: PersonalRecordServiceProtocol
    let readOnly: Bool

    @State private var records: [PersonalRecord] = []
    @State private var activities: [RecordActivity] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var editingRecord: PersonalRecord?
    @State private var showCreateSheet = false
    @State private var showHelpSheet = false
    @State private var mode: RecordsMode = .feed
    @State private var query: String = ""
    @State private var metricFilter: PersonalRecordMetricType? = nil
    @State private var period: RecordsPeriod = .all

    private var groupedByDay: [(String, [PersonalRecord])] {
        let calendar = Calendar.current
        let now = Date()
        return Dictionary(grouping: filteredRecords) { calendar.startOfDay(for: $0.recordDate) }
            .sorted { $0.key > $1.key }
            .map { (dayStart, items) in
                let title = sectionTitle(for: dayStart, calendar: calendar, now: now)
                return (title, items.sorted { $0.recordDate > $1.recordDate })
            }
    }

    private var filteredRecords: [PersonalRecord] {
        var base = records

        if period != .all {
            let start = period.startDate(reference: Date())
            base = base.filter { $0.recordDate >= start }
        }

        if let metricFilter {
            base = base.filter { record in
                record.metrics.contains(where: { $0.metricType == metricFilter })
            }
        }

        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            base = base.filter { record in
                record.activityName.localizedCaseInsensitiveContains(q)
                || (record.activityType?.localizedCaseInsensitiveContains(q) ?? false)
                || (record.notes?.localizedCaseInsensitiveContains(q) ?? false)
            }
        }

        return base.sorted { $0.recordDate > $1.recordDate }
    }

    private var exercisesSummary: [ExerciseSummary] {
        let grouped = Dictionary(grouping: filteredRecords, by: { $0.activityName.trimmingCharacters(in: .whitespacesAndNewlines) })
        return grouped
            .map { name, items in
                ExerciseSummary(
                    name: name.isEmpty ? "Без названия" : name,
                    count: items.count,
                    lastDate: items.max(by: { $0.recordDate < $1.recordDate })?.recordDate ?? Date.distantPast
                )
            }
            .sorted { a, b in
                if a.lastDate != b.lastDate { return a.lastDate > b.lastDate }
                return a.name < b.name
            }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                heroCard

                modePicker
                filtersBar

                if !readOnly {
                    addAchievementButton
                }

                if isLoading {
                    loadingState
                } else if filteredRecords.isEmpty {
                    emptyState
                } else {
                    summaryCard
                    switch mode {
                    case .feed:
                        ForEach(Array(groupedByDay.enumerated()), id: \.offset) { _, pair in
                            let (sectionTitle, items) = pair
                            VStack(alignment: .leading, spacing: 8) {
                                Text(sectionTitle)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 2)
                                ForEach(items) { record in
                                    recordCard(record)
                                }
                            }
                        }

                    case .exercises:
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(exercisesSummary) { item in
                                exerciseRow(item)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppDesign.cardPadding)
            .padding(.top, AppDesign.blockSpacing)
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .background(AdaptiveScreenBackground())
        .navigationTitle("Мои достижения")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Упражнение, тип или заметка")
        .task {
            await loadData()
        }
        .refreshable {
            await loadRecords()
        }
        .sheet(isPresented: $showCreateSheet) {
            AddEditPersonalRecordSheet(
                profileId: profile.id,
                service: service,
                activities: activities,
                record: nil,
                onSaved: {
                    showCreateSheet = false
                    Task { await loadRecords() }
                },
                onCancel: { showCreateSheet = false }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .sheetPresentationStyle()
        }
        .sheet(item: $editingRecord) { record in
            AddEditPersonalRecordSheet(
                profileId: profile.id,
                service: service,
                activities: activities,
                record: record,
                onSaved: {
                    editingRecord = nil
                    Task { await loadRecords() }
                },
                onCancel: { editingRecord = nil }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .sheetPresentationStyle()
        }
        .sheet(isPresented: $showHelpSheet) {
            PersonalRecordsHelpSheet(
                onAddTapped: readOnly ? nil : { showHelpSheet = false; showCreateSheet = true },
                onClose: { showHelpSheet = false }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .sheetPresentationStyle()
        }
        .appConfirmationDialog(
            title: "Ошибка",
            message: errorMessage ?? "Произошла ошибка.",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ),
            confirmTitle: "OK",
            onConfirm: { errorMessage = nil },
            onCancel: { errorMessage = nil }
        )
        .overlay {
            if isSaving {
                LoadingOverlayView(message: "Сохраняю")
            }
        }
        .allowsHitTesting(!isSaving)
    }

    private var heroCard: some View {
        HeroCard(
            icon: "award-medal",
            title: "Мои достижения",
            headline: "Ваши рекорды и прогресс",
            description: readOnly
            ? "Здесь отображаются личные достижения подопечного."
            : "Записывайте лучшие результаты по упражнениям и возвращайтесь к ним, чтобы видеть прогресс.",
            accent: AppColors.visitsOneTimeDebt
        )
    }

    private var summaryCard: some View {
        let total = filteredRecords.count
        let calendar = Calendar.current
        let last30Start = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let prs30 = filteredRecords.filter { $0.recordDate >= last30Start && isPersonalBest($0) }.count
        let top = exercisesSummary.prefix(3)

        return SettingsCard(title: nil) {
            VStack(alignment: .leading, spacing: 12) {
                InfoValueTripleRow(
                    items: [
                        InfoValueItem(title: "Записей", value: "\(total)"),
                        InfoValueItem(title: "PR за 30 дней", value: "\(prs30)"),
                        InfoValueItem(title: "Упражнений", value: "\(exercisesSummary.count)"),
                    ],
                    chipSize: .standard
                )

                if !top.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Чаще всего")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.secondaryLabel)
                        ForEach(Array(top.enumerated()), id: \.offset) { _, item in
                            HStack {
                                Text(item.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppColors.label)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(item.count)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppColors.secondaryLabel)
                            }
                        }
                    }
                }
            }
        }
    }

    private var modePicker: some View {
        Picker("Режим", selection: $mode) {
            Text("Лента").tag(RecordsMode.feed)
            Text("Упражнения").tag(RecordsMode.exercises)
        }
        .pickerStyle(.segmented)
    }

    private var filtersBar: some View {
        HStack(spacing: 10) {
            Menu {
                Button {
                    metricFilter = nil
                } label: {
                    if metricFilter == nil {
                        Label("Все показатели", systemImage: "checkmark")
                    } else {
                        Text("Все показатели")
                    }
                }
                ForEach(PersonalRecordMetricType.allCases) { type in
                    Button {
                        metricFilter = type
                    } label: {
                        if metricFilter == type {
                            Label(type.title, systemImage: "checkmark")
                        } else {
                            Text(type.title)
                        }
                    }
                }
            } label: {
                filterChip(title: metricFilter?.title ?? "Показатель", icon: "filter-horizontal")
            }

            Menu {
                ForEach(RecordsPeriod.allCases) { p in
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
                filterChip(title: period.title, icon: "calendar-default")
            }

            Spacer()

            Button(action: { showHelpSheet = true }) {
                HStack(spacing: 6) {
                    AppTablerIcon("info-circle")
                    Text("Что это")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColors.secondaryLabel)
        }
        .padding(.top, 2)
    }

    private func filterChip(title: String, icon: String) -> some View {
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

    private var loadingState: some View {
        VStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: AppDesign.cornerRadius)
                    .fill(AppColors.tertiarySystemFill)
                    .frame(height: 112)
                    .redacted(reason: .placeholder)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            AppTablerIcon("award-medal")
                .appIcon(.s44)
                .foregroundStyle(AppColors.accent.opacity(0.85))
            Text(readOnly ? "Пока нет достижений" : "Создайте первое достижение")
                .font(.headline)
            Text(
                readOnly
                ? "Подопечный ещё не добавил достижения."
                : "Например: «Жим лёжа — 100 кг × 5» или «Бег — 5 км за 22:10»."
            )
                .foregroundStyle(AppColors.secondaryLabel)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppDesign.cardPadding)

            if !readOnly {
                VStack(spacing: 10) {
                    Button(action: { showCreateSheet = true }) {
                        HStack(spacing: 10) {
                            AppTablerIcon("plus-circle")
                                .font(.title3)
                            Text("Добавить достижение")
                                .font(.headline.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.accent, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
                    }
                    .buttonStyle(PressableButtonStyle())

                    Button(action: { showHelpSheet = true }) {
                        Text("Зачем это и как пользоваться")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
                    }
                    .buttonStyle(PressableButtonStyle())
                }
                .padding(.top, 4)
                .padding(.horizontal, 4)
            } else {
                Button(action: { showHelpSheet = true }) {
                    Text("Что это такое")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.top, 4)
                .padding(.horizontal, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private var addAchievementButton: some View {
        Button(action: { showCreateSheet = true }) {
            HStack(spacing: 10) {
                AppTablerIcon("plus-circle")
                    .font(.title3)
                Text("Добавить достижение")
                    .font(.headline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppColors.accent, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.top, 2)
    }

    private func recordCard(_ record: PersonalRecord) -> some View {
        let isPr = isPersonalBest(record)
        return ListActionRow(
            verticalPadding: 10,
            horizontalPadding: 12,
            cornerRadius: AppDesign.cornerRadius,
            isInteractive: false
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(record.activityName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                    Spacer()
                    if isPr {
                        Text("PR")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppColors.destructive)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.destructive.opacity(0.12), in: Capsule())
                    }
                }

                metricLine(record.metrics)

                if let activityType = record.activityType, !activityType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(activityType)
                        .font(.caption2)
                        .foregroundStyle(AppColors.tertiaryLabel)
                }

                if let notes = record.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .lineLimit(2)
                }
            }
        } trailing: {
            if !readOnly {
                TiniActionButton(style: .plain) {
                    Button {
                        editingRecord = record
                    } label: {
                        Label("Редактировать", appIcon: "pencil-edit")
                    }
                    Button(role: .destructive) {
                        Task { await delete(record) }
                    } label: {
                        Label("Удалить", appIcon: "delete-dustbin-01")
                    }
                }
            }
        }
    }

    private func isPersonalBest(_ record: PersonalRecord) -> Bool {
        let activity = record.activityName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !activity.isEmpty else { return false }
        let related = records.filter { $0.activityName.trimmingCharacters(in: .whitespacesAndNewlines) == activity }
        guard !related.isEmpty else { return false }

        for metric in record.metrics {
            let bestValue = related
                .flatMap(\.metrics)
                .filter { $0.metricType == metric.metricType }
                .map(\.value)
                .max()
            guard let bestValue else { continue }
            if metric.value == bestValue {
                // PR: засчитываем только если это самая свежая запись с этим значением (чтобы не красить старые дубли).
                let latestDateForBest = related
                    .filter { r in
                        r.metrics.contains(where: { $0.metricType == metric.metricType && $0.value == bestValue })
                    }
                    .map(\.recordDate)
                    .max()
                if latestDateForBest == record.recordDate {
                    return true
                }
            }
        }
        return false
    }

    private func exerciseRow(_ item: ExerciseSummary) -> some View {
        NavigationLink {
            PersonalRecordExerciseDetailView(
                exerciseName: item.name,
                records: filteredRecords.filter { $0.activityName.trimmingCharacters(in: .whitespacesAndNewlines) == item.name },
                readOnly: readOnly
            )
        } label: {
            ListActionRow(
                verticalPadding: 10,
                horizontalPadding: 12,
                cornerRadius: AppDesign.cornerRadius,
                isInteractive: true
            ) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                    Text("Записей: \(item.count) · Последнее: \(item.lastDate.formattedRuShort)")
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                }
            } trailing: {
                AppTablerIcon("chevron-right")
                    .foregroundStyle(AppColors.tertiaryLabel)
            }
        }
        .buttonStyle(.plain)
    }

    private func metricLine(_ metrics: [PersonalRecordMetric]) -> some View {
        let summary = metrics
            .map { metric in
                "\(metric.metricType.title): \(metric.value.measurementFormatted) \(localizedUnit(for: metric))"
            }
            .joined(separator: "  ·  ")

        return Text(summary)
            .font(.caption.weight(.medium))
            .foregroundStyle(AppColors.secondaryLabel)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionTitle(for dayStart: Date, calendar: Calendar, now: Date) -> String {
        if calendar.isDateInToday(dayStart) { return "Сегодня" }
        if calendar.isDateInYesterday(dayStart) { return "Вчера" }
        return dayStart.formattedRuList
    }

    private func loadData() async {
        await loadActivities()
        await loadRecords()
        await MainActor.run { isLoading = false }
    }

    private func loadActivities() async {
        do {
            let list = try await service.fetchActivities()
            await MainActor.run { activities = list }
        } catch {
            await MainActor.run {
                activities = []
            }
        }
    }

    private func loadRecords() async {
        do {
            let list = try await service.fetchRecords(profileId: profile.id)
            await MainActor.run { records = list }
        } catch {
            await MainActor.run {
                if let msg = AppErrors.userMessageIfNeeded(for: error) { errorMessage = msg }
            }
        }
    }

    private func delete(_ record: PersonalRecord) async {
        await MainActor.run { isSaving = true }
        defer { Task { @MainActor in isSaving = false } }
        do {
            try await service.deleteRecord(profileId: profile.id, recordId: record.id)
            await loadRecords()
        } catch {
            await MainActor.run {
                if let msg = AppErrors.userMessageIfNeeded(for: error) { errorMessage = msg }
            }
        }
    }

    private func localizedUnit(for metric: PersonalRecordMetric) -> String {
        switch metric.metricType {
        case .weight:
            return "кг"
        case .reps:
            return "раз"
        case .duration:
            return "сек"
        case .speed:
            return "км/ч"
        case .distance:
            return "м"
        case .other:
            return metric.unit
        }
    }
}

private struct PersonalRecordsHelpSheet: View {
    let onAddTapped: (() -> Void)?
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    HeroCard(
                        icon: "award-medal",
                        title: "Мои достижения",
                        headline: "Зачем это нужно",
                        description: "Это личные рекорды и лучшие результаты по упражнениям — чтобы видеть прогресс в цифрах, сравнивать себя с собой и не забывать удачные попытки.",
                        accent: AppColors.visitsOneTimeDebt
                    )

                    SettingsCard(title: "Примеры") {
                        VStack(alignment: .leading, spacing: 10) {
                            exampleRow(title: "Жим лёжа", subtitle: "Вес: 100 кг · Повторения: 5 раз")
                            exampleRow(title: "Бег", subtitle: "Дистанция: 5 км · Время: 22:10")
                            exampleRow(title: "Подтягивания", subtitle: "Повторения: 15 раз")
                        }
                    }

                    SettingsCard(title: "Советы") {
                        VStack(alignment: .leading, spacing: 10) {
                            tipLine("Делайте отдельные записи под разные упражнения.")
                            tipLine("Добавляйте 1–2 показателя: вес + повторы, время + дистанция и т.д.")
                            tipLine("Пишите комментарий, если важно: техника, условия, самочувствие.")
                        }
                    }
                }
                .padding(.horizontal, AppDesign.cardPadding)
                .padding(.top, AppDesign.blockSpacing)
                .padding(.bottom, AppDesign.sectionSpacing)
            }
            .background(AdaptiveScreenBackground())
            .navigationTitle("О достижениях")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") { onClose() }
                }
                if let onAddTapped {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Добавить") { onAddTapped() }
                    }
                }
            }
        }
    }

    private func exampleRow(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.label)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }

    private func tipLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(AppColors.secondaryLabel)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppColors.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum RecordsMode: String, CaseIterable {
    case feed
    case exercises
}

private enum RecordsPeriod: String, CaseIterable, Identifiable {
    case all
    case days30
    case days90

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Всё время"
        case .days30: return "30 дней"
        case .days90: return "90 дней"
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

private struct ExerciseSummary: Identifiable {
    var id: String { name }
    let name: String
    let count: Int
    let lastDate: Date
}
