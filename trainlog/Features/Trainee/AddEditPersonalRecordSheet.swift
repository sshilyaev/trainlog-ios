import SwiftUI

struct AddEditPersonalRecordSheet: View {
    let profileId: String
    let service: PersonalRecordServiceProtocol
    let activities: [RecordActivity]
    let record: PersonalRecord?
    let onSaved: () -> Void
    let onCancel: () -> Void

    @State private var sourceType: PersonalRecordSourceType = .catalog
    @State private var selectedActivitySlug: String = ""
    @State private var customActivityName = ""
    @State private var activityType = ""
    @State private var recordDate = Date()
    @State private var notes = ""
    @State private var metrics: [PersonalRecordMetric] = []
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var catalogActivities: [RecordActivity] = []
    @State private var isLoadingCatalog = false
    @State private var showActivityPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    exerciseBlock
                    metricsBlock
                    notesBlock
                }
            .padding(.bottom, AppDesign.sectionSpacing)
            }
            .background(AdaptiveScreenBackground())
            .navigationTitle(record == nil ? "Новый рекорд" : "Редактировать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { onCancel() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") {
                        Task { await save() }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .onAppear(perform: hydrate)
            .task {
                await ensureActivitiesLoaded()
            }
            .onChange(of: selectedActivitySlug) { _, _ in
                applyDefaultMetricsIfNeeded()
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
        .sheet(isPresented: $showActivityPicker) {
            RecordActivityPickerSheet(
                title: "Выбор упражнения",
                activities: availableActivities,
                selectedSlug: $selectedActivitySlug,
                onClose: { showActivityPicker = false }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .sheetPresentationStyle()
        }
    }

    private var exerciseBlock: some View {
        SettingsCard(title: nil) {
            VStack(spacing: 0) {
                FormRow(icon: "award-medal", title: "Источник") {
                    Picker("Источник", selection: $sourceType) {
                        Text("Каталог").tag(PersonalRecordSourceType.catalog)
                        Text("Свое").tag(PersonalRecordSourceType.custom)
                    }
                    .pickerStyle(.segmented)
                }
                FormSectionDivider()

                if sourceType == .catalog {
                    FormRow(icon: "list-details", title: "Упражнение") {
                        if isLoadingCatalog {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.85)
                                Text("Загружаю…")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.secondaryLabel)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        } else {
                            Button {
                                showActivityPicker = true
                            } label: {
                                HStack(spacing: 8) {
                                    Text(selectedActivityDisplayName)
                                        .foregroundStyle(selectedActivitySlug.isEmpty ? AppColors.tertiaryLabel : AppColors.label)
                                        .lineLimit(1)
                                    AppTablerIcon("chevron-right")
                                        .foregroundStyle(AppColors.tertiaryLabel)
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    FormRowTextField(
                        icon: "pencil-edit-02",
                        title: "Упражнение",
                        placeholder: "Название упражнения",
                        text: $customActivityName,
                        autocapitalization: .sentences
                    )
                }
                FormSectionDivider()

                FormRowTextField(
                    icon: "tag-01",
                    title: "Тип",
                    placeholder: "Необязательно",
                    text: $activityType,
                    autocapitalization: .sentences
                )
            }
        }
    }

    private var metricsBlock: some View {
        SettingsCard(title: nil) {
            VStack(spacing: 0) {
                FormRow(icon: "calendar-default", title: "Дата") {
                    DatePicker("Дата", selection: $recordDate, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .environment(\.locale, .ru)
                }
                FormSectionDivider()

                ForEach(Array(metrics.enumerated()), id: \.element.id) { index, _ in
                    metricRow(index: index)
                    if index != metrics.count - 1 {
                        FormSectionDivider()
                    }
                }

                Button {
                    metrics.append(
                        PersonalRecordMetric(
                            rawId: nil,
                            metricType: .weight,
                            value: 0,
                            unit: PersonalRecordMetricType.weight.defaultUnit ?? "",
                            displayOrder: metrics.count
                        )
                    )
                } label: {
                    Label("Добавить показатель", appIcon: "plus-circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var notesBlock: some View {
        SettingsCard(title: nil) {
            FormRow(icon: "comment-01", title: "Комментарий") {
                TextField("Заметка", text: $notes)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .formInputStyle()
            }
        }
    }

    private var canSave: Bool {
        let hasActivity = sourceType == .catalog
            ? !selectedActivitySlug.isEmpty
            : !customActivityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasMetrics = !metrics.isEmpty && metrics.allSatisfy { $0.value > 0 && !$0.unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return hasActivity && hasMetrics
    }

    private var availableActivities: [RecordActivity] {
        catalogActivities.isEmpty ? activities : catalogActivities
    }

    private var selectedActivityDisplayName: String {
        guard !selectedActivitySlug.isEmpty else { return "Выберите" }
        return availableActivities.first(where: { $0.slug == selectedActivitySlug })?.name ?? "Выберите"
    }

    @ViewBuilder
    private func metricRow(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("Показатель")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 100, alignment: .leading)

                Picker("Показатель", selection: $metrics[index].metricType) {
                    ForEach(PersonalRecordMetricType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                .onChange(of: metrics[index].metricType) { _, newValue in
                    if let defaultUnit = newValue.defaultUnit {
                        metrics[index].unit = defaultUnit
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                Button(role: .destructive) {
                    metrics.remove(at: index)
                    normalizeMetricOrder()
                } label: {
                    AppTablerIcon("delete-dustbin-01")
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                TextField(
                    "Значение",
                    value: $metrics[index].value,
                    format: .number.precision(.fractionLength(0...2))
                )
                .keyboardType(.decimalPad)
                .formInputStyle()

                TextField("Ед.", text: $metrics[index].unit)
                    .formInputStyle()
            }
            .padding(.leading, 110)
        }
    }

    private func hydrate() {
        if let record {
            sourceType = record.sourceType
            customActivityName = record.sourceType == .custom ? record.activityName : ""
            if record.sourceType == .catalog {
                selectedActivitySlug = availableActivities.first(where: { $0.name == record.activityName })?.slug ?? ""
            }
            activityType = record.activityType ?? ""
            recordDate = record.recordDate
            notes = record.notes ?? ""
            metrics = record.metrics.sorted { $0.displayOrder < $1.displayOrder }
        } else if metrics.isEmpty {
            metrics = [
                PersonalRecordMetric(
                    rawId: nil,
                    metricType: .weight,
                    value: 0,
                    unit: PersonalRecordMetricType.weight.defaultUnit ?? "",
                    displayOrder: 0
                ),
            ]
        }
    }

    private func ensureActivitiesLoaded() async {
        if !catalogActivities.isEmpty || !activities.isEmpty {
            if catalogActivities.isEmpty { catalogActivities = activities }
            return
        }
        await MainActor.run { isLoadingCatalog = true }
        defer { Task { @MainActor in isLoadingCatalog = false } }
        do {
            let list = try await service.fetchActivities()
            await MainActor.run {
                catalogActivities = list
                if selectedActivitySlug.isEmpty, let first = list.first {
                    selectedActivitySlug = first.slug
                }
            }
        } catch {
            await MainActor.run {
                catalogActivities = []
            }
        }
    }

    private func applyDefaultMetricsIfNeeded() {
        guard record == nil else { return }
        guard sourceType == .catalog else { return }
        guard !selectedActivitySlug.isEmpty else { return }
        guard let activity = availableActivities.first(where: { $0.slug == selectedActivitySlug }) else { return }
        guard !activity.defaultMetrics.isEmpty else { return }

        // Не затираем метрики, если пользователь уже явно добавил/изменил их.
        let looksLikeFreshDefault = metrics.count == 1
            && metrics.first?.metricType == .weight
            && (metrics.first?.value ?? 0) == 0
            && (metrics.first?.unit ?? "") == (PersonalRecordMetricType.weight.defaultUnit ?? "")
        guard looksLikeFreshDefault || metrics.isEmpty else { return }

        metrics = activity.defaultMetrics.enumerated().map { index, type in
            PersonalRecordMetric(
                rawId: nil,
                metricType: type,
                value: 0,
                unit: type.defaultUnit ?? "",
                displayOrder: index
            )
        }
    }

    private func normalizeMetricOrder() {
        for index in metrics.indices {
            metrics[index].displayOrder = index
        }
    }

    private func save() async {
        await MainActor.run { isSaving = true }
        defer { Task { @MainActor in isSaving = false } }
        normalizeMetricOrder()
        do {
            _ = try await service.saveRecord(
                profileId: profileId,
                id: record?.id,
                recordDate: recordDate,
                sourceType: sourceType,
                activitySlug: sourceType == .catalog ? selectedActivitySlug : nil,
                activityName: sourceType == .custom ? customActivityName.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                activityType: activityType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : activityType.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
                metrics: metrics
            )
            await MainActor.run { onSaved() }
        } catch {
            await MainActor.run {
                if let msg = AppErrors.userMessageIfNeeded(for: error) { errorMessage = msg }
            }
        }
    }
}

private struct RecordActivityPickerSheet: View {
    let title: String
    let activities: [RecordActivity]
    @Binding var selectedSlug: String
    let onClose: () -> Void

    @AppStorage("records.activities.favorites") private var favoritesRaw = ""
    @AppStorage("records.activities.recent") private var recentRaw = ""
    @State private var query = ""

    private var favorites: Set<String> { Set(Self.csv(favoritesRaw)) }
    private var recent: [String] { Self.csv(recentRaw) }

    private var activitiesBySlug: [String: RecordActivity] {
        Dictionary(uniqueKeysWithValues: activities.map { ($0.slug, $0) })
    }

    private var filteredAll: [RecordActivity] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return activities }
        return activities.filter { a in
            a.name.localizedCaseInsensitiveContains(q)
            || (a.activityType?.localizedCaseInsensitiveContains(q) ?? false)
        }
    }

    private var recentActivities: [RecordActivity] {
        recent.compactMap { activitiesBySlug[$0] }.filter { filteredAll.contains($0) }
    }

    private var favoriteActivities: [RecordActivity] {
        filteredAll.filter { favorites.contains($0.slug) }.sorted { $0.displayOrder < $1.displayOrder }
    }

    var body: some View {
        NavigationStack {
            List {
                if !query.isEmpty, filteredAll.isEmpty {
                    ContentUnavailableView(
                        "Ничего не найдено",
                        image: "tabler-outline-circle-x",
                        description: Text("Попробуйте другой запрос.")
                    )
                }

                if query.isEmpty, !recentActivities.isEmpty {
                    Section("Недавние") {
                        ForEach(recentActivities) { activity in
                            row(activity)
                        }
                    }
                }

                if !favoriteActivities.isEmpty {
                    Section("Избранные") {
                        ForEach(favoriteActivities) { activity in
                            row(activity)
                        }
                    }
                }

                Section(query.isEmpty ? "Каталог" : "Результаты") {
                    ForEach(filteredAll) { activity in
                        row(activity)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Поиск упражнения")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") { onClose() }
                }
            }
        }
    }

    private func row(_ activity: RecordActivity) -> some View {
        let isFavorite = favorites.contains(activity.slug)
        return Button {
            select(activity)
            onClose()
        } label: {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(activity.name)
                        .foregroundStyle(AppColors.label)
                    if let t = activity.activityType, !t.isEmpty {
                        Text(t)
                            .font(.caption)
                            .foregroundStyle(AppColors.secondaryLabel)
                    }
                }
                Spacer()
                Button {
                    toggleFavorite(activity.slug)
                } label: {
                    AppTablerIcon(isFavorite ? "star.circle.fill" : "star.circle")
                        .foregroundStyle(isFavorite ? AppColors.accent : AppColors.tertiaryLabel)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isFavorite ? "Убрать из избранного" : "Добавить в избранное")

                if selectedSlug == activity.slug {
                    Image(systemName: "checkmark")
                        .foregroundStyle(AppColors.accent)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func select(_ activity: RecordActivity) {
        selectedSlug = activity.slug
        var nextRecent = recent.filter { $0 != activity.slug }
        nextRecent.insert(activity.slug, at: 0)
        nextRecent = Array(nextRecent.prefix(12))
        recentRaw = nextRecent.joined(separator: ",")
    }

    private func toggleFavorite(_ slug: String) {
        var set = favorites
        if set.contains(slug) { set.remove(slug) } else { set.insert(slug) }
        favoritesRaw = Array(set).sorted().joined(separator: ",")
    }

    private static func csv(_ raw: String) -> [String] {
        raw
            .split(separator: ",")
            .map { String($0) }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}
