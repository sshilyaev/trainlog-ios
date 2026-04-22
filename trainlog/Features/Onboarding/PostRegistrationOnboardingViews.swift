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
                    Image("CoachWelcomeIllustration")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 320)
                        .padding(.top, 8)

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
                        featureRow(icon: "users-group", title: "Добавлять подопечных", subtitle: "Подключайте клиентов по коду или создавайте профиль вручную.")
                        featureRow(icon: "calendar-check", title: "Вести посещения и абонементы", subtitle: "Отмечайте тренировки, контролируйте остатки и сроки абонементов.")
                        featureRow(icon: "chart-line", title: "Отслеживать прогресс", subtitle: "Смотрите динамику замеров и активности по каждому подопечному.")
                    }
                    .padding(.horizontal, AppDesign.cardPadding)

                    Spacer(minLength: 16)

                    OfferCTAButton(title: "Добавить подопечного", action: onAddTrainee)

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
                    Image("TraineeWelcomeIllustration")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 300)
                        .padding(.top, 8)

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
                        featureRow(icon: "calendar-event", title: "График тренировок", subtitle: "Отслеживайте расписание и отмечайте выполненные тренировки в календаре.")
                    }
                    .padding(.horizontal, AppDesign.cardPadding)

                    Spacer(minLength: 16)

                    VStack(spacing: 10) {
                        OfferCTAButton(title: "Замеры и цели", action: onAddMeasurementsGoals)
                        OfferCTAButton(title: "Добавить достижение", action: onAddAchievement)
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

                    OfferCTAButton(title: "Открыть замеры и цели", action: onAddMeasurement)

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
