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
                            Picker("Упражнение", selection: $selectedActivitySlug) {
                                Text("Выберите").tag("")
                                ForEach(availableActivities) { activity in
                                    Text(activity.name).tag(activity.slug)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .trailing)
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
