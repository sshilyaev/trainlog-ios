//
//  AddMeasurementView.swift
//  TrainLog
//

import SwiftUI
import UIKit

struct AddMeasurementView: View {
    let profile: Profile
    var lastMeasurement: Measurement?
    /// Если `false`, оборачивающий `NavigationStack` должен быть снаружи (например, шит «Замер / цель»).
    var embedsNavigationStack: Bool = true
    /// Заголовок и кнопки навбара задаёт `AddMeasurementOrGoalSheet`; контент только шлёт состояние и реагирует на `hostSavePulse`.
    var useHostNavigationChrome: Bool = false
    var hostSavePulse: Binding<Int> = .constant(0)
    let onSave: (Measurement) async -> Void
    let onCancel: () -> Void

    @State private var date = Date()
    @State private var weight: String = ""
    @State private var neck: String = ""
    @State private var shoulders: String = ""
    @State private var leftBiceps: String = ""
    @State private var rightBiceps: String = ""
    @State private var waist: String = ""
    @State private var belly: String = ""
    @State private var chest: String = ""
    @State private var leftThigh: String = ""
    @State private var rightThigh: String = ""
    @State private var hips: String = ""
    @State private var buttocks: String = ""
    @State private var leftCalf: String = ""
    @State private var rightCalf: String = ""
    @State private var isLoading = false
    @State private var showDatePickerSheet = false

    private func parse(_ s: String) -> Double? {
        let n = s.replacingOccurrences(of: ",", with: ".")
        return Double(n)
    }

    private static var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = .ru
        f.dateStyle = .medium
        return f
    }

    var body: some View {
        Group {
            if embedsNavigationStack {
                NavigationStack { mainContent }
            } else {
                mainContent
            }
        }
        .sheetContentEntrance()
        .mainSheetPresentation(.half)
        .sheet(isPresented: $showDatePickerSheet) {
            MainSheet(
                title: "Дата замера",
                onBack: { showDatePickerSheet = false },
                trailing: {
                    Button("Готово") { showDatePickerSheet = false }
                        .fontWeight(.regular)
                },
                content: {
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .environment(\.locale, .ru)
                        .padding()
                }
            )
            .mainSheetPresentation(.calendar)
        }
        .onAppear {
            // Чтобы ввод веса был как при редактировании профиля: подставляем последнее значение.
            if weight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let last = lastMeasurement?.weight {
                weight = last.measurementFormatted
            }
        }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                SettingsCard(title: nil) {
                    FormRowDateSelection(
                        title: "Дата замера",
                        selection: Binding<Date?>(
                            get: { date },
                            set: { if let value = $0 { date = value } }
                        ),
                        allowsClear: false,
                        onTap: { showDatePickerSheet = true }
                    )
                    FormSectionDivider()
                    FormRowTextField(
                        icon: "pencil-scale",
                        title: "Вес",
                        placeholder: "кг",
                        text: $weight,
                        autocapitalization: .never,
                        keyboardType: .decimalPad
                    )
                }

                SettingsCard(title: nil) {
                    HStack(spacing: 10) {
                        MeasurementField(title: "Шея", value: $neck, unit: "см", lastValue: lastMeasurement?.neck)
                        MeasurementField(title: "Плечи", value: $shoulders, unit: "см", lastValue: lastMeasurement?.shoulders)
                        MeasurementField(title: "Грудь", value: $chest, unit: "см", lastValue: lastMeasurement?.chest)
                    }
                }

                SettingsCard(title: nil) {
                    HStack(spacing: 10) {
                        MeasurementField(title: "Бицепс (л)", value: $leftBiceps, unit: "см", lastValue: lastMeasurement?.leftBiceps)
                        MeasurementField(title: "Бицепс (п)", value: $rightBiceps, unit: "см", lastValue: lastMeasurement?.rightBiceps)
                    }
                }

                SettingsCard(title: nil) {
                    HStack(spacing: 10) {
                        MeasurementField(title: "Талия", value: $waist, unit: "см", lastValue: lastMeasurement?.waist)
                        MeasurementField(title: "Живот", value: $belly, unit: "см", lastValue: lastMeasurement?.belly)
                    }
                }

                SettingsCard(title: nil) {
                    HStack(spacing: 10) {
                        MeasurementField(title: "Ягодицы", value: $buttocks, unit: "см", lastValue: lastMeasurement?.buttocks)
                        MeasurementField(title: "Бёдра", value: $hips, unit: "см", lastValue: lastMeasurement?.hips)
                    }
                }

                SettingsCard(title: nil) {
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            MeasurementField(title: "Бедро (л)", value: $leftThigh, unit: "см", lastValue: lastMeasurement?.leftThigh)
                            MeasurementField(title: "Бедро (п)", value: $rightThigh, unit: "см", lastValue: lastMeasurement?.rightThigh)
                        }
                        HStack(spacing: 10) {
                            MeasurementField(title: "Икра (л)", value: $leftCalf, unit: "см", lastValue: lastMeasurement?.leftCalf)
                            MeasurementField(title: "Икра (п)", value: $rightCalf, unit: "см", lastValue: lastMeasurement?.rightCalf)
                        }
                    }
                }
            }
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .background(AppColors.systemGroupedBackground)
        .scrollDismissesKeyboard(.immediately)
        .dismissKeyboardOnTap()
        .modifier(ProgressAddFormNavigationChrome(
            useHostChrome: useHostNavigationChrome,
            hostSavePulse: hostSavePulse,
            navigationTitle: "Добавить замер",
            hasAnyValue: hasAnyValue,
            isLoading: isLoading,
            onCancel: onCancel,
            onSaveTap: {
                AppDesign.dismissKeyboardThen(delay: 0.28) { Task { await save() } }
            }
        ))
        .overlay {
            if isLoading {
                LoadingOverlayView(message: "Сохранение…")
            }
        }
        .allowsHitTesting(!isLoading)
    }

    private var hasAnyValue: Bool {
        [weight, neck, shoulders, leftBiceps, rightBiceps, waist, belly, chest,
         leftThigh, rightThigh, hips, buttocks, leftCalf, rightCalf]
            .contains { parse($0) != nil }
    }

    private func save() async {
        isLoading = true
        defer { isLoading = false }

        let m = Measurement(
            id: "",  // пустой id = создание через POST; сервер вернёт id в ответе
            profileId: profile.id,
            date: date,
            weight: parse(weight),
            neck: parse(neck),
            shoulders: parse(shoulders),
            leftBiceps: parse(leftBiceps),
            rightBiceps: parse(rightBiceps),
            waist: parse(waist),
            belly: parse(belly),
            chest: parse(chest),
            leftThigh: parse(leftThigh),
            rightThigh: parse(rightThigh),
            hips: parse(hips),
            buttocks: parse(buttocks),
            leftCalf: parse(leftCalf),
            rightCalf: parse(rightCalf),
            note: nil
        )
        await onSave(m)
    }

}

struct MeasurementField: View {
    let title: String
    @Binding var value: String
    let unit: String
    var lastValue: Double?

    private var placeholder: String {
        if let v = lastValue {
            return v.measurementFormatted
        }
        return defaultPlaceholder
    }

    private var defaultPlaceholder: String {
        if unit == "кг" { return "70" }
        // Единицы в сантиметрах: подбираем «реальные» числа по названию метрики.
        if title.contains("Шея") { return "40" }
        if title.contains("Плечи") { return "50" }
        if title.contains("Грудь") { return "100" }
        if title.contains("Талия") { return "80" }
        if title.contains("Живот") { return "85" }
        if title.contains("Бицепс") { return "35" }
        if title.contains("Бедро") || title.contains("Бёдра") { return "55" }
        if title.contains("Ягодицы") { return "105" }
        if title.contains("Икра") { return "35" }
        return "90"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text(title)
                Text(unit)
                    .appTypography(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .lineLimit(1)

            TextField(placeholder, text: $value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.leading)
                .appTypography(.bodyEmphasis)
                .textFieldStyle(.plain)
                .formInputCompactStyle()
                .onAppear {
                    if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       let lastValue {
                        value = lastValue.measurementFormatted
                    }
                }
                .onChange(of: value) { _, newValue in
                    let sanitized = sanitizeDecimalInput(newValue)
                    if sanitized != newValue {
                        value = sanitized
                    }
                }
        }
        .frame(maxWidth: .infinity)
        .environment(\.locale, .ru)
    }

    private func sanitizeDecimalInput(_ raw: String) -> String {
        var s = raw.replacingOccurrences(of: ",", with: ".")
        s = s.filter { $0.isNumber || $0 == "." }
        if let firstDot = s.firstIndex(of: ".") {
            let after = s[s.index(after: firstDot)...]
            let cleanedAfter = after.replacingOccurrences(of: ".", with: "")
            s = String(s[..<s.index(after: firstDot)]) + cleanedAfter
        }
        return s
    }
}

#if canImport(SwiftUI)
private extension View {
    func formInputCompactStyle() -> some View {
        self
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(AppColors.tertiarySystemFill, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color(.separator).opacity(0.5), lineWidth: 0.5)
            )
    }
}
#endif

#Preview {
    AddMeasurementView(
        profile: Profile(id: "1", userId: "u1", type: .trainee, name: "Мой дневник"),
        lastMeasurement: nil,
        onSave: { _ in },
        onCancel: {}
    )
}
