//
//  MembershipOfferView.swift
//  TrainLog
//

import SwiftUI

/// Продающая страница про абонементы: зачем нужны, какие бывают, что можно делать. Показывается после добавления подопечного (всегда — и новому тренеру, и существующему).
struct MembershipOfferView: View {
    let traineeName: String
    let onCreateMembership: () -> Void
    let onSkip: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    AppTablerIcon("tag")
                        .appIcon(.s44)
                        .foregroundStyle(AppColors.accent)
                        .symbolRenderingMode(.hierarchical)
                        .padding(.top, 20)

                    Text("Создать абонемент для \(traineeName)?")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Text("Абонементы помогают вести учёт посещений и не терять прогресс. Вы создаёте абонемент — клиент ходит, вы отмечаете занятия. Всё в одном месте.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 12) {
                        offerRow(
                            icon: "tag",
                            title: "По посещениям",
                            subtitle: "Например, 8 или 12 занятий. Отмечаете каждое посещение — остаток списывается автоматически"
                        )
                        offerRow(
                            icon: "calendar-filled",
                            title: "Безлимитный",
                            subtitle: "На срок: неделя, месяц или дольше. Удобно для неограниченного доступа в зал или к тренировкам"
                        )
                        offerRow(
                            icon: "check-tick-circle",
                            title: "Календарь и отчёты",
                            subtitle: "Все посещения в календаре подопечного, история по абонементам. Можно заморозить абонемент при необходимости"
                        )
                    }
                    .padding(.horizontal, AppDesign.cardPadding)

                    Spacer(minLength: 16)

                    CTAButton(title: "Создать абонемент", action: onCreateMembership)

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
            .navigationTitle("Абонемент")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") {
                        onSkip()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.secondaryLabel)
                }
            }
        }
    }

    private func offerRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            AppTablerIcon(icon)
                .font(.title2)
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
