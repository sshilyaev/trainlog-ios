//
//  MeasurementsAndChartsScreen.swift
//  TrainLog
//

import SwiftUI

/// Сводка по весу, история замеров и сетка графиков (как экран «Мои достижения»: hero + контент).
struct MeasurementsAndChartsScreen: View {
    let profile: Profile
    let measurements: [Measurement]
    let goals: [Goal]
    @State private var showHelpSheet = false

    /// Цель по весу, ближайшая по дате к сегодня.
    private var nearestWeightGoal: Goal? {
        let weightGoals = goals.filter { $0.type == .weight }
        guard !weightGoals.isEmpty else { return nil }
        let now = Date().timeIntervalSince1970
        return weightGoals.min(by: { a, b in
            abs(a.targetDate.timeIntervalSince1970 - now) < abs(b.targetDate.timeIntervalSince1970 - now)
        })
    }

    private var lastWeightKg: Double? {
        measurements
            .sorted { $0.date > $1.date }
            .compactMap(\.weight)
            .first
    }

    private var targetWeightDisplay: String {
        guard let g = nearestWeightGoal else { return "—" }
        return "\(g.targetValue.measurementFormatted) кг"
    }

    private var lastWeightDisplay: String {
        guard let w = lastWeightKg else { return "—" }
        return "\(w.measurementFormatted) кг"
    }

    /// ИМТ по весу и росту из профиля.
    private var profileBmi: Double? {
        guard let h = profile.height, h > 0,
              let w = profile.weight, w > 0
        else { return nil }
        return w / pow(h / 100.0, 2)
    }

    private var bmiDisplay: String {
        guard let bmi = profileBmi else { return "—" }
        return String(format: "%.1f", bmi)
    }

    private var weightSummaryItems: [InfoValueItem] {
        [
            InfoValueItem(title: "Целевой вес", value: targetWeightDisplay),
            InfoValueItem(title: "Последний вес", value: lastWeightDisplay),
            InfoValueItem(
                title: "ИМТ",
                value: bmiDisplay,
                infoFootnote: bmiHintFootnote,
                infoHintTitle: "Информация об ИМТ",
                infoFootnoteCompactIcon: true
            ),
        ]
    }

    /// Текст подсказки: ориентиры построчно и вывод по расчётному ИМТ.
    private var bmiHintFootnote: String {
        var lines: [String] = []
        lines.append("Индекс массы тела (ИМТ) здесь считается по весу и росту из профиля.")
        lines.append("")
        lines.append("Ориентиры для взрослых (ВОЗ):")
        lines.append("ниже 18,5 — недостаточный вес")
        lines.append("18,5–24,9 — обычно в пределах нормы")
        lines.append("25–29,9 — избыточный вес")
        lines.append("30 и выше — ожирение")
        lines.append("")
        if let bmi = profileBmi {
            let formatted = String(format: "%.1f", bmi)
            lines.append("При текущем ИМТ \(formatted):")
            lines.append(bmiConclusionLine(for: bmi))
        } else {
            lines.append("Чтобы увидеть вывод по вашим данным, укажите рост и вес в профиле.")
        }
        lines.append("")
        lines.append("На оценку влияют мышечная масса, возраст и индивидуальные особенности. При сомнениях ориентируйтесь на мнение врача.")
        return lines.joined(separator: "\n")
    }

    private func bmiConclusionLine(for bmi: Double) -> String {
        if bmi < 18.5 {
            return "по этим ориентирам показатель в зоне недостаточного веса."
        }
        if bmi < 25 {
            return "по этим ориентирам показатель обычно в пределах нормы."
        }
        if bmi < 30 {
            return "по этим ориентирам показатель в зоне избыточного веса."
        }
        return "по этим ориентирам показатель в зоне ожирения."
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppDesign.blockSpacing) {
                heroCard
                    .padding(.horizontal, AppDesign.cardPadding)

                NavigationLink {
                    MeasurementsListView(
                        profile: profile,
                        measurements: measurements,
                        readOnly: true,
                        embedsNavigationStack: false
                    )
                } label: {
                    WideActionButtonToOneColumn(
                        icon: "world",
                        title: "История замеров",
                        subtitle: "Все записи, только просмотр",
                        showChevron: true,
                        iconColor: AppColors.accent
                    )
                }
                .buttonStyle(PressableButtonStyle(cornerRadius: 12))
                .padding(.horizontal, AppDesign.cardPadding)

                MeasurementChartsGridContent(
                    measurements: measurements,
                    goals: goals,
                    compactSectionChrome: true
                )
            }
            .padding(.top, AppDesign.blockSpacing)
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .background(AdaptiveScreenBackground())
        .navigationTitle("Замеры и графики")
        .navigationBarTitleDisplayMode(.inline)
        .trackAPIScreen("Замеры и графики")
        .sheet(isPresented: $showHelpSheet) {
            RecordsGuideSheet(
                title: "Замеры и графики",
                headline: "О разделе",
                description: "Здесь сводка по весу и целям, история замеров и графики динамики по каждому показателю.",
                examples: [
                    RecordsGuideExample(title: "Вес", subtitle: "Добавляйте замеры и следите за трендом по неделе/месяцу/году."),
                    RecordsGuideExample(title: "Объёмы", subtitle: "Талия, грудь, бёдра и другие метрики — удобно для контроля прогресса."),
                    RecordsGuideExample(title: "Цели", subtitle: "Поставьте цель и сверяйте динамику на графиках."),
                ],
                tips: [
                    "Делайте замеры в одно и то же время суток для честного сравнения.",
                    "Если график выглядит “рваным” — увеличьте период и смотрите тренд.",
                    "Цели и замеры лучше работают вместе: цель задаёт направление, замеры — факты.",
                ],
                onPrimaryAction: nil,
                primaryActionTitle: "",
                onClose: { showHelpSheet = false }
            )
            .mainSheetPresentation(.full)
        }
    }

    private var heroCard: some View {
        HeroCard(
            icon: "world",
            title: "Замеры и графики",
            headline: "Сводка и динамика",
            description: "Здесь сводка по целям и весу, полная история и динамика по каждому показателю.",
            accent: AppColors.profileAccent,
            decoration: .glow
        ) {
            InfoValueTripleRow(items: weightSummaryItems, chipSize: .standard)
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
}
