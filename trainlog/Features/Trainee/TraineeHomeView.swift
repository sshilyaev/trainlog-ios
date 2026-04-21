//
//  TraineeHomeView.swift
//  TrainLog
//

import SwiftUI

struct TraineeHomeView<NutritionDestination: View, MembershipsDestination: View, CalculatorsDestination: View, CalendarDestination: View>: View {
    let profile: Profile
    let measurements: [Measurement]
    let goals: [Goal]
    let coachLinks: [CoachTraineeLink]
    let coachProfiles: [Profile]
    let membershipsCount: Int
    let activeMembershipsCount: Int
    let isLoading: Bool
    let onOpenProgress: () -> Void
    let onShareWithCoach: () -> Void
    let supportCampaignService: SupportCampaignServiceProtocol
    let rewardedAdService: RewardedAdServiceProtocol
    @ViewBuilder let nutritionDestination: () -> NutritionDestination
    @ViewBuilder let membershipsDestination: () -> MembershipsDestination
    @ViewBuilder let calculatorsDestination: () -> CalculatorsDestination
    @ViewBuilder let calendarDestination: () -> CalendarDestination

    private var trainerBlockDescription: String {
        guard !coachLinks.isEmpty else {
            return "Подключите тренера, чтобы получать рекомендации по питанию, добавкам и абонементам"
        }
        let name = coachProfiles.first?.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let name, !name.isEmpty {
            return "Ваш тренер \(name) подготовил рекомендации и следит за динамикой вашего дневника"
        }
        return "Ваш тренер подготовил рекомендации и следит за динамикой вашего дневника"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if isLoading {
                    homeSkeleton
                } else {
                    trainerSection
                    personalActionsSection
                    additionalSection
                }
            }
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .background(AdaptiveScreenBackground())
    }

    @ViewBuilder
    private var trainerSection: some View {
        ContentCard(
            title: "От тренера",
            description: trainerBlockDescription
        ) {
            if !coachLinks.isEmpty {
                VStack(spacing: 8) {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10),
                        ],
                        spacing: 10
                    ) {
                        NavigationLink(destination: nutritionDestination()) {
                            BigActionButtonToTwoColumn(
                                icon: "tools-kitchen-2",
                                title: "Питание и добавки",
                                subtitle: "План и назначения"
                            )
                        }
                        .buttonStyle(PressableButtonStyle(cornerRadius: 12))

                        NavigationLink(destination: membershipsDestination()) {
                            BigActionButtonToTwoColumn(
                                icon: "tag",
                                title: "Абонементы",
                                subtitle: activeMembershipsCount > 0 ? "Активных: \(activeMembershipsCount)" : "Всего: \(membershipsCount)"
                            )
                        }
                        .buttonStyle(PressableButtonStyle(cornerRadius: 12))
                    }

                    NavigationLink(destination: calendarDestination()) {
                        HomeActionRow(
                            icon: "calendar-default",
                            title: "Мой календарь",
                            subtitle: "Посещения и события"
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            } else {
                Button(action: onShareWithCoach) {
                    HomeActionRow(
                        icon: "key-left",
                        title: "Подключить тренера",
                        subtitle: "Открыть код для связи",
                        accent: AppColors.profileAccent,
                        showsLeadingAccentBar: true,
                        statusTitle: "Важно",
                        statusColor: AppColors.profileAccent
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    private var personalActionsSection: some View {
        ContentCard(
            title: "Мои действия",
            description: "Все, что вы делаете сами в дневнике"
        ) {
            Button(action: onOpenProgress) {
                HomeActionRow(
                    icon: "grid-dashboard-circle",
                    title: "Мой прогресс",
                    subtitle: "Замеры, цели и графики"
                )
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.bottom, 4)

            Text("Планы тренировок и конструктор — в следующих версиях; сейчас фокус на прогрессе и связи с тренером.")
                .appTypography(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
        }
    }

    private var additionalSection: some View {
        ContentCard(
            title: "Дополнительно",
            description: "Дополнительные инструменты, которые можно использовать при необходимости"
        ) {
            VStack(spacing: 8) {
                NavigationLink(destination: calculatorsDestination()) {
                    HomeActionRow(
                        icon: "grid-dashboard-02",
                        title: "Калькуляторы",
                        subtitle: "Дополнительные расчеты",
                        accent: AppColors.profileAccent
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
                        subtitle: "Мини-игра: помощь виртуальным клиентам",
                        accent: AppColors.profileAccent
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    private var homeSkeleton: some View {
        VStack(spacing: 0) {
            SettingsCard {
                VStack(alignment: .leading, spacing: 10) {
                    SkeletonLine(width: 130, height: 14)
                    SkeletonLine(width: 240, height: 12)
                    SkeletonBlock(height: 46, cornerRadius: 10)
                    SkeletonBlock(height: 46, cornerRadius: 10)
                }
            }
            SettingsCard {
                VStack(alignment: .leading, spacing: 10) {
                    SkeletonLine(width: 120, height: 14)
                    SkeletonLine(width: 250, height: 12)
                    SkeletonBlock(height: 44, cornerRadius: 10)
                    SkeletonLine(width: 280, height: 10)
                }
            }
            SettingsCard {
                VStack(alignment: .leading, spacing: 10) {
                    SkeletonLine(width: 120, height: 14)
                    SkeletonLine(width: 210, height: 12)
                    SkeletonBlock(height: 44, cornerRadius: 10)
                }
            }
        }
    }
}
