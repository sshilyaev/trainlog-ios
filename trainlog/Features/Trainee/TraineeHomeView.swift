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
    let totalTrainingsCount: Int
    let isLoading: Bool
    let onOpenProgress: () -> Void
    let onShareWithCoach: () -> Void
    let supportCampaignService: SupportCampaignServiceProtocol
    let rewardedAdService: RewardedAdServiceProtocol
    @ViewBuilder let nutritionDestination: () -> NutritionDestination
    @ViewBuilder let membershipsDestination: () -> MembershipsDestination
    @ViewBuilder let calculatorsDestination: () -> CalculatorsDestination
    @ViewBuilder let calendarDestination: () -> CalendarDestination
    @Environment(\.openURL) private var openURL

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

    private var primaryCoach: Profile? {
        coachProfiles.first
    }

    private var coachPhoneDisplay: String? {
        guard let phone = primaryCoach?.phoneNumber?.trimmingCharacters(in: .whitespacesAndNewlines), !phone.isEmpty else { return nil }
        return PhoneFormatter.formatForDisplay(phone)
    }

    private var coachTelegramDisplay: String? {
        guard let raw = primaryCoach?.telegramUsername?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        return raw.hasPrefix("@") ? raw : "@\(raw)"
    }

    private var latestMeasurementDate: Date? {
        measurements.max(by: { $0.date < $1.date })?.date
    }

    private var lastMeasurementText: String {
        latestMeasurementDate?.formattedRuShort ?? "—"
    }

    private var isLastMeasurementStale: Bool {
        guard let latestMeasurementDate else { return false }
        guard let days = Calendar.current.dateComponents([.day], from: latestMeasurementDate, to: Date()).day else { return false }
        return days > 7
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if isLoading {
                    homeSkeleton
                } else {
                    diarySummarySection
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
    private var diarySummarySection: some View {
        HeroCard(
            icon: "chart-bar",
            title: "Сводка",
            headline: "Дневник за текущий период",
            description: "Быстрый срез по активности и измерениям.",
            accent: AppColors.profileAccent,
            decoration: .glow
        ) {
            MetricRowLarge(
                items: [
                    InfoValueItem(
                        title: "Последний замер",
                        value: lastMeasurementText,
                        accentColor: AppColors.profileAccent
                    ),
                    InfoValueItem(
                        title: "Тренировок",
                        value: "\(totalTrainingsCount)",
                        accentColor: AppColors.visitsBySubscription
                    ),
                    InfoValueItem(
                        title: "Замеров",
                        value: "\(measurements.count)",
                        accentColor: AppColors.genderMale
                    ),
                ],
                backgroundColor: AppColors.profileAccent,
                textColor: AppColors.label
            )
            .padding(.top, 4)

            if latestMeasurementDate == nil {
                Text("Пока нет замеров. Добавьте первый замер, чтобы рекомендации и динамика в дневнике стали точными.")
                    .appTypography(.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            } else if isLastMeasurementStale {
                Text("Последний замер был больше недели назад. Обновите данные, чтобы рекомендации оставались точными.")
                    .appTypography(.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            }

            Button(action: onOpenProgress) {
                Text("Открыть прогресс")
                    .appTypography(.button)
                    .foregroundStyle(AppColors.white)
                    .frame(maxWidth: .infinity, minHeight: AppDesign.minTouchTarget)
                    .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .actionBlockStyle()
    }

    @ViewBuilder
    private var trainerSection: some View {
        if !coachLinks.isEmpty, let coach = primaryCoach {
            ContentCard(
                title: "Мой тренер",
                description: "Контакты и рекомендации"
            ) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Ваш тренер")
                            .appTypography(.caption)
                            .foregroundStyle(AppColors.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.accent.opacity(0.14), in: Capsule())
                        Spacer()
                    }
                    .padding(.bottom, 12)

                    HStack(alignment: .center, spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            AppColors.accent.opacity(0.35),
                                            AppColors.profileAccent.opacity(0.22),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 76, height: 76)
                                .overlay(
                                    Circle()
                                        .strokeBorder(AppColors.accent.opacity(0.35), lineWidth: 1)
                                )
                            AppTablerIcon(coach.gender == .female ? "person" : "person")
                                .appIcon(.s32, weight: .medium)
                                .foregroundStyle(AppColors.label)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(coach.name)
                                .appTypography(.bodyEmphasis)
                                .foregroundStyle(AppColors.label)
                                .lineLimit(2)
                            if let dob = coach.dateOfBirth {
                                let age = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
                                let ageLabel = age > 0 ? " (\(age))" : ""
                                Text("\(dob.formattedRuShort)\(ageLabel)")
                                    .appTypography(.caption)
                                    .foregroundStyle(AppColors.secondaryLabel)
                            } else {
                                Text("Дата рождения не указана")
                                    .appTypography(.caption)
                                    .foregroundStyle(AppColors.secondaryLabel)
                            }
                            if let gym = coach.gymName?.trimmingCharacters(in: .whitespacesAndNewlines), !gym.isEmpty {
                                Text(gym)
                                    .appTypography(.caption)
                                    .foregroundStyle(AppColors.secondaryLabel)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.bottom, 10)

                    if let phone = coach.phoneNumber?.trimmingCharacters(in: .whitespacesAndNewlines), !phone.isEmpty {
                        Divider()
                        Button {
                            let digits = PhoneFormatter.digitsOnly(phone)
                            guard let url = URL(string: "tel://\(digits)") else { return }
                            openURL(url)
                        } label: {
                            trainerActionRow(icon: "phone", title: "Телефон", value: coachPhoneDisplay ?? phone)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                    if let tgRaw = coach.telegramUsername?.trimmingCharacters(in: .whitespacesAndNewlines), !tgRaw.isEmpty {
                        Divider()
                        Button {
                            let username = tgRaw.replacingOccurrences(of: "@", with: "")
                            guard let url = URL(string: "https://t.me/\(username)") else { return }
                            openURL(url)
                        } label: {
                            trainerActionRow(icon: "send-plane-horizontal", title: "Telegram", value: coachTelegramDisplay ?? "@\(tgRaw)")
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(AppDesign.cardPadding)
                .background(
                    RoundedRectangle(cornerRadius: AppDesign.cornerRadius, style: .continuous)
                        .fill(AppColors.secondarySystemGroupedBackground)
                        .shadow(color: AppColors.accent.opacity(0.08), radius: 12, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppDesign.cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [AppColors.accent.opacity(0.45), AppColors.profileAccent.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .padding(.bottom, 10)

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
                        title: "Календарь тренировок",
                        subtitle: "Посещения и события"
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }
        } else {
            ContentCard(
                title: "Мой тренер",
                description: trainerBlockDescription
            ) {
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

    private func trainerActionRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            AppTablerIcon(icon)
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .center)

            Text(title)
                .appTypography(.secondary)
                .foregroundStyle(AppColors.label)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(value)
                .appTypography(.secondary)
                .foregroundStyle(AppColors.secondaryLabel)
                .lineLimit(1)

            AppTablerIcon("upload-up")
                .foregroundStyle(AppColors.tertiaryLabel)
                .frame(width: 18, alignment: .trailing)
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
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
