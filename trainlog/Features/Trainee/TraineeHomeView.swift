//
//  TraineeHomeView.swift
//  TrainLog
//

import SwiftUI

struct TraineeHomeView<NutritionDestination: View, MembershipsDestination: View, CalculatorsDestination: View>: View {
    let profile: Profile
    let measurements: [Measurement]
    let goals: [Goal]
    let coachLinks: [CoachTraineeLink]
    let coachProfiles: [Profile]
    let membershipsCount: Int
    let activeMembershipsCount: Int
    let isLoading: Bool
    let onOpenProgress: () -> Void
    let onOpenCalendar: () -> Void
    let onShareWithCoach: () -> Void
    @ViewBuilder let nutritionDestination: () -> NutritionDestination
    @ViewBuilder let membershipsDestination: () -> MembershipsDestination
    @ViewBuilder let calculatorsDestination: () -> CalculatorsDestination

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
                    futureSection
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
                    NavigationLink(destination: nutritionDestination()) {
                        HomeActionRow(
                            icon: "coffee-cup-01",
                            title: "Питание и добавки",
                            subtitle: "План питания и назначения"
                        )
                    }
                    .buttonStyle(PressableButtonStyle())

                    if membershipsCount > 0 {
                        NavigationLink(destination: membershipsDestination()) {
                            HomeActionRow(
                                icon: "tag",
                                title: "Мои абонементы",
                                subtitle: activeMembershipsCount > 0 ? "Активных: \(activeMembershipsCount)" : "Всего: \(membershipsCount)"
                            )
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
            } else {
                Button(action: onShareWithCoach) {
                    HomeActionRow(
                        icon: "key-left",
                        title: "Подключить тренера",
                        subtitle: "Открыть код для связи"
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    private var personalActionsSection: some View {
        ContentCard(
            title: "Мои действия",
            description: "Все, что вы делаете сами: фиксируете прогресс, ведете календарь и делитесь доступом при необходимости"
        ) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                ],
                spacing: 10
            ) {
                Button(action: onOpenProgress) {
                    BigActionButtonToTwoColumn(
                        icon: "grid-dashboard-circle",
                        title: "Прогресс",
                        subtitle: "Замеры, цели и графики"
                    )
                }
                .buttonStyle(PressableButtonStyle(cornerRadius: 12))

                Button(action: onOpenCalendar) {
                    BigActionButtonToTwoColumn(
                        icon: "calendar-default",
                        title: "Календарь",
                        subtitle: "Посещения и события"
                    )
                }
                .buttonStyle(PressableButtonStyle(cornerRadius: 12))
            }

            Button(action: onShareWithCoach) {
                HomeActionRow(
                    icon: "key-left",
                    title: "Поделиться с тренером",
                    subtitle: "Показать код для доступа к дневнику"
                )
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.top, 8)
        }
    }

    private var additionalSection: some View {
        ContentCard(
            title: "Дополнительно",
            description: "Дополнительные инструменты, которые можно использовать при необходимости"
        ) {
            NavigationLink(destination: calculatorsDestination()) {
                HomeActionRow(
                    icon: "grid-dashboard-02",
                    title: "Калькуляторы",
                    subtitle: "Дополнительные расчеты"
                )
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private var futureSection: some View {
        ContentCard(
            title: "Скоро в дневнике",
            description: "Скоро появятся новые разделы, чтобы вам было удобнее отслеживать тренировки и личные результаты"
        ) {
            VStack(spacing: 8) {
                HomeActionRow(
                    icon: "treadmill",
                    title: "Тренировки",
                    subtitle: "Планы и конструктор тренировок",
                    showChevron: false
                )
                HomeActionRow(
                    icon: "award-medal",
                    title: "Мои рекорды",
                    subtitle: "Достижения и личные максимумы",
                    showChevron: false
                )
            }
        }
        .opacity(0.78)
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
                    HStack(spacing: 10) {
                        SkeletonBlock(height: 112, cornerRadius: 12)
                        SkeletonBlock(height: 112, cornerRadius: 12)
                    }
                    SkeletonBlock(height: 44, cornerRadius: 10)
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
