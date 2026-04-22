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
                VStack(spacing: 20) {
                    AppTablerIcon("tag")
                        .appIcon(.s56)
                        .foregroundStyle(AppColors.accent)
                        .symbolRenderingMode(.hierarchical)
                        .padding(.top, 12)

                    Text("Оформим абонемент для \(traineeName)?")
                        .appTypography(.numericMetric)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)

                    Text("Один абонемент — порядок в посещениях: остаток занятий, безлимит на срок, календарь и история. Клиент видит то же в дневнике.")
                        .appTypography(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .lineSpacing(3)

                    VStack(alignment: .leading, spacing: 12) {
                        offerRow(
                            icon: "tag",
                            title: "По посещениям",
                            subtitle: "8 / 12 занятий и меньше — отмечаете занятие, счётчик уменьшается."
                        )
                        offerRow(
                            icon: "calendar-filled",
                            title: "Безлимит",
                            subtitle: "Фиксированный период — удобно для полного доступа или пакета тренировок."
                        )
                        offerRow(
                            icon: "check-tick-circle",
                            title: "Контроль",
                            subtitle: "Заморозка, разовые визиты, отчёты — остаются под рукой в карточке клиента."
                        )
                    }
                    .padding(.horizontal, AppDesign.cardPadding)

                    Spacer(minLength: 12)

                    OfferCTAButton(title: "Создать абонемент", action: onCreateMembership)

                    Button(action: onSkip) {
                        Text("Настрою позже")
                            .appTypography(.secondary)
                            .foregroundStyle(AppColors.secondaryLabel)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 28)
                }
            }
            .background(AdaptiveScreenBackground())
            .navigationTitle("Следующий шаг")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func offerRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            AppTablerIcon(icon)
                .appTypography(.screenTitle)
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
