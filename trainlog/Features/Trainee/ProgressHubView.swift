import SwiftUI

struct ProgressHubView: View {
    let measurements: [Measurement]
    let goals: [Goal]
    let showHealthIntegration: Bool
    /// Открыть объединённый шит «Замеры / Цели».
    let onAddMeasurementOrGoal: () -> Void
    let onAddRecord: () -> Void
    let onOpenMeasurementsAndCharts: () -> Void
    let onOpenHealth: () -> Void
    let onOpenRecords: () -> Void
    @State private var didAppear = false

    private var measurementsCountText: String {
        "\(measurements.count)"
    }

    private var goalsCountText: String {
        "\(goals.count)"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroOverviewCard
                    .padding(.top, 8)
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 8)
                quickActionsBlock
                    .opacity(didAppear ? 1 : 0)
                    .scaleEffect(didAppear ? 1 : 0.985)
                    .offset(y: didAppear ? 0 : 14)
                moreSectionsBlock
                    .opacity(didAppear ? 1 : 0)
                    .scaleEffect(didAppear ? 1 : 0.99)
                    .offset(y: didAppear ? 0 : 18)
            }
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .background(AdaptiveScreenBackground())
        .navigationTitle("Прогресс")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !didAppear else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
                didAppear = true
            }
        }
    }

    private var heroOverviewCard: some View {
        HeroCard(
            icon: "sparkles",
            title: "Прогресс",
            headline: "Ваш прогресс",
            description: "",
            accent: AppColors.accent,
            decoration: .glow
        ) {
            HStack(spacing: 10) {
                kpiPill(
                    title: "Замеры",
                    value: measurementsCountText,
                    icon: "pencil-scale",
                    hint: "Вводи замеры регулярно - пойдет прогресс."
                )
                kpiPill(
                    title: "Цели",
                    value: goalsCountText,
                    icon: "map-pin",
                    hint: "Добавляй цели - фокус и мотивация выше."
                )
            }
        }
        .padding(.horizontal, AppDesign.cardPadding)
        .padding(.bottom, AppDesign.blockSpacing)
    }

    private func kpiPill(title: String, value: String, icon: String, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                AppTablerIcon(icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.accent)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                    Text(value)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                }
            }
            Text(hint)
                .font(.caption2)
                .foregroundStyle(AppColors.secondaryLabel)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppColors.secondarySystemGroupedBackground.opacity(0.9), in: RoundedRectangle(cornerRadius: 10))
    }

    private var quickActionsBlock: some View {
        ContentCard(
            title: "Быстрые действия",
            description: "Добавляйте данные и держите прогресс под контролем.",
            trailing: .icon("sparkles")
        ) {
            HStack(spacing: 10) {
                Button(action: onAddMeasurementOrGoal) {
                    BigActionButtonToTwoColumn(
                        icon: "plus-circle",
                        title: "Замер или цель",
                        subtitle: "Выберите тип в форме"
                    )
                }
                .buttonStyle(PressableButtonStyle(cornerRadius: 12))

                Button(action: onAddRecord) {
                    BigActionButtonToTwoColumn(
                        icon: "award-medal",
                        title: "Достижение",
                        subtitle: "Вес, повторы, время и др."
                    )
                }
                .buttonStyle(PressableButtonStyle(cornerRadius: 12))
            }
            .padding(.top, 2)
        }
    }

    private var moreSectionsBlock: some View {
        ContentCard(
            title: "Ещё",
            description: "Замеры, графики, достижения и интеграции."
        ) {
            VStack(spacing: 8) {
                Button(action: onOpenMeasurementsAndCharts) {
                    summaryCardRow(
                        icon: "chart.bar.fill",
                        title: "Замеры и графики",
                        subtitle: "Сводка, история замеров и динамика метрик",
                        accent: AppColors.profileAccent
                    )
                }
                .buttonStyle(PressableButtonStyle())

                Button(action: onOpenRecords) {
                    summaryCardRow(
                        icon: "award-medal",
                        title: "Мои достижения",
                        subtitle: "Личные рекорды по упражнениям и метрикам",
                        accent: AppColors.visitsOneTimeDebt
                    )
                }
                .buttonStyle(PressableButtonStyle())

                if showHealthIntegration {
                    Button(action: onOpenHealth) {
                        summaryCardRow(
                            icon: "shield-check",
                            title: "Apple Health",
                            subtitle: "Шаги, активность, сон и тренировки",
                            accent: AppColors.visitsBySubscription
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
    }

    private func summaryCardRow(
        icon: String,
        title: String,
        subtitle: String,
        accent: Color
    ) -> some View {
        WideActionButtonToOneColumn(
            icon: icon,
            title: title,
            subtitle: subtitle,
            showChevron: true,
            iconColor: accent
        )
    }
}
