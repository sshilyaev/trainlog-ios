import SwiftUI

struct MeasurementGuideView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                guideCard(
                    title: "Измеряйте в одно время",
                    subtitle: "Лучше утром или вечером в одинаковых условиях",
                    icon: "clock-default"
                )
                guideCard(
                    title: "Одна и та же точка",
                    subtitle: "Лента должна проходить по одной и той же зоне тела",
                    icon: "search-big"
                )
                guideCard(
                    title: "Ровная стойка",
                    subtitle: "Стойте прямо, без втягивания живота и напряжения мышц",
                    icon: "user-default"
                )
                guideCard(
                    title: "Стабильное натяжение",
                    subtitle: "Лента прилегает плотно, но не пережимает мягкие ткани",
                    icon: "pencil-scale"
                )
            }
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .background(AppColors.systemGroupedBackground)
        .navigationTitle("Как делать замеры")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func guideCard(title: String, subtitle: String, icon: String) -> some View {
        SettingsCard(title: nil) {
            HStack(alignment: .top, spacing: 12) {
                AppTablerIcon(icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 28, height: 28)
                    .background(AppColors.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(AppColors.secondaryLabel)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

