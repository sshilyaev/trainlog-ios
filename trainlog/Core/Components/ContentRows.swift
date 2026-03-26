import SwiftUI

/// Контент одной прямоугольной плитки: иконка, заголовок, опционально значение.
/// Используется внутри `NavigationLink/Button` вместе с `.rectangularBlockStyle()`.
struct RectangularBlockContent: View {
    let icon: String
    let title: String
    var value: String? = nil
    var iconColor: Color = AppColors.profileAccent

    var body: some View {
        VStack(spacing: AppDesign.blockSpacing) {
            AppTablerIcon(icon)
                .font(.title2)
                .foregroundStyle(iconColor)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            if let value, !value.isEmpty {
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppDesign.cardPadding)
        .padding(.horizontal, AppDesign.rowSpacing)
        .contentShape(Rectangle())
    }
}

