import SwiftUI

/// Полный список завершённых виртуальных клиентов (история спасений).
struct SupportCampaignHistoryView: View {
    let items: [SupportCampaignHistoryItem]

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    "Пока пусто",
                    image: "tabler-outline-heart-handshake",
                    description: Text("Когда виртуальный клиент достигнет цели, запись появится здесь.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(items) { item in
                            HStack(alignment: .top, spacing: 12) {
                                AppTablerIcon("circle-check")
                                    .foregroundStyle(AppColors.accent)
                                    .frame(width: 24, alignment: .center)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.goalType == .loseWeight ? "Снижение веса" : "Набор веса")
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(item.startWeightKg.formattedOneDecimal) → \(item.targetWeightKg.formattedOneDecimal) кг")
                                        .font(.caption)
                                        .foregroundStyle(AppColors.secondaryLabel)
                                    Text(item.createdAt.formattedRuDayMonth)
                                        .font(.caption2)
                                        .foregroundStyle(AppColors.tertiaryLabel)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(AppDesign.cardPadding)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
                        }
                    }
                    .padding(.horizontal, AppDesign.cardPadding)
                    .padding(.vertical, AppDesign.blockSpacing)
                }
            }
        }
        .background(AdaptiveScreenBackground())
        .navigationTitle("История спасений")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension Double {
    var formattedOneDecimal: String {
        String(format: "%.1f", self)
    }
}

#Preview {
    NavigationStack {
        SupportCampaignHistoryView(
            items: [
                SupportCampaignHistoryItem(
                    id: "1",
                    goalType: .loseWeight,
                    startWeightKg: 90,
                    targetWeightKg: 75,
                    createdAt: Date()
                )
            ]
        )
    }
}
