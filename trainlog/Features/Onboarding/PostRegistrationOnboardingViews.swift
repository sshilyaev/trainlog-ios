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
                VStack(spacing: 24) {
                    AppTablerIcon("user-default")
                        .appIcon(.s44)
                        .foregroundStyle(AppColors.accent)
                        .symbolRenderingMode(.hierarchical)
                        .padding(.top, 24)

                    Text("Добавьте первого подопечного")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text("В приложении вы сможете вести календарь посещений, создавать абонементы по занятиям или безлимит, смотреть замеры и цели клиента и отмечать тренировки.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 10) {
                        featureRow(icon: "token", title: "Подключение по коду", subtitle: "Клиент открывает свой дневник в приложении и даёт вам код — вы добавляете его одним нажатием.")
                        featureRow(icon: "plus-square", title: "Создать профиль вручную", subtitle: "Если клиент пока не в приложении — создайте профиль подопечного и ведите учёт сами.")
                        featureRow(icon: "tag", title: "Абонементы и посещения", subtitle: "После добавления можно сразу создать абонемент и отмечать занятия в календаре.")
                    }
                    .padding(.horizontal, AppDesign.cardPadding)

                    Spacer(minLength: 20)

                    CTAButton(title: "Добавить подопечного", action: onAddTrainee)

                    Button(action: onSkip) {
                        Text("Позже")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppColors.secondaryLabel)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 32)
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
                .font(.title3)
                .foregroundStyle(AppColors.accent)
                .frame(width: 28, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
    }
}

// MARK: - Онбординг подопечного (дневник) после регистрации

/// Показывается сразу после регистрации подопечного: предложить ввести цели и сообщить про замеры.
struct TraineePostRegistrationOnboardingView: View {
    let userName: String
    let onAddGoals: () -> Void
    let onAddMeasurement: () -> Void
    let onSkip: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    AppTablerIcon("user-default")
                        .appIcon(.s44)
                        .foregroundStyle(AppColors.accent)
                        .symbolRenderingMode(.hierarchical)
                        .padding(.top, 24)

                    Text("Настройте дневник под себя")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text("Добавьте цели по весу или объёмам — так удобнее следить за прогрессом на графиках. Замеры можно вносить в разделе «Мои замеры» в любое время.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            AppTablerIcon("map-pin")
                                .font(.title3)
                                .foregroundStyle(AppColors.accent)
                                .frame(width: 28, alignment: .center)
                            Text("Цели помогут видеть прогресс на графиках и не забывать о целевых датах.")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                        .padding(14)
                        .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))

                        HStack(alignment: .top, spacing: 12) {
                            AppTablerIcon("pencil-scale")
                                .font(.title3)
                                .foregroundStyle(AppColors.accent)
                                .frame(width: 28, alignment: .center)
                            Text("Замеры (вес, объёмы) добавляйте в разделе «Мои замеры» — там же графики и история.")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                        .padding(14)
                        .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
                    }
                    .padding(.horizontal, AppDesign.cardPadding)

                    Spacer(minLength: 20)

                    VStack(spacing: 12) {
                        CTAButton(title: "Добавить цели", action: onAddGoals)
                        CTAButton(title: "Добавить замер", action: onAddMeasurement)
                    }

                    Button(action: onSkip) {
                        Text("Понятно, позже")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppColors.secondaryLabel)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .background(AdaptiveScreenBackground())
            .navigationTitle("Добро пожаловать, \(userName)")
            .navigationBarTitleDisplayMode(.inline)
        }
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
                VStack(spacing: 24) {
                    AppTablerIcon("pencil-scale")
                        .appIcon(.s44)
                        .foregroundStyle(AppColors.accent)
                        .symbolRenderingMode(.hierarchical)
                        .padding(.top, 20)

                    Text("Добавить первый замер?")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Text("Цели уже сохранены. Теперь внесите текущие значения, чтобы прогресс на графиках считался сразу и корректно.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Spacer(minLength: 16)

                    CTAButton(title: "Добавить замер", action: onAddMeasurement)

                    Button(action: onSkip) {
                        Text("Позже")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppColors.secondaryLabel)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .background(AdaptiveScreenBackground())
            .navigationTitle("Замеры")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
