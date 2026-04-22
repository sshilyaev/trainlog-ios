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
                        .appTypography(.secondary)
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
                MetricRowCompact(
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
                        .appTypography(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                    Text("Вес: \(plan.weightKgUsed.measurementFormatted) кг")
                        .appTypography(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                    Text("Белки: \(plan.proteinPerKg.measurementFormatted) г/кг · Жиры: \(plan.fatPerKg.measurementFormatted) г/кг · Углеводы: \(plan.carbsPerKg.measurementFormatted) г/кг")
                        .appTypography(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                    Text("Калорий: \(plan.calories)")
                        .appTypography(.caption)
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

enum SupplementAssignmentRowPresentation: Equatable {
    /// Каждая добавка в отдельном блоке: прозрачная подложка и обводка (дневник, просмотр у тренера).
    case card
    /// Строка списка с разделителем — без отдельной «карточки» на строку (редактор назначенных добавок).
    case listRow
}

struct SupplementAssignmentRow: View {
    let assignment: TraineeSportsSupplementAssignment
    var presentation: SupplementAssignmentRowPresentation = .card
    var showsDeleteAction: Bool = false
    var showsEditAction: Bool = false
    var showsActionsMenu: Bool = false
    var hintSide: InfoHintPopupSide = .right
    var contentHorizontalPadding: CGFloat = 12
    var contentVerticalPadding: CGFloat = 10
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    @State private var infoButtonFrame: CGRect = .zero

    private var cardStrokeColor: Color {
        AppColors.separator.opacity(0.4)
    }

    var body: some View {
        Group {
            switch presentation {
            case .card:
                cardChrome {
                    assignmentBody()
                }
            case .listRow:
                ListActionRow(
                    verticalPadding: contentVerticalPadding,
                    horizontalPadding: contentHorizontalPadding,
                    cornerRadius: 0,
                    isInteractive: false
                ) {
                    assignmentBody()
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
        }
    }

    @ViewBuilder
    private func cardChrome<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(contentHorizontalPadding)
            .padding(.vertical, contentVerticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(cardStrokeColor, lineWidth: 1)
            )
    }

    @ViewBuilder
    private func assignmentBody() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                HStack(alignment: .center, spacing: 6) {
                    Text(assignment.supplementName)
                        .appTypography(.bodyEmphasis)
                        .foregroundStyle(AppColors.label)
                        .multilineTextAlignment(.leading)

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
                            .appTypography(.bodyEmphasis)
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
                Spacer(minLength: 0)
            }

            if hasAnyMeta {
                supplementMetaLayout
            }

            if let note = cleaned(assignment.note), !note.isEmpty {
                supplementLabeledField(title: "Заметка", value: note)
            }
        }
        .onPreferenceChange(InfoButtonFramePreferenceKey.self) { frame in
            guard frame.width > 0, frame.height > 0 else { return }
            infoButtonFrame = frame
        }
    }

    @ViewBuilder
    private var supplementMetaLayout: some View {
        let dosage = dosageDisplayText
        let frequency = cleaned(assignment.frequency)
        let timing = cleaned(assignment.timing)

        if dosage != nil || frequency != nil {
            HStack(alignment: .top, spacing: 12) {
                if let dosage {
                    supplementLabeledField(title: "Дозировка", value: dosage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let frequency {
                    supplementLabeledField(title: "Частота", value: frequency)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }

        if let timing {
            supplementLabeledField(title: "Время приёма", value: timing)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func supplementLabeledField(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .appTypography(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
            Text(value)
                .appTypography(.secondary)
                .foregroundStyle(AppColors.label)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var hasAnyMeta: Bool {
        dosageDisplayText != nil
            || cleaned(assignment.timing) != nil
            || cleaned(assignment.frequency) != nil
    }

    private var dosageDisplayText: String? {
        let value = cleaned(assignment.dosageValue)
        let unit = assignment.dosageUnit?.displayName
        if let value, let unit, !unit.isEmpty {
            return "\(value) \(unit)"
        }
        if let value { return value }
        return cleaned(assignment.dosage)
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
    var icon: String? = nil
    var description: String? = nil
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
    /// Сводка дневника: та же фиксированная высота, но более спокойные значения.
    case diarySummary
}

struct InfoValueTripleRow: View {
    let items: [InfoValueItem]
    var style: InfoValueTripleStyle = .standard
    var chipSize: InfoValueTripleChipSize = .standard
    var customBackgroundColor: Color? = nil
    var customTextColor: Color? = nil
    /// Для кастомного цвета подложки используем фиксированную прозрачность.
    var customBackgroundOpacity: Double = 0.14
    var compactDescriptionLineLimit: Int = 2
    var compactValueWeight: Font.Weight = .semibold
    var compactFixedMinHeight: CGFloat? = nil
    var compactCenterContent: Bool = false
    var alignCompactValueToTitle: Bool = false

    private var maxColumns: Int {
        items.count <= 2 ? 2 : 3
    }

    private var rowSpacing: CGFloat {
        switch chipSize {
        case .standard: 8
        case .large: 10
        case .coachSummary, .diarySummary: 6
        }
    }

    private var rowAlignment: VerticalAlignment {
        (chipSize == .coachSummary || chipSize == .diarySummary) ? .center : .top
    }

    private var rowFrameAlignment: Alignment {
        (chipSize == .coachSummary || chipSize == .diarySummary) ? .center : .leading
    }

    var body: some View {
        HStack(alignment: rowAlignment, spacing: rowSpacing) {
            ForEach(Array(items.prefix(maxColumns).enumerated()), id: \.offset) { _, item in
                InfoValueChip(
                    item: item,
                    style: style,
                    chipSize: chipSize,
                    customBackgroundColor: customBackgroundColor,
                    customTextColor: customTextColor,
                    customBackgroundOpacity: customBackgroundOpacity,
                    compactDescriptionLineLimit: compactDescriptionLineLimit,
                    compactValueWeight: compactValueWeight,
                    compactFixedMinHeight: compactFixedMinHeight,
                    compactCenterContent: compactCenterContent,
                    alignCompactValueToTitle: alignCompactValueToTitle
                )
            }
            if items.count < maxColumns {
                ForEach(0..<(maxColumns - items.count), id: \.self) { _ in
                    InfoValueChip(
                        item: InfoValueItem(title: "", value: ""),
                        style: style,
                        chipSize: chipSize,
                        customBackgroundColor: customBackgroundColor,
                        customTextColor: customTextColor,
                        customBackgroundOpacity: customBackgroundOpacity,
                        compactDescriptionLineLimit: compactDescriptionLineLimit,
                        compactValueWeight: compactValueWeight,
                        compactFixedMinHeight: compactFixedMinHeight,
                        compactCenterContent: compactCenterContent,
                        alignCompactValueToTitle: alignCompactValueToTitle,
                        isHiddenPlaceholder: true
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: rowFrameAlignment)
    }
}

/// Унифицированный крупный ряд метрик: центр, 2 или 3 колонки.
struct MetricRowLarge: View {
    let items: [InfoValueItem]
    var backgroundColor: Color? = nil
    var textColor: Color? = nil

    var body: some View {
        InfoValueTripleRow(
            items: items,
            style: .standard,
            chipSize: .coachSummary,
            customBackgroundColor: backgroundColor,
            customTextColor: textColor
        )
    }
}

/// Базовый компактный ряд метрик.
struct MetricRowCompact: View {
    let items: [InfoValueItem]
    var style: InfoValueTripleStyle = .standard
    var backgroundColor: Color? = nil
    var textColor: Color? = nil

    var body: some View {
        InfoValueTripleRow(
            items: items,
            style: style,
            chipSize: .standard,
            customBackgroundColor: backgroundColor,
            customTextColor: textColor
        )
    }
}

/// Расширенный компактный ряд метрик: иконка, описание, настраиваемая жирность значения.
struct MetricRowCompactExtended: View {
    let items: [InfoValueItem]
    var style: InfoValueTripleStyle = .standard
    var backgroundColor: Color? = nil
    var textColor: Color? = nil
    var valueWeight: Font.Weight = .bold
    var descriptionLineLimit: Int = 3

    var body: some View {
        InfoValueTripleRow(
            items: items,
            style: style,
            chipSize: .standard,
            customBackgroundColor: backgroundColor,
            customTextColor: textColor,
            compactDescriptionLineLimit: descriptionLineLimit,
            compactValueWeight: valueWeight,
            compactFixedMinHeight: 96,
            compactCenterContent: true,
            alignCompactValueToTitle: true
        )
    }
}

private struct InfoValueChip: View {
    let item: InfoValueItem
    let style: InfoValueTripleStyle
    var chipSize: InfoValueTripleChipSize = .standard
    var customBackgroundColor: Color? = nil
    var customTextColor: Color? = nil
    var customBackgroundOpacity: Double = 0.14
    var compactDescriptionLineLimit: Int = 2
    var compactValueWeight: Font.Weight = .semibold
    var compactFixedMinHeight: CGFloat? = nil
    var compactCenterContent: Bool = false
    var alignCompactValueToTitle: Bool = false
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
                metricLargeContent
            case .diarySummary:
                metricLargeContent
            case .standard, .large:
                Group {
                    if let hint = infoFootnote, item.infoFootnoteCompactIcon {
                        ZStack(alignment: .topTrailing) {
                            VStack(alignment: .leading, spacing: chipSize == .large ? 4 : 2) {
                                titleWithOptionalIcon
                                    .padding(.trailing, 22)
                                if !item.value.isEmpty {
                                    Text(item.value)
                                        .font(valueFont)
                                        .foregroundStyle(AppColors.label)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.85)
                                        .padding(.leading, compactValueLeadingInset)
                                }
                                if let description = item.description, !description.isEmpty {
                                    Text(description)
                                        .appTypography(.caption)
                                        .foregroundStyle(AppColors.secondaryLabel)
                                        .lineLimit(compactDescriptionLineLimit)
                                        .padding(.leading, compactValueLeadingInset)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(
                                minHeight: compactFixedMinHeight,
                                alignment: compactCenterContent ? .center : .topLeading
                            )
                            infoFootnoteButton(hint)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: chipSize == .large ? 4 : 2) {
                            titleRowStandardOrLarge
                            if !item.value.isEmpty {
                                Text(item.value)
                                    .font(valueFont)
                                    .foregroundStyle(AppColors.label)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.85)
                                    .padding(.leading, compactValueLeadingInset)
                            }
                            if let description = item.description, !description.isEmpty {
                                Text(description)
                                    .appTypography(.caption)
                                    .foregroundStyle(AppColors.secondaryLabel)
                                    .lineLimit(compactDescriptionLineLimit)
                                    .padding(.leading, compactValueLeadingInset)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(
                            minHeight: compactFixedMinHeight,
                            alignment: compactCenterContent ? .center : .topLeading
                        )
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
                titleWithOptionalIcon
                infoFootnoteButton(hint)
            }
        } else {
            titleWithOptionalIcon
        }
    }

    @ViewBuilder
    private var titleWithOptionalIcon: some View {
        if let icon = item.icon, !icon.isEmpty {
            HStack(spacing: 4) {
                AppTablerIcon(icon)
                    .appTypography(.caption)
                    .foregroundStyle(titleColor)
                Text(item.title)
                    .font(titleFont)
                    .foregroundStyle(titleColor)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
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
        case .coachSummary, .diarySummary: 6
        }
    }

    private var verticalPadding: CGFloat {
        switch chipSize {
        case .standard: 6
        case .large: 10
        case .coachSummary, .diarySummary: 4
        }
    }

    private var cornerRadius: CGFloat {
        switch chipSize {
        case .standard: 8
        case .large: 12
        case .coachSummary, .diarySummary: 8
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
        case .diarySummary:
            return .caption
        }
    }

    private var valueFont: Font {
        switch chipSize {
        case .standard:
            return .caption.weight(compactValueWeight)
        case .large:
            return .system(size: 26, weight: .bold, design: .rounded)
        case .coachSummary:
            return .system(size: 14, weight: .semibold, design: .rounded)
        case .diarySummary:
            return .system(size: 14, weight: .semibold, design: .rounded)
        }
    }

    private var titleColor: Color {
        if let customTextColor {
            return customTextColor
        }
        switch style {
        case .standard:
            return AppColors.tertiaryLabel
        case .colored:
            return (chipSize == .coachSummary || chipSize == .diarySummary)
                ? AppColors.tertiaryLabel
                : (item.accentColor ?? AppColors.tertiaryLabel)
        }
    }

    private var backgroundColor: Color {
        if let customBackgroundColor {
            return customBackgroundColor.opacity(customBackgroundOpacity)
        }
        switch style {
        case .standard:
            return AppColors.tertiarySystemFill
        case .colored:
            return (chipSize == .coachSummary || chipSize == .diarySummary)
                ? AppColors.tertiarySystemFill
                : (item.accentColor ?? AppColors.tertiarySystemFill).opacity(0.12)
        }
    }

    private var metricLargeContent: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(item.title)
                .fontSystemWithAppExtra(size: 12, weight: .regular)
                .foregroundStyle(AppColors.tertiaryLabel)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, infoFootnote == nil ? 0 : 12)
                .frame(minHeight: coachSummaryTitleMinHeight, alignment: .top)
            Text(item.value)
                .fontSystemWithAppExtra(size: 14, weight: .semibold, design: .rounded)
                .foregroundStyle(customTextColor ?? AppColors.label)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .center)
        .overlay(alignment: .topTrailing) {
            if let hint = infoFootnote {
                infoFootnoteButton(hint)
                    .padding(.top, 1)
                    .padding(.trailing, 1)
            }
        }
    }

    private var compactValueLeadingInset: CGFloat {
        guard alignCompactValueToTitle else { return 0 }
        guard let icon = item.icon, !icon.isEmpty else { return 0 }
        return 16
    }
}
