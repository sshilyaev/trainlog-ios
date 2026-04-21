//
//  PostRegistrationOnboardingViews.swift
//  TrainLog
//

import SwiftUI

// MARK: - Онбординг тренера после регистрации

/// Показывается сразу после регистрации тренера: предложить добавить первого подопечного.
struct CoachPostRegistrationOnboardingView: View {
    let userName: String
    let onAddTrainee: () -> Void
    let onSkip: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.accent.opacity(0.22), AppColors.accent.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 120)
                        HStack(spacing: 20) {
                            coachVisualPillar(icon: "user-default", caption: "Клиент")
                            coachVisualPillar(icon: "calendar-filled", caption: "График")
                            coachVisualPillar(icon: "tag", caption: "Абонемент")
                        }
                    }
                    .padding(.horizontal, AppDesign.cardPadding)
                    .padding(.top, 8)

                    AppTablerIcon("user-default")
                        .appIcon(.s56)
                        .foregroundStyle(AppColors.accent)
                        .symbolRenderingMode(.hierarchical)
                        .padding(.top, 4)

                    Text("Первый шаг — клиент в списке")
                        .appTypography(.numericMetric)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)

                    Text("Добавьте подопечного за минуту: по коду из приложения или вручную. Дальше — абонемент, посещения и прогресс в одном месте.")
                        .appTypography(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .lineSpacing(3)

                    VStack(alignment: .leading, spacing: 10) {
                        featureRow(icon: "token", title: "По коду", subtitle: "Клиент открывает дневник → «Подключить по коду» → вы вводите код — готово.")
                        featureRow(icon: "plus-square", title: "Вручную", subtitle: "Клиент без приложения — создайте профиль и ведите учёт сами, потом можно объединить.")
                        featureRow(icon: "chart-area-line", title: "Дальше", subtitle: "Сразу после добавления настроим абонемент — так удобнее отмечать занятия.")
                    }
                    .padding(.horizontal, AppDesign.cardPadding)

                    Spacer(minLength: 16)

                    CTAButton(title: "Добавить подопечного", action: onAddTrainee)

                    Button(action: onSkip) {
                        Text("Сначала осмотрю приложение")
                            .appTypography(.secondary)
                            .foregroundStyle(AppColors.secondaryLabel)
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 28)
                }
            }
            .background(AdaptiveScreenBackground())
            .navigationTitle("Добро пожаловать, \(userName)")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func coachVisualPillar(icon: String, caption: String) -> some View {
        VStack(spacing: 8) {
            AppTablerIcon(icon)
                .appIcon(.s28)
                .foregroundStyle(AppColors.accent)
                .frame(width: 52, height: 52)
                .background(AppColors.secondarySystemGroupedBackground.opacity(0.9), in: Circle())
            Text(caption)
                .appTypography(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
        }
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            AppTablerIcon(icon)
                .appTypography(.numericMetric)
                .foregroundStyle(AppColors.accent)
                .frame(width: 28, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .appTypography(.bodyEmphasis)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .appTypography(.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
    }
}

// MARK: - Онбординг подопечного (дневник) после регистрации

/// Показывается сразу после регистрации подопечного: замеры/цели/достижения.
struct TraineePostRegistrationOnboardingView: View {
    let userName: String
    let onAddMeasurementsGoals: () -> Void
    let onAddAchievement: () -> Void
    let onSkip: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    traineeProgressVisualStrip
                        .padding(.horizontal, AppDesign.cardPadding)
                        .padding(.top, 8)

                    AppTablerIcon("note.text")
                        .appIcon(.s56)
                        .foregroundStyle(AppColors.accent)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 88, height: 88)
                        .background(AppColors.secondarySystemGroupedBackground, in: Circle())

                    Text("Заполните дневник за 2 минуты")
                        .appTypography(.numericMetric)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)

                    Text("Замеры и цели открываются в одном окне — удобно внести вес, объёмы и целевые даты. Достижения фиксируют лучшие веса, разы и времена по упражнениям.")
                        .appTypography(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .lineSpacing(3)

                    VStack(alignment: .leading, spacing: 10) {
                        featureRow(icon: "pencil-scale", title: "Замеры и цели", subtitle: "Один шаг — графики и прогресс сразу осмысленные.")
                        featureRow(icon: "award-medal", title: "Достижения", subtitle: "Личные рекорды по упражнениям — видно, куда вы растёте.")
                        featureRow(icon: "chart-area-line", title: "Всё на вкладке «Прогресс»", subtitle: "Потом можно дополнять в любой момент.")
                    }
                    .padding(.horizontal, AppDesign.cardPadding)

                    Spacer(minLength: 16)

                    VStack(spacing: 10) {
                        CTAButton(title: "Замеры и цели", action: onAddMeasurementsGoals)
                        CTAButton(title: "Добавить достижение", action: onAddAchievement)
                    }

                    Button(action: onSkip) {
                        Text("Сделаю позже")
                            .appTypography(.secondary)
                            .foregroundStyle(AppColors.secondaryLabel)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 28)
                }
            }
            .background(AdaptiveScreenBackground())
            .navigationTitle("Добро пожаловать, \(userName)")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var traineeProgressVisualStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                AppTablerIcon("chart-area-line")
                    .appTypography(.caption)
                    .foregroundStyle(AppColors.accent)
                Text("Как будет считаться прогресс")
                    .appTypography(.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
            }

            HStack(spacing: 0) {
                stripSegment(
                    color: AppColors.accent.opacity(0.85),
                    height: 44,
                    title: "Старт"
                )
                stripSegment(
                    color: AppColors.visitsOneTimePaid.opacity(0.9),
                    height: 30,
                    title: "Цель"
                )
                stripSegment(
                    color: AppColors.visitsBySubscription.opacity(0.85),
                    height: 36,
                    title: "Результат"
                )
            }
            .frame(height: 48)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: 14))
    }

    private func stripSegment(color: Color, height: CGFloat, title: String) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(maxWidth: .infinity)
                .frame(height: height)
            Text(title)
                .appTypography(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
        }
        .padding(.horizontal, 3)
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            AppTablerIcon(icon)
                .appTypography(.numericMetric)
                .foregroundStyle(AppColors.accent)
                .frame(width: 28, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .appTypography(.bodyEmphasis)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .appTypography(.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
    }
}

// MARK: - Оффер после создания целей

/// Показывается после сохранения целей: предложить сразу внести первый замер.
struct GoalCreatedMeasurementOfferView: View {
    let onAddMeasurement: () -> Void
    let onSkip: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    HStack(spacing: 0) {
                        stripBar(AppColors.accent.opacity(0.75), 32)
                        stripBar(AppColors.accent.opacity(0.45), 20)
                        stripBar(AppColors.accent.opacity(0.3), 26)
                    }
                    .frame(height: 40)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
                    .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, AppDesign.cardPadding)
                    .padding(.top, 12)

                    AppTablerIcon("pencil-scale")
                        .appIcon(.s56)
                        .foregroundStyle(AppColors.accent)
                        .symbolRenderingMode(.hierarchical)

                    Text("Закрепим старт с замерами")
                        .appTypography(.numericMetric)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)

                    Text("Цели уже есть — добавьте текущий вес и объёмы в том же окне с переключателем «Замеры / Цели», и графики сразу покажут динамику.")
                        .appTypography(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .lineSpacing(3)

                    Spacer(minLength: 12)

                    CTAButton(title: "Открыть замеры и цели", action: onAddMeasurement)

                    Button(action: onSkip) {
                        Text("Позже")
                            .appTypography(.secondary)
                            .foregroundStyle(AppColors.secondaryLabel)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 28)
                }
            }
            .background(AdaptiveScreenBackground())
            .navigationTitle("Дальше")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func stripBar(_ color: Color, _ h: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(color)
            .frame(maxWidth: .infinity)
            .frame(height: h)
            .padding(.horizontal, 3)
    }
}
