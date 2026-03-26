//
//  NutritionPlanComponents.swift
//  TrainLog
//

import SwiftUI

struct NutritionPlanCard: View {
    var title: String? = nil
    var subtitle: String? = nil
    let plan: NutritionPlan
    var accentColor: Color = AppColors.accent
    var actionTitle: String? = nil
    var onActionTap: (() -> Void)? = nil

    var body: some View {
        SettingsCard(title: title) {
            VStack(alignment: .center, spacing: 14) {
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.secondaryLabel)
                }

                // Graph (bigger) in center + calories in the middle.
                MacroRatioDonutView(
                    proteinPercent: plan.proteinPercent,
                    fatPercent: plan.fatPercent,
                    carbsPercent: plan.carbsPercent,
                    size: 132,
                    lineWidth: 18,
                    centerPrimaryText: "\(plan.calories)",
                    centerSecondaryText: "ккал",
                    centerPrimaryFont: .system(size: 36, weight: .semibold),
                    centerSecondaryFont: .system(size: 12, weight: .semibold)
                )
                .padding(.top, 2)

                // Percent line: color dot + percent.
                HStack(spacing: 10) {
                    percentStatItem(title: "Белки", color: AppColors.genderMale, percent: plan.proteinPercent)
                    percentStatItem(title: "Жиры", color: AppColors.visitsOneTimeDebt, percent: plan.fatPercent)
                    percentStatItem(title: "Углеводы", color: AppColors.visitsBySubscription, percent: plan.carbsPercent)
                }

                // One-line macros with colored labels/blocks.
                InfoValueTripleRow(
                    items: [
                        InfoValueItem(
                            title: "Белки",
                            value: "\(plan.proteinGrams.measurementFormatted) г",
                            accentColor: AppColors.genderMale
                        ),
                        InfoValueItem(
                            title: "Жиры",
                            value: "\(plan.fatGrams.measurementFormatted) г",
                            accentColor: AppColors.visitsOneTimeDebt
                        ),
                        InfoValueItem(
                            title: "Углеводы",
                            value: "\(plan.carbsGrams.measurementFormatted) г",
                            accentColor: AppColors.visitsBySubscription
                        )
                    ],
                    style: .colored
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Данные для расчёта:")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.secondaryLabel)
                    Text("Вес: \(plan.weightKgUsed.measurementFormatted) кг")
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                    Text("Белки: \(plan.proteinPerKg.measurementFormatted) г/кг · Жиры: \(plan.fatPerKg.measurementFormatted) г/кг · Углеводы: \(plan.carbsPerKg.measurementFormatted) г/кг")
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                    Text("Калорий: \(plan.calories)")
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)

                if let actionTitle, let onActionTap {
                    Button(action: onActionTap) {
                        Text(actionTitle)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 4)
                }
            }
        }
    }

    private func percentStatItem(title: String, color: Color, percent: Int) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            Text("\(percent)%")
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: 10))
    }

}

struct SupplementAssignmentRow: View {
    let assignment: TraineeSportsSupplementAssignment
    var showsDeleteAction: Bool = false
    var showsEditAction: Bool = false
    var showsActionsMenu: Bool = false
    var hintSide: InfoHintPopupSide = .right
    var contentHorizontalPadding: CGFloat = 12
    var contentVerticalPadding: CGFloat = 10
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    @State private var infoButtonFrame: CGRect = .zero

    var body: some View {
        ListActionRow(
            verticalPadding: contentVerticalPadding,
            horizontalPadding: contentHorizontalPadding,
            cornerRadius: 0,
            isInteractive: false
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    HStack(alignment: .center, spacing: 6) {
                        Text(assignment.supplementName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.label)

                        Button {
                            guard infoButtonFrame.width > 0, infoButtonFrame.height > 0 else { return }
                            InfoHintPopupPresenter.shared.show(
                                title: "Информация о добавке",
                                message: hintMessage,
                                anchorRect: infoButtonFrame,
                                preferredSide: hintSide
                            )
                        } label: {
                            AppTablerIcon("info.circle")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColors.secondaryLabel)
                        }
                        .buttonStyle(.plain)
                        .background(
                            GeometryReader { proxy in
                                Color.clear
                                    .preference(
                                        key: InfoButtonFramePreferenceKey.self,
                                        value: proxy.frame(in: .global)
                                    )
                            }
                        )
                    }
                    Spacer()
                }

                if hasAnyMeta {
                    supplementMetaGrid
                }

                if let note = cleaned(assignment.note), !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(AppColors.tertiaryLabel)
                        .padding(.top, 2)
                }
            }
            .onPreferenceChange(InfoButtonFramePreferenceKey.self) { frame in
                guard frame.width > 0, frame.height > 0 else { return }
                infoButtonFrame = frame
            }
        } trailing: {
            if showsActionsMenu {
                TiniActionButton(
                    color: AppColors.label,
                    font: .title3,
                    minWidth: 28,
                    minHeight: 28,
                    style: .plain
                ) {
                    if showsEditAction, let onEdit {
                        EditMenuAction(action: onEdit)
                    }
                    if showsDeleteAction, let onDelete {
                        DeleteMenuAction(action: onDelete)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var supplementMetaGrid: some View {
        let visibleItems: [InfoValueItem] = [
            cleaned(assignment.dosage).map { InfoValueItem(title: "Дозировка", value: $0) },
            cleaned(assignment.timing).map { InfoValueItem(title: "Время", value: $0) },
            cleaned(assignment.frequency).map { InfoValueItem(title: "Частота", value: $0) }
        ].compactMap { $0 }

        InfoValueTripleRow(
            items: visibleItems,
            style: .standard
        )
    }

    private func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var hasAnyMeta: Bool {
        cleaned(assignment.dosage) != nil
            || cleaned(assignment.timing) != nil
            || cleaned(assignment.frequency) != nil
    }

    private var hintMessage: String {
        let description = cleaned(assignment.supplementDescription) ?? "Описание отсутствует"
        return "Тип: \(assignment.supplementType.displayName)\n\(description)"
    }
}

private struct InfoButtonFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let candidate = nextValue()
        if candidate.width > 0, candidate.height > 0 {
            value = candidate
        }
    }
}

struct InfoValueItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let value: String
    var accentColor: Color? = nil
    /// Подсказка у заголовка (кнопка «i», тот же `InfoHintPopup`, что у спортивных добавок).
    var infoFootnote: String? = nil
    /// Заголовок всплывашки; если `nil` — только текст сообщения.
    var infoHintTitle: String? = nil
    /// Меньшая иконка «i», чтобы чип в ряду не казался выше соседних.
    var infoFootnoteCompactIcon: Bool = false
}

enum InfoValueTripleStyle {
    case standard
    case colored
}

enum InfoValueTripleChipSize {
    /// Как в карточках КБЖУ и прочих компактных сводках.
    case standard
    /// Крупнее: заголовок сводки на главной тренера и т.п.
    case large
    /// Компактная сводка тренера: по центру, одинаковая высота блоков, заголовок до 2 строк.
    case coachSummary
}

struct InfoValueTripleRow: View {
    let items: [InfoValueItem]
    var style: InfoValueTripleStyle = .standard
    var chipSize: InfoValueTripleChipSize = .standard

    private var rowSpacing: CGFloat {
        switch chipSize {
        case .standard: 8
        case .large: 10
        case .coachSummary: 6
        }
    }

    private var rowAlignment: VerticalAlignment {
        chipSize == .coachSummary ? .center : .top
    }

    private var rowFrameAlignment: Alignment {
        chipSize == .coachSummary ? .center : .leading
    }

    var body: some View {
        HStack(alignment: rowAlignment, spacing: rowSpacing) {
            ForEach(Array(items.prefix(3).enumerated()), id: \.offset) { _, item in
                InfoValueChip(item: item, style: style, chipSize: chipSize)
            }
            if items.count < 3 {
                ForEach(0..<(3 - items.count), id: \.self) { _ in
                    InfoValueChip(
                        item: InfoValueItem(title: "", value: ""),
                        style: style,
                        chipSize: chipSize,
                        isHiddenPlaceholder: true
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: rowFrameAlignment)
    }
}

private struct InfoValueChip: View {
    let item: InfoValueItem
    let style: InfoValueTripleStyle
    var chipSize: InfoValueTripleChipSize = .standard
    var isHiddenPlaceholder = false

    @State private var infoButtonFrame: CGRect = .zero

    /// Две строки подписи `caption` (~13 pt) для выравнивания высоты блоков сводки тренера.
    private var coachSummaryTitleMinHeight: CGFloat { 34 }

    private var infoFootnote: String? {
        let t = item.infoFootnote?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? nil : t
    }

    var body: some View {
        Group {
            switch chipSize {
            case .coachSummary:
                VStack(alignment: .center, spacing: 4) {
                    Text(item.title)
                        .font(.caption)
                        .foregroundStyle(titleColor)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: coachSummaryTitleMinHeight, alignment: .top)
                    Text(item.value)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppColors.label)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, minHeight: 72, alignment: .center)
            case .standard, .large:
                Group {
                    if let hint = infoFootnote, item.infoFootnoteCompactIcon {
                        ZStack(alignment: .topTrailing) {
                            VStack(alignment: .leading, spacing: chipSize == .large ? 4 : 2) {
                                Text(item.title)
                                    .font(titleFont)
                                    .foregroundStyle(titleColor)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.trailing, 22)
                                Text(item.value)
                                    .font(valueFont)
                                    .foregroundStyle(AppColors.label)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.85)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            infoFootnoteButton(hint)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: chipSize == .large ? 4 : 2) {
                            titleRowStandardOrLarge
                            Text(item.value)
                                .font(valueFont)
                                .foregroundStyle(AppColors.label)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: cornerRadius))
        .opacity(isHiddenPlaceholder ? 0 : 1)
        .onPreferenceChange(InfoButtonFramePreferenceKey.self) { frame in
            guard frame.width > 0, frame.height > 0 else { return }
            infoButtonFrame = frame
        }
    }

    @ViewBuilder
    private var titleRowStandardOrLarge: some View {
        if let hint = infoFootnote {
            HStack(alignment: item.infoFootnoteCompactIcon ? .center : .firstTextBaseline, spacing: item.infoFootnoteCompactIcon ? 3 : 4) {
                Text(item.title)
                    .font(titleFont)
                    .foregroundStyle(titleColor)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                infoFootnoteButton(hint)
            }
        } else {
            Text(item.title)
                .font(titleFont)
                .foregroundStyle(titleColor)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func infoFootnoteButton(_ text: String) -> some View {
        Button {
            guard infoButtonFrame.width > 0, infoButtonFrame.height > 0 else { return }
            InfoHintPopupPresenter.shared.show(
                title: item.infoHintTitle,
                message: text,
                anchorRect: infoButtonFrame,
                preferredSide: .right,
                width: 280
            )
        } label: {
            AppTablerIcon("info.circle")
                .font(
                    item.infoFootnoteCompactIcon
                        ? .caption2.weight(.semibold)
                        : .subheadline.weight(.semibold)
                )
                .foregroundStyle(AppColors.secondaryLabel)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Подробнее: \(item.title)")
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        key: InfoButtonFramePreferenceKey.self,
                        value: proxy.frame(in: .global)
                    )
            }
        )
    }

    private var horizontalPadding: CGFloat {
        switch chipSize {
        case .standard: 8
        case .large: 12
        case .coachSummary: 6
        }
    }

    private var verticalPadding: CGFloat {
        switch chipSize {
        case .standard: 6
        case .large: 10
        case .coachSummary: 7
        }
    }

    private var cornerRadius: CGFloat {
        switch chipSize {
        case .standard: 8
        case .large: 12
        case .coachSummary: 8
        }
    }

    private var titleFont: Font {
        switch chipSize {
        case .standard:
            return .caption2
        case .large:
            return .caption.weight(.semibold)
        case .coachSummary:
            return .caption
        }
    }

    private var valueFont: Font {
        switch chipSize {
        case .standard:
            return .caption.weight(.semibold)
        case .large:
            return .system(size: 26, weight: .bold, design: .rounded)
        case .coachSummary:
            return .system(size: 17, weight: .bold, design: .rounded)
        }
    }

    private var titleColor: Color {
        switch style {
        case .standard:
            return AppColors.tertiaryLabel
        case .colored:
            return item.accentColor ?? AppColors.tertiaryLabel
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .standard:
            return AppColors.tertiarySystemFill
        case .colored:
            return (item.accentColor ?? AppColors.tertiarySystemFill).opacity(0.12)
        }
    }
}
