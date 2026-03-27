//
//  AddMeasurementForTodaySheet.swift
//  TrainLog
//

import SwiftUI
import UIKit

/// Быстрое добавление одной метрики за сегодня. По тапу на карточку метрики на дашборде.
struct AddMeasurementForTodaySheet: View {
    let profile: Profile
    let metric: MeasurementType
    var lastMeasurement: Measurement?
    let onSave: (Measurement) async -> Void
    let onCancel: () -> Void

    @State private var date = Calendar.current.startOfDay(for: Date())
    @State private var valueText: String = ""
    @State private var isLoading = false
    @State private var showDatePickerSheet = false

    private var lastValue: Double? {
        lastMeasurement.flatMap { metric.value(from: $0) }
    }

    private func parse(_ s: String) -> Double? {
        let n = s.replacingOccurrences(of: ",", with: ".")
        return Double(n)
    }

    var body: some View {
        MainSheet(
            title: metric.displayName,
            onBack: onCancel,
            trailing: {
                Button {
                    AppDesign.dismissKeyboardThen(delay: 0.28) { Task { await save() } }
                } label: {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.9)
                    } else {
                        Text("Сохранить")
                    }
                }
                .disabled(valueText.trimmingCharacters(in: .whitespaces).isEmpty || parse(valueText) == nil || isLoading)
                .fontWeight(.regular)
            },
            content: {
                ScrollView {
                    VStack(spacing: 0) {
                        SettingsCard(title: "Дата") {
                            FormRowDateSelection(
                                title: "Дата замера",
                                selection: Binding<Date?>(
                                    get: { date },
                                    set: { if let value = $0 { date = value } }
                                ),
                                allowsClear: false,
                                onTap: { showDatePickerSheet = true }
                            )
                        }
                        SettingsCard(title: metric.displayName) {
                            MeasurementField(
                                title: metric.displayName,
                                value: $valueText,
                                unit: metric.unit,
                                lastValue: lastValue
                            )
                        }
                    }
                    .padding(.bottom, AppDesign.sectionSpacing)
                }
                .background(AppColors.systemGroupedBackground)
                .dismissKeyboardOnTap()
                .overlay {
                    if isLoading {
                        LoadingOverlayView(message: "Сохранение…")
                    }
                }
                .allowsHitTesting(!isLoading)
            }
        )
        .environment(\.locale, .ru)
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
    }

    private func save() async {
        guard let value = parse(valueText) else { return }
        isLoading = true
        defer { isLoading = false }

        // пустой id = создание через POST; сервер вернёт id в ответе
        let id = ""
        let m: Measurement
        switch metric {
        case .weight: m = Measurement(id: id, profileId: profile.id, date: date, weight: value)
        case .height: m = Measurement(id: id, profileId: profile.id, date: date, height: value)
        case .neck: m = Measurement(id: id, profileId: profile.id, date: date, neck: value)
        case .shoulders: m = Measurement(id: id, profileId: profile.id, date: date, shoulders: value)
        case .leftBiceps: m = Measurement(id: id, profileId: profile.id, date: date, leftBiceps: value)
        case .rightBiceps: m = Measurement(id: id, profileId: profile.id, date: date, rightBiceps: value)
        case .waist: m = Measurement(id: id, profileId: profile.id, date: date, waist: value)
        case .belly: m = Measurement(id: id, profileId: profile.id, date: date, belly: value)
        case .chest: m = Measurement(id: id, profileId: profile.id, date: date, chest: value)
        case .leftThigh: m = Measurement(id: id, profileId: profile.id, date: date, leftThigh: value)
        case .rightThigh: m = Measurement(id: id, profileId: profile.id, date: date, rightThigh: value)
        case .hips: m = Measurement(id: id, profileId: profile.id, date: date, hips: value)
        case .buttocks: m = Measurement(id: id, profileId: profile.id, date: date, buttocks: value)
        case .leftCalf: m = Measurement(id: id, profileId: profile.id, date: date, leftCalf: value)
        case .rightCalf: m = Measurement(id: id, profileId: profile.id, date: date, rightCalf: value)
        }
        await onSave(m)
    }
}
