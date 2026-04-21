//
//  CoachHomeView.swift
//  TrainLog
//

import SwiftUI

struct CoachHomeQuickPickRow: Identifiable, Hashable {
    let id: String
    let title: String
}

/// Вкладка «Главная» тренера: сводка по клиентам, быстрые действия, калькуляторы и статистика (не смешиваются со списком подопечных).
struct CoachHomeView: View {
    let weekSummaryClients: Int
    let weekSummaryOneOffVisits: Int
    let weekSummarySubscriptionVisits: Int
    /// Подпись периода недели, например «17 мар — 23 мар 2025».
    let weekSummaryRangeCaption: String
    let isLoading: Bool
    let coachProfileId: String
    let calculatorsService: CalculatorsServiceProtocol
    let supportCampaignService: SupportCampaignServiceProtocol
    let rewardedAdService: RewardedAdServiceProtocol
    let coachStatisticsService: CoachStatisticsServiceProtocol
    let quickPickRows: [CoachHomeQuickPickRow]
    let onAddTrainee: () -> Void
    let onOpenAllTrainees: () -> Void
    let onSelectQuickPickTrainee: (String) -> Void

    @State private var quickPickMenuSelection: String?
    private var isWeekSummaryEmpty: Bool {
        weekSummaryClients == 0 && weekSummaryOneOffVisits == 0 && weekSummarySubscriptionVisits == 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if isLoading {
                    coachHomeSkeleton
                } else {
                    summarySection
                    quickActionsSection
                    additionalSection
                }
            }
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .background(AdaptiveScreenBackground())
    }

    private var summarySection: some View {
        ContentCard(
            title: "Сводка за неделю",
            description: weekSummaryRangeCaption.isEmpty ? "—" : weekSummaryRangeCaption
        ) {
            InfoValueTripleRow(
                items: [
                    InfoValueItem(
                        title: "Клиенты",
                        value: "\(weekSummaryClients)",
                        accentColor: AppColors.genderMale,
                        infoFootnote: "Уникальные клиенты, у которых за текущую неделю есть хотя бы одно проведённое посещение.",
                        infoHintTitle: "Клиенты",
                        infoFootnoteCompactIcon: true
                    ),
                    InfoValueItem(
                        title: "Разовые визиты",
                        value: "\(weekSummaryOneOffVisits)",
                        accentColor: AppColors.visitsOneTimeDebt
                    ),
                    InfoValueItem(
                        title: "По абонементу",
                        value: "\(weekSummarySubscriptionVisits)",
                        accentColor: AppColors.visitsBySubscription
                    )
                ],
                style: .colored,
                chipSize: .coachSummary
            )
            .padding(.vertical, 4)

            if isWeekSummaryEmpty {
                Text("Данные появятся после внесения посещений и событий за эту неделю.")
                    .appTypography(.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
            }

            NavigationLink {
                CoachStatisticsView(
                    coachProfileId: coachProfileId,
                    statisticsService: coachStatisticsService
                )
            } label: {
                HomeActionRow(
                    icon: "grid-dashboard-circle",
                    title: "Полная статистика",
                    subtitle: "Сводка за период"
                )
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.top, 8)
        }
    }

    private var quickActionsSection: some View {
        ContentCard(
            title: "Быстрые действия",
            description: "Частые шаги при работе с подопечными",
            trailing: .icon("sparkles")
        ) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                ],
                spacing: 10
            ) {
                Button(action: onAddTrainee) {
                    BigActionButtonToTwoColumn(
                        icon: "plus-square",
                        title: "Добавить",
                        subtitle: "Нового подопечного"
                    )
                }
                .buttonStyle(PressableButtonStyle(cornerRadius: 12))

                Button(action: onOpenAllTrainees) {
                    BigActionButtonToTwoColumn(
                        icon: "users-group",
                        title: "Посмотреть",
                        subtitle: "Весь список"
                    )
                }
                .buttonStyle(PressableButtonStyle(cornerRadius: 12))
            }

            Group {
                if quickPickRows.isEmpty {
                    Text("Добавьте активного подопечного — здесь появится выбор для перехода в карточку.")
                        .appTypography(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    HStack(alignment: .center, spacing: 10) {
                        AppTablerIcon("list-details")
                            .appIcon(.s14)
                            .foregroundStyle(AppColors.accent)
                            .frame(width: 20, alignment: .center)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Карточка")
                                .appTypography(.bodyEmphasis)
                                .foregroundStyle(AppColors.label)
                            Text("Выберите подопечного")
                                .appTypography(.caption)
                                .foregroundStyle(AppColors.secondaryLabel)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Picker("", selection: $quickPickMenuSelection) {
                            Text("Выбрать").tag(nil as String?)
                            ForEach(quickPickRows) { row in
                                Text(row.title).tag(Optional(row.id))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                    .padding(.vertical, 9)
                    .onChange(of: quickPickMenuSelection) { _, newValue in
                        guard let id = newValue else { return }
                        onSelectQuickPickTrainee(id)
                        DispatchQueue.main.async {
                            quickPickMenuSelection = nil
                        }
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private var additionalSection: some View {
        ContentCard(
            title: "Дополнительно",
            description: "Инструменты, не привязанные к конкретному клиенту"
        ) {
            VStack(spacing: 8) {
                NavigationLink {
                    CalculatorsCatalogView(
                        calculatorsService: calculatorsService,
                        profileId: coachProfileId
                    )
                } label: {
                    HomeActionRow(
                        icon: "grid-dashboard-02",
                        title: "Калькуляторы",
                        subtitle: "Справочные расчёты"
                    )
                }
                .buttonStyle(PressableButtonStyle())

                NavigationLink {
                    SupportProjectView(
                        campaignService: supportCampaignService,
                        rewardedAdService: rewardedAdService
                    )
                } label: {
                    HomeActionRow(
                        icon: "currency-rubel",
                        title: "Поддержать проект",
                        subtitle: "Мини-игра: помощь виртуальным клиентам"
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    private var coachHomeSkeleton: some View {
        VStack(spacing: 0) {
            SettingsCard {
                VStack(alignment: .leading, spacing: 10) {
                    SkeletonLine(width: 100, height: 14)
                    SkeletonLine(width: 260, height: 12)
                    HStack(spacing: 8) {
                        SkeletonBlock(height: 56, cornerRadius: 8)
                        SkeletonBlock(height: 56, cornerRadius: 8)
                        SkeletonBlock(height: 56, cornerRadius: 8)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            SettingsCard {
                VStack(alignment: .leading, spacing: 10) {
                    SkeletonLine(width: 140, height: 14)
                    SkeletonLine(width: 240, height: 12)
                    HStack(spacing: 10) {
                        SkeletonBlock(height: 96, cornerRadius: 12)
                        SkeletonBlock(height: 96, cornerRadius: 12)
                    }
                    SkeletonBlock(height: 44, cornerRadius: 10)
                }
            }
            SettingsCard {
                VStack(alignment: .leading, spacing: 10) {
                    SkeletonLine(width: 130, height: 14)
                    SkeletonLine(width: 220, height: 12)
                    SkeletonBlock(height: 44, cornerRadius: 10)
                    SkeletonBlock(height: 44, cornerRadius: 10)
                }
            }
        }
    }
}
