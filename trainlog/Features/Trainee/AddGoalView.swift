//
//  AddGoalView.swift
//  TrainLog
//

import SwiftUI
import UIKit

struct AddGoalView: View {
    let profile: Profile
    /// Если `false`, `NavigationStack` задаётся снаружи (шит «Замер / цель»).
    var embedsNavigationStack: Bool = true
    var useHostNavigationChrome: Bool = false
    var hostSavePulse: Binding<Int> = .constant(0)
    let onSave: ([Goal]) async -> Void
    let onCancel: () -> Void

    @State private var targetDate = Date()
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

    private var hasAnyValue: Bool {
        [weight, neck, shoulders, leftBiceps, rightBiceps, waist, belly, chest,
         leftThigh, rightThigh, hips, buttocks, leftCalf, rightCalf]
            .contains { parse($0) != nil }
    }

    var body: some View {
        Group {
            if embedsNavigationStack {
                NavigationStack { mainContent }
            } else {
                mainContent
            }
        }
        .environment(\.locale, .ru)
        .sheetContentEntrance()
        .mainSheetPresentation(.half)
        .sheet(isPresented: $showDatePickerSheet) {
            MainSheet(
                title: "Целевая дата",
                onBack: { showDatePickerSheet = false },
                trailing: {
                    Button("Готово") { showDatePickerSheet = false }
                        .fontWeight(.regular)
                },
                content: {
                    DatePicker("", selection: $targetDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .environment(\.locale, .ru)
                        .padding()
                }
            )
            .mainSheetPresentation(.calendar)
        }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                topInfoBlock(
                    icon: "flag",
                    text: "Фокус на ключевых целях даёт лучший результат"
                )

                SettingsCard(title: nil) {
                    FormRowDateSelection(
                        title: "Дата",
                        selection: Binding<Date?>(
                            get: { targetDate },
                            set: { if let value = $0 { targetDate = value } }
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
                        MeasurementField(title: "Шея", value: $neck, unit: "см", lastValue: nil)
                        MeasurementField(title: "Плечи", value: $shoulders, unit: "см", lastValue: nil)
                        MeasurementField(title: "Грудь", value: $chest, unit: "см", lastValue: nil)
                    }
                }

                SettingsCard(title: nil) {
                    HStack(spacing: 10) {
                        MeasurementField(title: "Бицепс (л)", value: $leftBiceps, unit: "см", lastValue: nil)
                        MeasurementField(title: "Бицепс (п)", value: $rightBiceps, unit: "см", lastValue: nil)
                    }
                }

                SettingsCard(title: nil) {
                    HStack(spacing: 10) {
                        MeasurementField(title: "Талия", value: $waist, unit: "см", lastValue: nil)
                        MeasurementField(title: "Живот", value: $belly, unit: "см", lastValue: nil)
                    }
                }

                SettingsCard(title: nil) {
                    HStack(spacing: 10) {
                        MeasurementField(title: "Ягодицы", value: $buttocks, unit: "см", lastValue: nil)
                        MeasurementField(title: "Бёдра", value: $hips, unit: "см", lastValue: nil)
                    }
                }

                SettingsCard(title: nil) {
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            MeasurementField(title: "Бедро (л)", value: $leftThigh, unit: "см", lastValue: nil)
                            MeasurementField(title: "Бедро (п)", value: $rightThigh, unit: "см", lastValue: nil)
                        }
                        HStack(spacing: 10) {
                            MeasurementField(title: "Икра (л)", value: $leftCalf, unit: "см", lastValue: nil)
                            MeasurementField(title: "Икра (п)", value: $rightCalf, unit: "см", lastValue: nil)
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
            navigationTitle: "Добавить цель",
            hasAnyValue: hasAnyValue,
            isLoading: isLoading,
            onCancel: onCancel,
            onSaveTap: {
                AppDesign.dismissKeyboardThen(delay: 0.28) { Task { await save() } }
            }
        ))
        .overlay {
            if isLoading {
                LoadingOverlayView(message: "Сохранение целей…")
            }
        }
        .allowsHitTesting(!isLoading)
    }

    private func save() async {
        guard hasAnyValue else { return }
        isLoading = true
        defer { isLoading = false }

        let pairs: [(MeasurementType, String)] = [
            (.weight, weight), (.neck, neck), (.shoulders, shoulders),
            (.leftBiceps, leftBiceps), (.rightBiceps, rightBiceps), (.waist, waist), (.belly, belly), (.chest, chest),
            (.leftThigh, leftThigh), (.rightThigh, rightThigh), (.hips, hips), (.buttocks, buttocks),
            (.leftCalf, leftCalf), (.rightCalf, rightCalf)
        ]
        var goals: [Goal] = []
        for (type, str) in pairs {
            guard let value = parse(str), !str.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            goals.append(Goal(
                id: "",  // пустой id = создание через POST; сервер вернёт id в ответе
                profileId: profile.id,
                measurementType: type.rawValue,
                targetValue: value,
                targetDate: targetDate,
                createdAt: Date()
            ))
        }
        if !goals.isEmpty {
            await onSave(goals)
        }
    }

    @ViewBuilder
    private func topInfoBlock(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            AppTablerIcon(icon)
                .appTypography(.bodyEmphasis)
                .foregroundStyle(AppColors.accent)
                .frame(width: 22, height: 22)
                .background(AppColors.accent.opacity(0.16), in: Circle())

            Text(text)
                .appTypography(.caption)
                .foregroundStyle(AppColors.label)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.accent.opacity(0.25), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

#Preview {
    AddGoalView(
        profile: Profile(id: "1", userId: "u1", type: .trainee, name: "Мой дневник"),
        onSave: { _ in },
        onCancel: {}
    )
}
