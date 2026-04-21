import SwiftUI
import Foundation

struct DynamicCalculatorView: View {
    let calculatorId: String
    let calculatorsService: CalculatorsServiceProtocol
    let profileId: String?

    @State private var isLoading = true
    @State private var definition: CalculatorDefinition?

    @State private var inputStrings: [String: String] = [:]
    @State private var isCalculating = false

    @State private var result: CalculatorCalculateResult?

    @State private var showHowCalculated = false
    @State private var currentStepIndex = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if isLoading {
                    LoadingBlockView(message: "Загружаю калькулятор…")
                } else if let definition {
                    headerBlock(definition: definition)
                    formBlock(definition: definition)
                    resultBlock(definition: definition)
                    actionsInFlow
                } else {
                    ContentUnavailableView(
                        "Калькулятор не найден",
                        image: "flag",
                        description: Text("Попробуйте позже.")
                    )
                    .padding(.top, 32)
                }
            }
        }
        .dismissKeyboardOnTap()
        .background(AdaptiveScreenBackground())
        .navigationTitle(definition?.title ?? "Калькулятор")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isCalculating {
                LoadingOverlayView(message: "Считаю…")
            }
        }
        .allowsHitTesting(!isCalculating)
        .task { await loadDefinition() }
    }

    @ViewBuilder
    private func headerBlock(definition: CalculatorDefinition) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                AppTablerIcon("troubleshoot")
                    .appIcon(.s20)
                    .foregroundStyle(AppColors.accent)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 4) {
                    Text("О калькуляторе")
                        .appTypography(.bodyEmphasis)
                        .foregroundStyle(AppColors.label)

                    Text(definition.description)
                        .appTypography(.secondary)
                        .foregroundStyle(AppColors.label)
                        .multilineTextAlignment(.leading)
                }
            }

            if let help = definition.helpText, !help.isEmpty {
                Text(help)
                    .appTypography(.caption)
                    .foregroundStyle(AppColors.label)
                    .multilineTextAlignment(.leading)
            }

            Text("Результаты ориентировочные — используйте как подсказку для настройки привычек.")
                .appTypography(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppDesign.cardPadding)
        .background(
            LinearGradient(
                colors: [AppColors.accent.opacity(0.17), AppColors.accent.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            Rectangle()
                .fill(AppColors.accent.opacity(0.28))
                .frame(width: 4),
            alignment: .leading
        )
        .padding(.horizontal, AppDesign.cardPadding)
        .padding(.top, AppDesign.blockSpacing)
    }

    @ViewBuilder
    private func formBlock(definition: CalculatorDefinition) -> some View {
        if let flow = definition.flow, flow.mode == .multistep, !flow.steps.isEmpty {
            multiStepFormBlock(definition: definition, flow: flow)
        } else {
            singleStepFormBlock(definition: definition)
        }
    }

    @ViewBuilder
    private func singleStepFormBlock(definition: CalculatorDefinition) -> some View {
        VStack(spacing: 0) {
            ForEach(definition.uiGroups, id: \.title) { group in
                SettingsCard(title: group.title) {
                    inputGrid(
                        keys: group.inputKeys.filter { isVisible(key: $0, definition: definition) },
                        definition: definition
                    )
                }
            }
        }

        // Поля, которые не попали в uiGroups — показываем в отдельной секции.
        let grouped = Set(definition.uiGroups.flatMap(\.inputKeys))
        let ungroupedKeys = definition.inputs.map(\.key).filter { !grouped.contains($0) }
        if !ungroupedKeys.isEmpty {
            SettingsCard(title: "Дополнительно") {
                inputGrid(
                    keys: ungroupedKeys.filter { isVisible(key: $0, definition: definition) },
                    definition: definition
                )
            }
        }
    }

    @ViewBuilder
    private func multiStepFormBlock(definition: CalculatorDefinition, flow: CalculatorFlow) -> some View {
        let clampedIndex = min(max(0, currentStepIndex), max(0, flow.steps.count - 1))
        let step = flow.steps[clampedIndex]

        SettingsCard(title: "Шаги") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            currentStepIndex = max(0, clampedIndex - 1)
                        }
                    } label: {
                        AppTablerIcon("chevron-left")
                            .appTypography(.bodyEmphasis)
                            .foregroundStyle(clampedIndex > 0 ? AppColors.accent : AppColors.tertiaryLabel)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(clampedIndex > 0 ? AppColors.accent.opacity(0.12) : AppColors.tertiarySystemFill)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(clampedIndex == 0)

                    Text("Шаг \(clampedIndex + 1) из \(flow.steps.count)")
                        .appTypography(.bodyEmphasis)
                        .foregroundStyle(AppColors.label)

                    Spacer()
                }

                HStack(spacing: 6) {
                    ForEach(Array(flow.steps.enumerated()), id: \.offset) { idx, item in
                        VStack(spacing: 4) {
                            Capsule()
                                .fill(idx <= clampedIndex ? AppColors.accent : AppColors.tertiarySystemFill)
                                .frame(height: 6)
                            Text("\(idx + 1)")
                                .appTypography(.caption)
                                .foregroundStyle(idx == clampedIndex ? AppColors.accent : AppColors.secondaryLabel)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Шаг \(idx + 1): \(item.title)")
                    }
                }

                Text(step.title)
                    .appTypography(.sectionTitle)
                    .foregroundStyle(AppColors.label)

                if let subtitle = step.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .appTypography(.secondary)
                        .foregroundStyle(AppColors.secondaryLabel)
                }
            }
        }

        SettingsCard(title: "Вводные данные") {
            inputGrid(
                keys: step.inputKeys.filter { isVisible(key: $0, definition: definition) },
                definition: definition
            )
        }
    }

    @ViewBuilder
    private func resultBlock(definition: CalculatorDefinition) -> some View {
        if let result {
            VStack(spacing: AppDesign.blockSpacing) {
                if let primary = definition.outputs.first,
                   let primaryValue = result.outputs[primary.key] {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Итог")
                            .appTypography(.caption)
                            .foregroundStyle(AppColors.secondaryLabel)
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(formattedValue(primaryValue, decimals: primary.decimals))
                                .appTypography(.screenTitle)
                                .foregroundStyle(AppColors.label)
                            if let unit = primary.unit, !unit.isEmpty {
                                Text(unit)
                                    .appTypography(.sectionTitle)
                                    .foregroundStyle(AppColors.secondaryLabel)
                            }
                        }
                        Text(primary.title)
                            .appTypography(.caption)
                            .foregroundStyle(AppColors.secondaryLabel)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppDesign.cardPadding)
                    .background(
                        LinearGradient(
                            colors: [AppColors.accent.opacity(0.16), AppColors.accent.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDesign.cornerRadius)
                            .stroke(AppColors.accent.opacity(0.28), lineWidth: 1)
                    )
                    .padding(.horizontal, AppDesign.cardPadding)
                    .padding(.top, AppDesign.blockSpacing)
                }

                if definition.outputs.count > 1 {
                    SettingsCard(title: "Результат") {
                        VStack(alignment: .leading, spacing: AppDesign.rowSpacing) {
                            ForEach(definition.outputs) { out in
                                if let value = result.outputs[out.key] {
                                    HStack {
                                        Text(out.title)
                                            .foregroundStyle(AppColors.secondaryLabel)
                                        Spacer()
                                        Text(formattedValue(value, decimals: out.decimals))
                                            .appTypography(.bodyEmphasis)
                                        if let unit = out.unit, !unit.isEmpty {
                                            Text(unit)
                                                .appTypography(.caption)
                                                .foregroundStyle(AppColors.secondaryLabel)
                                                .padding(.leading, 4)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                if let label = result.interpretationLabel {
                    SettingsCard(title: "Интерпретация") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(label)
                                .appTypography(.bodyEmphasis)
                            if let subtitle = result.interpretationSubtitle, !subtitle.isEmpty {
                                Text(subtitle)
                                    .appTypography(.caption)
                                    .foregroundStyle(AppColors.secondaryLabel)
                            }
                        }
                    }
                }

                visualizationBlock(definition: definition, result: result)

                howCalculatedBlock(definition: definition)

                if definition.outputs.count > 1,
                   let summary = result.summary, !summary.isEmpty {
                    SettingsCard {
                        Text(summary)
                            .appTypography(.secondary)
                            .foregroundStyle(AppColors.secondaryLabel)
                    }
                }

                if !result.resultDescriptions.isEmpty {
                    SettingsCard(title: "Описание результата") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(result.resultDescriptions.enumerated()), id: \.offset) { _, item in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .appTypography(.bodyEmphasis)
                                        .foregroundStyle(AppColors.label)
                                    Text(item.description)
                                        .appTypography(.caption)
                                        .foregroundStyle(AppColors.secondaryLabel)
                                }
                            }
                        }
                    }
                }

                if !result.recommendations.isEmpty {
                    SettingsCard(title: "Рекомендации") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(result.recommendations.enumerated()), id: \.offset) { _, item in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .appTypography(.bodyEmphasis)
                                        .foregroundStyle(AppColors.label)
                                    Text(item.description)
                                        .appTypography(.caption)
                                        .foregroundStyle(AppColors.secondaryLabel)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.top, AppDesign.blockSpacing)
        }
    }

    @ViewBuilder
    private func visualizationBlock(definition: CalculatorDefinition, result: CalculatorCalculateResult) -> some View {
        if let interpretation = definition.interpretation,
           let value = result.outputs[interpretation.targetOutputKey],
           !interpretation.ranges.isEmpty {
            SettingsCard(title: "Шкала") {
                VStack(alignment: .leading, spacing: 10) {
                    InterpretationScaleBarView(ranges: interpretation.ranges, value: value)
                    Text("Значение на шкале: \(formattedValue(value, decimals: nil))")
                        .appTypography(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                }
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func howCalculatedBlock(definition: CalculatorDefinition) -> some View {
        let expressions: [(title: String, expr: String)] = definition.outputs.compactMap { out in
            guard let expr = out.expressionValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !expr.isEmpty
            else { return nil }
            return (title: out.title, expr: expr)
        }

        if expressions.isEmpty {
            EmptyView()
        } else {
            SettingsCard(title: "Как считается") {
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        withAnimation(.snappy) { showHowCalculated.toggle() }
                    } label: {
                        HStack {
                            Text(showHowCalculated ? "Свернуть" : "Показать формулы")
                                .appTypography(.secondary)
                                .foregroundStyle(.secondary)
                            Spacer()
                            AppTablerIcon(showHowCalculated ? "chevron.up" : "chevron.down")
                                .foregroundStyle(AppColors.secondaryLabel)
                        }
                    }
                    .buttonStyle(.plain)

                    if showHowCalculated {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(expressions, id: \.title) { item in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .appTypography(.caption)
                                        .foregroundStyle(AppColors.secondaryLabel)
                                    Text(item.expr)
                                        .font(.footnote.monospaced())
                                        .foregroundStyle(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private struct InterpretationScaleBarView: View {
        let ranges: [CalculatorInterpretationRange]
        let value: Double

        var body: some View {
            GeometryReader { geo in
                let barMin = minBoundary()
                let barMax = maxBoundary()
                let total = max(0.000001, barMax - barMin)
                let clampValue = min(max(value, barMin), barMax)
                let indicatorX = ((clampValue - barMin) / total) * geo.size.width

                let selectedIndex = selectedRangeIndex(barMin: barMin, barMax: barMax)

                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        ForEach(Array(ranges.enumerated()), id: \.offset) { index, r in
                            let segStart = r.min ?? barMin
                            let segEnd = r.max ?? barMax
                            let segWidth = max(0, (segEnd - segStart) / total) * geo.size.width

                            segmentView(
                                index: index,
                                isSelected: index == selectedIndex,
                                label: r.label
                            )
                            .frame(width: segWidth, height: 10)
                        }
                    }
                    Rectangle()
                        .fill(AppColors.white.opacity(0.9))
                        .frame(width: 2, height: 18)
                        .offset(x: indicatorX - 1)
                        .overlay(
                            Rectangle()
                                .fill(AppColors.accent)
                                .frame(width: 2, height: 18)
                                .offset(x: 0)
                        )
                }
            }
            .frame(height: 18)
        }

        private func minBoundary() -> Double {
            let mins = ranges.compactMap(\.min)
            if let m = mins.min() { return m }
            return max(0, value * 0.8)
        }

        private func maxBoundary() -> Double {
            let maxs = ranges.compactMap(\.max)
            if let m = maxs.max() { return m }
            return value * 1.2
        }

        private func selectedRangeIndex(barMin: Double, barMax: Double) -> Int? {
            for (idx, r) in ranges.enumerated() {
                let start = r.min ?? barMin
                let end = r.max ?? barMax
                if value >= start && value <= end { return idx }
            }
            return nil
        }

        private func segmentView(index: Int, isSelected: Bool, label: String) -> some View {
            let base: Color = {
                if label.lowercased().contains("норм") {
                    return AppColors.accent.opacity(0.22)
                } else if label.lowercased().contains("ожир") || label.lowercased().contains("высок") {
                    return AppColors.destructive.opacity(0.18)
                } else {
                    return AppColors.tertiarySystemFill.opacity(0.9)
                }
            }()

            if isSelected {
                return baseWithSelection(base: base, selected: true)
            } else {
                return baseWithSelection(base: base, selected: false)
            }
        }

        private func baseWithSelection(base: Color, selected: Bool) -> some View {
            if selected {
                return AppColors.accent.opacity(0.95)
            } else {
                return base.opacity(1.0)
            }
        }
    }

    private var actionsInFlow: some View {
        VStack(spacing: 12) {
            if let definition,
               let flow = definition.flow,
               flow.mode == .multistep,
               !flow.steps.isEmpty {
                multiStepActions(definition: definition, flow: flow)
            } else {
                Button {
                    if let definition {
                        Task { await calculate(definition: definition) }
                    }
                } label: {
                    Text("Рассчитать")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(
                    isCalculating ||
                    definition == nil ||
                    (definition.map { !canCalculate(definition: $0) } ?? true)
                )
            }
        }
        .padding(.horizontal, AppDesign.cardPadding)
        .padding(.top, AppDesign.sectionSpacing)
            .padding(.bottom, AppDesign.sectionSpacing)
    }

    @ViewBuilder
    private func multiStepActions(definition: CalculatorDefinition, flow: CalculatorFlow) -> some View {
        let clampedIndex = min(max(0, currentStepIndex), max(0, flow.steps.count - 1))
        let step = flow.steps[clampedIndex]
        let isLast = clampedIndex == flow.steps.count - 1

        Button {
            if isLast {
                Task { await calculate(definition: definition) }
            } else {
                guard canProceedStep(definition: definition, step: step) else {
                    ToastCenter.shared.warning("Заполните поля текущего шага")
                    return
                }
                withAnimation(.easeInOut(duration: 0.18)) {
                    currentStepIndex = min(flow.steps.count - 1, clampedIndex + 1)
                }
            }
        } label: {
            Text(isLast ? "Рассчитать" : (step.nextButtonTitle ?? "Далее"))
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(isCalculating || (isLast && !canCalculate(definition: definition)))
    }

    private func calculatorInputRow(input: CalculatorInput) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(input.title)
                    .appTypography(.secondary)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if let unit = input.unit, !unit.isEmpty {
                    Text(unit)
                        .appTypography(.caption)
                        .foregroundStyle(AppColors.tertiaryLabel)
                }
                Spacer(minLength: 0)
            }

            switch input.type {
            case .number:
                TextField(
                    input.placeholder ?? "",
                    text: Binding(
                        get: { inputStrings[input.key] ?? "" },
                        set: { inputStrings[input.key] = sanitizeNumber($0) }
                    )
                )
                .keyboardType(.decimalPad)
                .textFieldStyle(.plain)
                .formInputStyle()

            case .select:
                if input.options.count <= 2 {
                    Picker(
                        input.title,
                        selection: Binding(
                            get: { inputStrings[input.key] ?? input.options.first?.value ?? "" },
                            set: { inputStrings[input.key] = $0 }
                        )
                    ) {
                        ForEach(input.options, id: \.value) { opt in
                            Text(opt.label).tag(opt.value)
                        }
                    }
                    .pickerStyle(.segmented)
                } else {
                    Picker(
                        input.title,
                        selection: Binding(
                            get: { inputStrings[input.key] ?? input.options.first?.value ?? "" },
                            set: { inputStrings[input.key] = $0 }
                        )
                    ) {
                        ForEach(input.options, id: \.value) { opt in
                            Text(opt.label).tag(opt.value)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }

    @ViewBuilder
    private func inputGrid(keys: [String], definition: CalculatorDefinition) -> some View {
        let resolvedInputs = keys.compactMap { key in
            definition.inputs.first(where: { $0.key == key })
        }
        let numberInputs = resolvedInputs.filter { $0.type == .number }
        let otherInputs = resolvedInputs.filter { $0.type != .number }

        VStack(spacing: AppDesign.rowSpacing) {
            if !numberInputs.isEmpty {
                let columns = inputColumns(count: numberInputs.count)
                LazyVGrid(columns: columns, alignment: .leading, spacing: AppDesign.rowSpacing) {
                    ForEach(numberInputs) { input in
                        calculatorInputRow(input: input)
                    }
                }
            }

            if !otherInputs.isEmpty {
                VStack(spacing: AppDesign.rowSpacing) {
                    ForEach(otherInputs) { input in
                        calculatorInputRow(input: input)
                    }
                }
            }
        }
    }

    private func inputColumns(count: Int) -> [GridItem] {
        let perRow: Int
        if count > 0, count % 3 == 0 {
            perRow = 3
        } else if count > 0, count % 2 == 0 {
            perRow = 2
        } else if count >= 5 {
            perRow = 3
        } else {
            perRow = 2
        }
        return Array(repeating: GridItem(.flexible(), spacing: AppDesign.rowSpacing, alignment: .top), count: perRow)
    }

    private func canCalculate(definition: CalculatorDefinition) -> Bool {
        for input in definition.inputs where isVisible(key: input.key, definition: definition) && input.required {
            let raw = inputStrings[input.key] ?? ""
            switch input.type {
            case .number:
                guard let v = Double(raw.replacingOccurrences(of: ",", with: ".")) else { return false }
                if let min = input.min, v < min { return false }
                if let max = input.max, v > max { return false }
            case .select:
                guard !raw.isEmpty else { return false }
            }
        }
        return true
    }

    private func canProceedStep(definition: CalculatorDefinition, step: CalculatorFlowStep) -> Bool {
        for key in step.inputKeys {
            guard let input = definition.inputs.first(where: { $0.key == key }) else { continue }
            guard isVisible(key: key, definition: definition) else { continue }
            guard input.required else { continue }

            let raw = inputStrings[key] ?? ""
            switch input.type {
            case .number:
                guard let v = Double(raw.replacingOccurrences(of: ",", with: ".")) else { return false }
                if let min = input.min, v < min { return false }
                if let max = input.max, v > max { return false }
            case .select:
                guard !raw.isEmpty else { return false }
            }
        }
        return true
    }

    private func isVisible(key: String, definition: CalculatorDefinition) -> Bool {
        // Если этот key встречается в showInputKeys нескольких правил — считаем видимость по OR.
        let rules = definition.conditionalRules.filter { $0.showInputKeys.contains(key) }
        if rules.isEmpty { return true }
        return rules.contains { rule in
            let controllingValue = inputStrings[rule.ifRule.inputKey] ?? ""
            if let expected = rule.ifRule.equals { return controllingValue == expected }
            if let expected = rule.ifRule.notEquals { return controllingValue != expected }
            return true
        }
    }

    private func calculate(definition: CalculatorDefinition) async {
        guard canCalculate(definition: definition) else {
            ToastCenter.shared.warning("Заполните обязательные поля для расчёта")
            return
        }

        // Собираем inputs только для видимых полей.
        var payload: [String: CalculatorInputValue] = [:]
        for input in definition.inputs where isVisible(key: input.key, definition: definition) {
            let raw = (inputStrings[input.key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            switch input.type {
            case .number:
                if raw.isEmpty {
                    if input.required {
                        ToastCenter.shared.warning("Заполните поле: \(input.title)")
                        return
                    }
                    // Необязательное числовое поле: пустое значение не отправляем.
                    continue
                }
                let normalized = raw.replacingOccurrences(of: ",", with: ".")
                guard let v = Double(normalized) else {
                    ToastCenter.shared.warning("Некорректное значение: \(input.title)")
                    return
                }
                if let min = input.min, v < min {
                    ToastCenter.shared.warning("\(input.title) слишком мало")
                    return
                }
                if let max = input.max, v > max {
                    ToastCenter.shared.warning("\(input.title) слишком велико")
                    return
                }
                payload[input.key] = .number(v)
            case .select:
                if raw.isEmpty {
                    if input.required {
                        ToastCenter.shared.warning("Выберите значение: \(input.title)")
                        return
                    }
                    // Необязательное поле выбора: пустое значение не отправляем.
                    continue
                }
                payload[input.key] = .string(raw)
            }
        }

        isCalculating = true
        defer { isCalculating = false }
        result = nil
        do {
            let calc = try await calculatorsService.calculate(
                calculatorId: calculatorId,
                inputs: payload,
                profileId: profileId
            )
            await MainActor.run { result = calc }
        } catch {
            await MainActor.run {
                ToastCenter.shared.error(from: error, fallback: "Не удалось посчитать")
            }
        }
    }

    private func loadDefinition() async {
        isLoading = true
        result = nil
        showHowCalculated = false
        do {
            let def = try await calculatorsService.fetchDefinition(calculatorId: calculatorId)
            await MainActor.run {
                definition = def
                // defaults: select = first option; number = empty
                var defaults: [String: String] = [:]
                for input in def.inputs {
                    switch input.type {
                    case .number:
                        if case .number(let value) = input.defaultValue {
                            defaults[input.key] = defaultNumberString(value, step: input.step)
                        } else {
                            defaults[input.key] = ""
                        }
                    case .select:
                        if case .string(let value) = input.defaultValue {
                            defaults[input.key] = value
                        } else {
                            defaults[input.key] = input.options.first?.value ?? ""
                        }
                    }
                }
                inputStrings = defaults
                currentStepIndex = 0
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
            ToastCenter.shared.error(from: error, fallback: "Не удалось загрузить калькулятор")
        }
    }

    private func sanitizeNumber(_ raw: String) -> String {
        let normalized = raw.replacingOccurrences(of: ",", with: ".")
        let filtered = normalized.filter { $0.isNumber || $0 == "." }
        if let firstDot = filtered.firstIndex(of: ".") {
            let after = filtered[filtered.index(after: firstDot)...]
            let cleanedAfter = after.replacingOccurrences(of: ".", with: "")
            return String(filtered[..<filtered.index(after: firstDot)]) + cleanedAfter
        }
        return filtered
    }

    private func formattedValue(_ value: Double, decimals: Int?) -> String {
        let d = decimals ?? 0
        let rounded = (value * pow(10.0, Double(d))).rounded() / pow(10.0, Double(d))
        if d <= 0 {
            return String(Int(rounded.rounded()))
        }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.minimumFractionDigits = d
        formatter.maximumFractionDigits = d
        return formatter.string(from: NSNumber(value: rounded)) ?? String(rounded)
    }

    private func defaultNumberString(_ value: Double, step: Double?) -> String {
        if let step, step < 1 {
            let decimals = min(4, max(1, numberOfFractionDigits(step)))
            let formatter = NumberFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = decimals
            formatter.decimalSeparator = "."
            return formatter.string(from: NSNumber(value: value)) ?? String(value)
        }
        return String(Int(value.rounded()))
    }

    private func numberOfFractionDigits(_ number: Double) -> Int {
        let s = String(number)
        guard let dot = s.firstIndex(of: ".") else { return 0 }
        var fraction = String(s[s.index(after: dot)...])
        while fraction.last == "0" {
            fraction.removeLast()
        }
        return fraction.count
    }
}

#Preview {
    let client = APIClient(baseURL: ApiConfig.baseURL, getIDToken: { _ in nil })
    DynamicCalculatorView(
        calculatorId: "bmi",
        calculatorsService: APICalculatorsService(client: client),
        profileId: "1"
    )
}

