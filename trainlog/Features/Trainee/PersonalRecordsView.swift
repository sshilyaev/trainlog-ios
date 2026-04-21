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
    @State private var showSearch = false

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

    private var hasAnyRecords: Bool {
        !records.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                heroCard

                if hasAnyRecords {
                    modePicker
                }

                if hasAnyRecords, !readOnly {
                    addAchievementButton
                }

                if isLoading {
                    loadingState
                } else if filteredRecords.isEmpty {
                    emptyState
                } else {
                    switch mode {
                    case .feed:
                        ForEach(Array(groupedByDay.enumerated()), id: \.offset) { _, pair in
                            let (sectionTitle, items) = pair
                            VStack(alignment: .leading, spacing: 8) {
                                Text(sectionTitle)
                                    .appTypography(.bodyEmphasis)
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
        .toolbar {
            if hasAnyRecords {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSearch = true
                    } label: {
                        AppTablerIcon("magnifyingglass")
                            .foregroundStyle(AppColors.accent)
                    }
                }
            }
        }
        .searchable(
            text: $query,
            isPresented: $showSearch,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Упражнение, тип или заметка"
        )
        .onChange(of: hasAnyRecords) { _, hasData in
            if !hasData {
                showSearch = false
                query = ""
            }
        }
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
            .mainSheetPresentation(.full)
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
            .mainSheetPresentation(.full)
        }
        .sheet(isPresented: $showHelpSheet) {
            RecordsGuideSheet(
                title: "Мои достижения",
                headline: "Зачем это нужно",
                description: "Это личные рекорды и лучшие результаты по упражнениям — чтобы видеть прогресс в цифрах, сравнивать себя с собой и не забывать удачные попытки.",
                examples: [
                    RecordsGuideExample(title: "Жим лёжа", subtitle: "Вес: 100 кг · Повторения: 5 раз"),
                    RecordsGuideExample(title: "Бег", subtitle: "Дистанция: 5 км · Время: 22:10"),
                    RecordsGuideExample(title: "Подтягивания", subtitle: "Повторения: 15 раз"),
                ],
                tips: [
                    "Делайте отдельные записи под разные упражнения.",
                    "Добавляйте 1–2 показателя: вес + повторы, время + дистанция и т.д.",
                    "Пишите комментарий, если важно: техника, условия, самочувствие.",
                ],
                onPrimaryAction: readOnly ? nil : { showHelpSheet = false; showCreateSheet = true },
                primaryActionTitle: "Добавить",
                onClose: { showHelpSheet = false }
            )
            .mainSheetPresentation(.full)
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
        {
            InfoValueTripleRow(
                items: [
                    InfoValueItem(title: "Записей", value: "\(filteredRecords.count)"),
                    InfoValueItem(title: "PR", value: "\(filteredRecords.filter(isPersonalBest).count)"),
                    InfoValueItem(title: "Упражнений", value: "\(exercisesSummary.count)"),
                ],
                chipSize: .standard
            )
        }
        .overlay(alignment: .topTrailing) {
            Button {
                showHelpSheet = true
            } label: {
                AppTablerIcon("info-circle")
                    .foregroundStyle(AppColors.secondaryLabel)
                    .padding(8)
                    .background(AppColors.secondarySystemGroupedBackground.opacity(0.9), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(10)
        }
    }

    private var modePicker: some View {
        Picker("Режим", selection: $mode) {
            Text("Лента").tag(RecordsMode.feed)
            Text("Упражнения").tag(RecordsMode.exercises)
        }
        .pickerStyle(.segmented)
    }

    private func filterChip(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            AppTablerIcon(icon)
                .foregroundStyle(AppColors.secondaryLabel)
            Text(title)
                .appTypography(.bodyEmphasis)
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
                .appIcon(.s56)
                .foregroundStyle(AppColors.accent.opacity(0.85))
            Text(readOnly ? "Пока нет достижений" : "Создайте первое достижение")
                .appTypography(.sectionTitle)
            Text(
                readOnly
                ? "Подопечный ещё не добавил достижения."
                : "Например: «Жим лёжа — 100 кг × 5» или «Бег — 5 км за 22:10»."
            )
                .foregroundStyle(AppColors.secondaryLabel)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppDesign.cardPadding)

            if !readOnly {
                Button(action: { showCreateSheet = true }) {
                    HStack(spacing: 10) {
                        AppTablerIcon("plus-circle")
                            .appTypography(.numericMetric)
                        Text("Добавить достижение")
                            .appTypography(.sectionTitle)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColors.accent, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
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
                    .appTypography(.numericMetric)
                Text("Добавить достижение")
                    .appTypography(.sectionTitle)
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
                        .appTypography(.bodyEmphasis)
                        .foregroundStyle(AppColors.label)
                    Spacer()
                    if isPr {
                        Text("PR")
                            .appTypography(.caption)
                            .foregroundStyle(AppColors.destructive)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.destructive.opacity(0.12), in: Capsule())
                    }
                }

                metricLine(record.metrics)

                if let activityType = record.activityType, !activityType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(activityType)
                        .appTypography(.caption)
                        .foregroundStyle(AppColors.tertiaryLabel)
                }

                if let notes = record.notes, !notes.isEmpty {
                    Text(notes)
                        .appTypography(.caption)
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
                        .appTypography(.bodyEmphasis)
                        .foregroundStyle(AppColors.label)
                    Text("Записей: \(item.count) · Последнее: \(item.lastDate.formattedRuShort)")
                        .appTypography(.caption)
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
            .appTypography(.caption)
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

private enum RecordsMode: String, CaseIterable {
    case feed
    case exercises
}

private struct ExerciseSummary: Identifiable {
    var id: String { name }
    let name: String
    let count: Int
    let lastDate: Date
}
