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
    @State private var showDatePickerSheet = false
    @State private var currentStep: RecordFormStep = .exercise

    var body: some View {
        MainSheet(
            title: record == nil ? "Новый рекорд" : "Редактировать",
            onBack: onCancel,
            trailing: {
                if currentStep == .notes {
                    Button("Сохранить") { Task { await save() } }
                        .disabled(!canSave || isSaving)
                } else {
                    Button("Далее") { goNextStep() }
                        .disabled(!canMoveToNextStep || isSaving)
                }
            },
            content: {
                ScrollView {
                    VStack(spacing: 12) {
                        wizardHeader
                        if currentStep != .exercise {
                            selectedExerciseSummaryCard
                        }
                        currentStepBlock
                    }
                    .padding(.bottom, AppDesign.sectionSpacing)
                }
                .background(AdaptiveScreenBackground())
                .onAppear(perform: hydrate)
                .task { await ensureActivitiesLoaded() }
                .onChange(of: selectedActivitySlug) { _, _ in applyDefaultMetricsIfNeeded() }
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
        )
        .sheet(isPresented: $showActivityPicker) {
            RecordActivityCatalogPickerSheet(
                title: "Выбор упражнения",
                activities: availableActivities,
                selectedSlug: $selectedActivitySlug,
                onClose: { showActivityPicker = false }
            )
            .mainSheetPresentation(.full)
        }
        .sheet(isPresented: $showDatePickerSheet) {
            MainSheet(
                title: "Дата рекорда",
                onBack: { showDatePickerSheet = false },
                trailing: {
                    Button("Готово") { showDatePickerSheet = false }
                        .fontWeight(.regular)
                },
                content: {
                    DatePicker("", selection: $recordDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .environment(\.locale, .ru)
                        .padding()
                }
            )
            .mainSheetPresentation(.calendar)
        }
    }

    private var wizardHeader: some View {
        SettingsCard(title: nil) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button {
                        goPreviousStep()
                    } label: {
                        AppTablerIcon("chevron-left")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(canGoBack ? AppColors.accent : AppColors.tertiaryLabel)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle().fill(canGoBack ? AppColors.accent.opacity(0.12) : AppColors.tertiarySystemFill)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canGoBack)

                    Text("Шаг \(currentStep.index + 1) из \(RecordFormStep.allCases.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                    Spacer()
                }

                HStack(spacing: 6) {
                    ForEach(RecordFormStep.allCases, id: \.rawValue) { step in
                        VStack(spacing: 4) {
                            Capsule()
                                .fill(step.index <= currentStep.index ? AppColors.accent : AppColors.tertiarySystemFill)
                                .frame(height: 6)
                            Text("\(step.index + 1)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(step == currentStep ? AppColors.accent : AppColors.secondaryLabel)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                Text(currentStep.title)
                    .font(.headline)
                    .foregroundStyle(AppColors.label)
                Text(currentStep.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryLabel)
            }
        }
    }

    @ViewBuilder
    private var currentStepBlock: some View {
        switch currentStep {
        case .exercise:
            exerciseBlock
        case .metrics:
            metricsBlock
        case .notes:
            notesBlock
        }
    }

    private var selectedExerciseSummaryCard: some View {
        SettingsCard(title: "Вы выбрали") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(selectedExerciseTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                        .lineLimit(1)
                    Spacer()
                    Text(sourceType == .catalog ? "Каталог" : "Свое")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.secondaryLabel)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.tertiarySystemFill, in: Capsule())
                }

                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        AppTablerIcon("calendar-default")
                            .foregroundStyle(AppColors.secondaryLabel)
                        Text(recordDate.formattedRuShort)
                            .font(.caption)
                            .foregroundStyle(AppColors.secondaryLabel)
                    }

                    if !metrics.isEmpty {
                        Text("·")
                            .foregroundStyle(AppColors.tertiaryLabel)
                        Text(metricsSummary)
                            .font(.caption)
                            .foregroundStyle(AppColors.secondaryLabel)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private var canGoBack: Bool {
        currentStep.index > 0
    }

    private var canMoveToNextStep: Bool {
        switch currentStep {
        case .exercise:
            return hasActivity
        case .metrics:
            return hasMetrics
        case .notes:
            return canSave
        }
    }

    private var hasActivity: Bool {
        sourceType == .catalog
        ? !selectedActivitySlug.isEmpty
        : !customActivityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasMetrics: Bool {
        !metrics.isEmpty && metrics.allSatisfy { $0.value > 0 && !$0.unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var selectedExerciseTitle: String {
        switch sourceType {
        case .catalog:
            return selectedActivityDisplayName
        case .custom:
            let t = customActivityName.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? "Упражнение не выбрано" : t
        }
    }

    private var metricsSummary: String {
        metrics.map { $0.metricType.title }.joined(separator: ", ")
    }

    private func goNextStep() {
        guard canMoveToNextStep else { return }
        if let next = RecordFormStep(rawValue: currentStep.rawValue + 1) {
            currentStep = next
        }
    }

    private func goPreviousStep() {
        guard canGoBack else { return }
        if let prev = RecordFormStep(rawValue: currentStep.rawValue - 1) {
            currentStep = prev
        }
    }

    private var exerciseBlock: some View {
        VStack(spacing: 12) {
        SettingsCard(title: "1. Упражнение") {
            VStack(spacing: 0) {
                Text("Сначала выберите упражнение. Показатели подставятся автоматически, их можно поменять ниже.")
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 10)

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
            }
        }

        SettingsCard(title: "Дополнительно") {
            VStack(alignment: .leading, spacing: 0) {
                Text("Необязательно: уточнение вида нагрузки или подхода.")
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 10)
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
    }

    private var metricsBlock: some View {
        SettingsCard(title: "2. Показатели") {
            VStack(spacing: 0) {
                Text("Укажите, что именно хотите зафиксировать. Для каждого показателя есть значение и единица измерения.")
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 10)

                FormRowDateSelection(
                    title: "Дата",
                    selection: Binding<Date?>(
                        get: { recordDate },
                        set: { if let value = $0 { recordDate = value } }
                    ),
                    allowsClear: false,
                    onTap: { showDatePickerSheet = true }
                )
                FormSectionDivider()

                // Важно: id метрики не должен зависеть от value, иначе будет пересоздаваться view и скрываться клавиатура.
                ForEach(Array(metrics.enumerated()), id: \.offset) { index, _ in
                    metricRow(index: index)
                        .padding(.vertical, 6)
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
        SettingsCard(title: "3. Комментарий") {
            VStack(spacing: 0) {
                Text("Опционально: контекст попытки, техника, самочувствие.")
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 10)
                FormRow(icon: "comment-01", title: "Комментарий") {
                    TextField("Заметка", text: $notes)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .formInputStyle()
                }
            }
        }
    }

    private var canSave: Bool {
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
                TextField("Значение", text: metricValueBinding(index: index))
                    .keyboardType(.decimalPad)
                    .formInputStyle()
                    .frame(maxWidth: .infinity)

                Menu {
                    ForEach(PersonalRecordMetricType.allCases) { type in
                        Button {
                            metrics[index].metricType = type
                            if let defaultUnit = type.defaultUnit {
                                metrics[index].unit = defaultUnit
                            }
                        } label: {
                            if metrics[index].metricType == type {
                                Label(type.title, systemImage: "checkmark")
                            } else {
                                Text(type.title)
                            }
                        }
                    }
                } label: {
                    pickerCell(metrics[index].metricType.title)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                if metrics[index].metricType == .other {
                    TextField("Ед.", text: $metrics[index].unit)
                        .formInputStyle()
                        .frame(maxWidth: .infinity)
                } else {
                    Menu {
                        ForEach(unitOptions(for: metrics[index].metricType), id: \.self) { unit in
                            Button {
                                metrics[index].unit = unit
                            } label: {
                                if metrics[index].unit == unit {
                                    Label(unit, systemImage: "checkmark")
                                } else {
                                    Text(unit)
                                }
                            }
                        }
                    } label: {
                        pickerCell(metrics[index].unit)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }

                Button(role: .destructive) {
                    metrics.remove(at: index)
                    normalizeMetricOrder()
                } label: {
                    AppTablerIcon("delete-dustbin-01")
                        .foregroundStyle(AppColors.destructive)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func pickerCell(_ title: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .lineLimit(1)
            AppTablerIcon("chevron-down")
                .foregroundStyle(AppColors.tertiaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .formInputStyle()
    }

    private func metricValueBinding(index: Int) -> Binding<String> {
        Binding<String>(
            get: {
                let v = metrics[index].value
                return v == 0 ? "" : v.measurementFormatted
            },
            set: { raw in
                let normalized = raw.replacingOccurrences(of: ",", with: ".")
                let filtered = normalized.filter { $0.isNumber || $0 == "." }
                metrics[index].value = Double(filtered) ?? 0
            }
        )
    }

    private func unitOptions(for type: PersonalRecordMetricType) -> [String] {
        switch type {
        case .weight: return ["кг", "lb"]
        case .reps: return ["раз"]
        case .duration: return ["сек", "мин", "ч"]
        case .speed: return ["км/ч", "м/с", "мин/км"]
        case .distance: return ["м", "км"]
        case .other: return []
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

private enum RecordFormStep: Int, CaseIterable {
    case exercise
    case metrics
    case notes

    var index: Int { rawValue }

    var title: String {
        switch self {
        case .exercise: return "Упражнение"
        case .metrics: return "Показатели и дата"
        case .notes: return "Комментарий и сохранение"
        }
    }

    var subtitle: String {
        switch self {
        case .exercise: return "Выберите упражнение или введите своё."
        case .metrics: return "Укажите значения и единицы измерения."
        case .notes: return "Добавьте примечание (необязательно) и сохраните."
        }
    }
}
