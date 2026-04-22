//
//  NutritionInputComponents.swift
//  TrainLog
//

import SwiftUI
import Foundation

struct NutritionPreviewModel: Equatable {
    let proteinGrams: Double
    let fatGrams: Double
    let carbsGrams: Double
    let calories: Int
    let proteinPercent: Int
    let fatPercent: Int
    let carbsPercent: Int

    init(weightKg: Double, proteinPerKg: Double, fatPerKg: Double, carbsPerKg: Double) {
        proteinGrams = proteinPerKg * weightKg
        fatGrams = fatPerKg * weightKg
        carbsGrams = carbsPerKg * weightKg

        let proteinCalories = proteinGrams * 4
        let fatCalories = fatGrams * 9
        let carbsCalories = carbsGrams * 4
        let totalCalories = max(1, proteinCalories + fatCalories + carbsCalories)

        calories = Int(totalCalories.rounded())
        proteinPercent = Int((proteinCalories / totalCalories * 100).rounded())
        fatPercent = Int((fatCalories / totalCalories * 100).rounded())
        carbsPercent = max(0, 100 - proteinPercent - fatPercent)
    }
}

struct MacroTripleInputRow: View {
    @Binding var proteinPerKg: Double
    @Binding var fatPerKg: Double
    @Binding var carbsPerKg: Double

    @State private var proteinText: String = ""
    @State private var fatText: String = ""
    @State private var carbsText: String = ""

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            macroDecimalInput(
                title: "Белки, г/кг",
                color: AppColors.genderMale,
                text: $proteinText,
                value: $proteinPerKg
            )
            macroDecimalInput(
                title: "Жиры, г/кг",
                color: AppColors.visitsOneTimeDebt,
                text: $fatText,
                value: $fatPerKg
            )
            macroDecimalInput(
                title: "Углеводы, г/кг",
                color: AppColors.visitsBySubscription,
                text: $carbsText,
                value: $carbsPerKg
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func macroDecimalInput(
        title: String,
        color: Color,
        text: Binding<String>,
        value: Binding<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .appTypography(.caption)
                .foregroundStyle(color)

            TextField("0.1", text: text)
                .keyboardType(.decimalPad)
                .textFieldStyle(.plain)
                .appTypography(.bodyEmphasis)
                .multilineTextAlignment(.leading)
                .formInputStyle()
                .onAppear {
                    // Начальная синхронизация: текст = текущее значение.
                    if text.wrappedValue.isEmpty {
                        text.wrappedValue = max(0.1, value.wrappedValue).measurementFormatted
                    }
                }
                .onChange(of: text.wrappedValue) { _, newValue in
                    let sanitized = sanitizeDecimalInput(newValue)
                    if sanitized != newValue {
                        text.wrappedValue = sanitized
                        return
                    }
                    guard let d = Double(sanitized) else { return }
                    // Не округляем и не переписываем текст в том же onChange,
                    // чтобы не ловить "обновление несколько раз за один frame"
                    // и лишние циклы UI-обновлений.
                    value.wrappedValue = max(0, d)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sanitizeDecimalInput(_ raw: String) -> String {
        var s = raw.replacingOccurrences(of: ",", with: ".")
        s = s.filter { $0.isNumber || $0 == "." }
        // Разрешаем только одну точку.
        if let firstDot = s.firstIndex(of: ".") {
            let after = s[s.index(after: firstDot)...]
            let cleanedAfter = after.replacingOccurrences(of: ".", with: "")
            s = String(s[..<s.index(after: firstDot)]) + cleanedAfter
        }
        return s
    }
}

struct MacroRatioDonutView: View {
    let proteinPercent: Int
    let fatPercent: Int
    let carbsPercent: Int

    var size: CGFloat = 92
    var lineWidth: CGFloat = 16

    /// Если не задано — показываем "процент белков" и метку "Б" (как в превью).
    var centerPrimaryText: String? = nil
    /// Если `centerPrimaryText` задан — обычно сюда кладут единицы ("ккал", ...).
    var centerSecondaryText: String? = nil

    var centerPrimaryFont: Font? = nil
    var centerSecondaryFont: Font? = nil

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppColors.tertiarySystemFill, lineWidth: lineWidth)

            CircleSegment(
                color: AppColors.genderMale,
                start: 0,
                end: Double(proteinPercent) / 100,
                lineWidth: lineWidth
            )
            CircleSegment(
                color: AppColors.visitsOneTimeDebt,
                start: Double(proteinPercent) / 100,
                end: Double(proteinPercent + fatPercent) / 100,
                lineWidth: lineWidth
            )
            CircleSegment(
                color: AppColors.visitsBySubscription,
                start: Double(proteinPercent + fatPercent) / 100,
                end: 1,
                lineWidth: lineWidth
            )

            VStack(spacing: 2) {
                Text(centerPrimaryText ?? "\(proteinPercent)%")
                    .font(centerPrimaryFont ?? .subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.label)

                if let centerSecondaryText {
                    Text(centerSecondaryText)
                        .font(centerSecondaryFont ?? .caption.weight(.semibold))
                        .foregroundStyle(AppColors.secondaryLabel)
                } else {
                    Text("Б")
                        .font(centerSecondaryFont ?? .caption.weight(.semibold))
                        .foregroundStyle(AppColors.secondaryLabel)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

struct NutritionPreviewCard: View {
    let preview: NutritionPreviewModel

    var body: some View {
        VStack(alignment: .center, spacing: 14) {
            MacroRatioDonutView(
                proteinPercent: preview.proteinPercent,
                fatPercent: preview.fatPercent,
                carbsPercent: preview.carbsPercent,
                size: 132,
                lineWidth: 18,
                centerPrimaryText: "\(preview.calories)",
                centerSecondaryText: "ккал",
                centerPrimaryFont: .system(size: 36, weight: .semibold),
                centerSecondaryFont: .system(size: 12, weight: .semibold)
            )
            .padding(.top, 2)

            HStack(spacing: 10) {
                percentStatItem(title: "Белки", color: AppColors.genderMale, percent: preview.proteinPercent)
                percentStatItem(title: "Жиры", color: AppColors.visitsOneTimeDebt, percent: preview.fatPercent)
                percentStatItem(title: "Углеводы", color: AppColors.visitsBySubscription, percent: preview.carbsPercent)
            }

            MetricRowCompact(
                items: [
                    InfoValueItem(title: "Белки", value: "\(preview.proteinGrams.measurementFormatted) г", accentColor: AppColors.genderMale),
                    InfoValueItem(title: "Жиры", value: "\(preview.fatGrams.measurementFormatted) г", accentColor: AppColors.visitsOneTimeDebt),
                    InfoValueItem(title: "Углеводы", value: "\(preview.carbsGrams.measurementFormatted) г", accentColor: AppColors.visitsBySubscription),
                ],
                style: .colored
            )
        }
    }

    private func percentStatItem(title: String, color: Color, percent: Int) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .appTypography(.caption)
                .foregroundStyle(color)
            Text("\(percent)%")
                .appTypography(.caption)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: 10))
    }

}

private struct CircleSegment: View {
    let color: Color
    let start: Double
    let end: Double
    let lineWidth: CGFloat

    var body: some View {
        Circle()
            .trim(from: max(0, min(1, start)), to: max(0, min(1, end)))
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(-90))
    }
}

private extension Double {
    /// Округляем до 0.1 для Stepper(с шагом 0.1).
    var formattedStep1: String {
        let v = (self * 10).rounded() / 10
        return v.measurementFormatted
    }

    var roundedTo0_1: Double {
        (self * 10).rounded() / 10
    }
}
