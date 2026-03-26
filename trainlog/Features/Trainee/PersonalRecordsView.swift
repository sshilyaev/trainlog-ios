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

    private var groupedByDay: [(String, [PersonalRecord])] {
        let calendar = Calendar.current
        let now = Date()
        return Dictionary(grouping: records) { calendar.startOfDay(for: $0.recordDate) }
            .sorted { $0.key > $1.key }
            .map { (dayStart, items) in
                let title = sectionTitle(for: dayStart, calendar: calendar, now: now)
                return (title, items.sorted { $0.recordDate > $1.recordDate })
            }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                heroCard

                if !readOnly {
                    addAchievementButton
                }

                if isLoading {
                    loadingState
                } else if records.isEmpty {
                    emptyState
                } else {
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
                }
            }
            .padding(.horizontal, AppDesign.cardPadding)
            .padding(.top, AppDesign.blockSpacing)
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .background(AdaptiveScreenBackground())
        .navigationTitle("Мои достижения")
        .navigationBarTitleDisplayMode(.inline)
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
            headline: "Личные достижения",
            description: readOnly
            ? "Здесь отображаются личные достижения подопечного."
            : "Фиксируйте достижения по упражнениям и следите за прогрессом в цифрах.",
            accent: AppColors.visitsOneTimeDebt
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
            Text("Пока нет рекордов")
                .font(.headline)
            Text(readOnly ? "Подопечный еще не добавил достижения." : "Добавьте первое достижение: вес, повторения, время, скорость или комбинацию метрик.")
                .foregroundStyle(AppColors.secondaryLabel)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppDesign.cardPadding)
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
        ListActionRow(
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
