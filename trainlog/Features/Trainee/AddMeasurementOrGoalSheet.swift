//
//  AddMeasurementOrGoalSheet.swift
//  TrainLog
//

import SwiftUI

enum ProgressAddSheetKind: String, CaseIterable {
    case measurement = "Замеры"
    case goal = "Цели"
}

/// Один шит с переключением «Замеры / Цели» для быстрых действий на экране «Прогресс».
/// Заголовок навигации и панель задаются здесь, чтобы не конфликтовать с вложенным контентом.
struct AddMeasurementOrGoalSheet: View {
    @Binding var selectedKind: ProgressAddSheetKind
    let profile: Profile
    var lastMeasurement: Measurement?
    let onSaveMeasurement: (Measurement) async -> Void
    let onSaveGoals: ([Goal]) async -> Void
    let onCancel: () -> Void

    @State private var toolbarState = ProgressAddFormToolbarState(canSave: false, isLoading: false)
    @State private var measurementSavePulse = 0
    @State private var goalSavePulse = 0

    private var sheetNavigationTitle: String {
        switch selectedKind {
        case .measurement:
            return "Добавить замер"
        case .goal:
            return "Добавить цель"
        }
    }

    var body: some View {
        MainSheet(
            title: sheetNavigationTitle,
            onBack: onCancel,
            trailing: {
                Button {
                    switch selectedKind {
                    case .measurement:
                        measurementSavePulse += 1
                    case .goal:
                        goalSavePulse += 1
                    }
                } label: {
                    if toolbarState.isLoading {
                        ProgressView().scaleEffect(0.9)
                    } else {
                        Text("Сохранить")
                            .font(.body)
                            .fontWeight(.regular)
                    }
                }
                .disabled(!toolbarState.canSave || toolbarState.isLoading)
            },
            content: {
                VStack(spacing: 0) {
                    Picker("", selection: $selectedKind) {
                        ForEach(ProgressAddSheetKind.allCases, id: \.self) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    Group {
                        switch selectedKind {
                        case .measurement:
                            AddMeasurementView(
                                profile: profile,
                                lastMeasurement: lastMeasurement,
                                embedsNavigationStack: false,
                                useHostNavigationChrome: true,
                                hostSavePulse: $measurementSavePulse,
                                onSave: onSaveMeasurement,
                                onCancel: onCancel
                            )
                        case .goal:
                            AddGoalView(
                                profile: profile,
                                embedsNavigationStack: false,
                                useHostNavigationChrome: true,
                                hostSavePulse: $goalSavePulse,
                                onSave: onSaveGoals,
                                onCancel: onCancel
                            )
                        }
                    }
                    .id(selectedKind)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(AppColors.systemGroupedBackground)
                .navigationBarBackButtonHidden(true)
                .onPreferenceChange(ProgressAddFormToolbarPreferenceKey.self) { toolbarState = $0 }
            }
        )
    }
}
