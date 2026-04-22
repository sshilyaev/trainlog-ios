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
            title: "Ваш прогресс",
            headline: "",
            description: "",
            accent: AppColors.accent,
            decoration: .glow
        ) {
            MetricRowCompactExtended(
                items: [
                    InfoValueItem(
                        title: "Замеры",
                        value: measurementsCountText,
                        icon: "pencil-scale",
                        description: "Вводите замеры регулярно, чтобы видеть динамику."
                    ),
                    InfoValueItem(
                        title: "Цели",
                        value: goalsCountText,
                        icon: "map-pin",
                        description: "Добавляйте цели, чтобы удерживать фокус."
                    )
                ],
                style: .standard,
                backgroundColor: AppColors.accent,
                valueWeight: .bold,
                descriptionLineLimit: 3
            )
        }
        .padding(.horizontal, AppDesign.cardPadding)
        .padding(.bottom, AppDesign.blockSpacing)
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
            title: "Подробнее",
            description: "Замеры, графики, достижения и интеграции."
        ) {
            VStack(spacing: 8) {
                Button(action: onOpenMeasurementsAndCharts) {
                    summaryCardRow(
                        icon: "world",
                        title: "Мои замеры",
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
