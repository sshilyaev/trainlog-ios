import SwiftUI

// MARK: - Small menu actions (tap + раскрывающийся список)

enum TiniActionButtonStyle {
    case plain
    case borderless
    case pressable
}

private struct TiniActionIconLabel: View {
    var color: Color = AppColors.label
    var font: Font = .title3
    var minWidth: CGFloat = 40
    var minHeight: CGFloat = 40

    var body: some View {
        AppTablerIcon("sidebar-menu")
            .font(font)
            .foregroundStyle(color)
            .frame(minWidth: minWidth, minHeight: minHeight)
            .contentShape(Rectangle())
    }
}

struct TiniActionButton<MenuContent: View>: View {
    var color: Color = AppColors.label
    var font: Font = .title3
    var minWidth: CGFloat = 40
    var minHeight: CGFloat = 40
    var style: TiniActionButtonStyle = .plain
    @ViewBuilder var menuContent: () -> MenuContent

    var body: some View {
        Menu {
            menuContent()
        } label: {
            TiniActionIconLabel(
                color: color,
                font: font,
                minWidth: minWidth,
                minHeight: minHeight
            )
        }
        .modifier(TiniMenuButtonStyleModifier(style: style))
    }
}

private struct TiniMenuButtonStyleModifier: ViewModifier {
    let style: TiniActionButtonStyle

    func body(content: Content) -> some View {
        switch style {
        case .plain:
            content.buttonStyle(.plain)
        case .borderless:
            content.buttonStyle(.borderless)
        case .pressable:
            content.buttonStyle(PressableButtonStyle())
        }
    }
}

// MARK: - Main CTA (tap)

/// Единая CTA-кнопка для онбординга и офферов (не на всю ширину): по центру, фиксированная ширина, скругление 8.
struct CTAButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .appTypography(.button)
                .foregroundStyle(AppColors.white)
                .frame(minWidth: 200, maxWidth: 280)
                .frame(height: 46)
                .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

/// Продающая CTA для welcome/offer экранов: яркий градиент, большая зона нажатия.
struct OfferCTAButton: View {
    let title: String
    var isLoading: Bool = false
    var minWidth: CGFloat = 220
    var maxWidth: CGFloat = 320
    let action: () -> Void

    private let start = Color(red: 74/255, green: 172/255, blue: 144/255)
    private let end = Color(red: 79/255, green: 84/255, blue: 171/255)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.9)
                }
                Text(title)
                    .appTypography(.button)
                    .foregroundStyle(AppColors.white)
            }
            .frame(minWidth: minWidth, maxWidth: maxWidth)
            .frame(minHeight: 48)
            .background(
                LinearGradient(colors: [start, end], startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle(cornerRadius: 12))
    }
}

/// Основная кнопка для действий с сервером: Войти, Сохранить, Создать, Обновить.
struct MainActionButton: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isLoading {
                ProgressView()
                    .tint(AppColors.white)
            } else {
                Text(title)
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(isLoading || isDisabled)
    }
}

/// Единая настройка отступов/размеров для action-кнопок.
struct ActionButtonLayout: Hashable {
    /// Внутренние отступы (внутри хрома/фона).
    var contentPaddingHorizontal: CGFloat
    var contentPaddingVertical: CGFloat

    /// Внешний вертикальный отступ (снаружи, чтобы кнопки не слипались в списках).
    var outerPaddingVertical: CGFloat

    /// Минимальная высота.
    var minHeight: CGFloat

    static let wideDefault = ActionButtonLayout(
        contentPaddingHorizontal: 12,
        contentPaddingVertical: 3,
        outerPaddingVertical: 3,
        minHeight: 44
    )

    static let bigDefault = ActionButtonLayout(
        contentPaddingHorizontal: 12,
        contentPaddingVertical: 5,
        outerPaddingVertical: 3,
        minHeight: 78
    )
}

/// Компактный статус справа у action-кнопок (например: "Активно", "Скоро", "3").
struct ActionStatusChip: View {
    let title: String
    var color: Color = AppColors.accent

    var body: some View {
        Text(title)
            .appTypography(.caption)
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.14), in: Capsule())
    }
}

// MARK: - Shared chrome (3D + border)

/// Заливка + лёгкий вертикальный блик (общая для всех вариантов хрома).
private struct ActionButtonChromeFill: View {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let topTint = colorScheme == .light ? 0.05 : 0.02
        let bottomTint = colorScheme == .light ? 0.03 : 0.05
        return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(AppColors.secondarySystemGroupedBackground)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColors.white.opacity(topTint),
                                AppColors.clear,
                                AppColors.black.opacity(bottomTint),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
    }
}

/// Полный бордер по контуру.
private struct ActionButtonChrome: ViewModifier {
    let cornerRadius: CGFloat
    let borderOpacity: CGFloat
    let borderLineWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    ActionButtonChromeFill(cornerRadius: cornerRadius)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(AppColors.tertiaryLabel.opacity(borderOpacity), lineWidth: borderLineWidth)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// Бордер только справа, к центру плавно исчезает.
private struct ActionButtonChromeRight: ViewModifier {
    let cornerRadius: CGFloat
    let borderOpacity: CGFloat
    let borderLineWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    ActionButtonChromeFill(cornerRadius: cornerRadius)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(AppColors.tertiaryLabel.opacity(borderOpacity), lineWidth: borderLineWidth)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// Бордер у нижнего края, к середине по вертикали плавно исчезает (снизу вверх).
private struct ActionButtonChromeBottom: ViewModifier {
    let cornerRadius: CGFloat
    let borderOpacity: CGFloat
    let borderLineWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    ActionButtonChromeFill(cornerRadius: cornerRadius)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(AppColors.tertiaryLabel.opacity(borderOpacity), lineWidth: borderLineWidth)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// Плитка под сетку из 2 колонок: иконка сверху по центру, заголовок (до 2 строк), подпись.
struct BigActionButtonToTwoColumn: View {
    let icon: String
    let title: String
    let subtitle: String
    var iconColor: Color = AppColors.accent
    var titleColor: Color = AppColors.label
    var subtitleColor: Color = AppColors.secondaryLabel
    var statusTitle: String? = nil
    var statusColor: Color = AppColors.accent
    var layout: ActionButtonLayout = .bigDefault

    @Environment(\.colorScheme) private var colorScheme

    private let cornerRadius: CGFloat = 12
    private let borderOpacity: CGFloat = 0.34
    private let borderWidth: CGFloat = 0.55

    var body: some View {
        VStack(alignment: .center, spacing: 5) {
            if let statusTitle, !statusTitle.isEmpty {
                HStack {
                    Spacer()
                    ActionStatusChip(title: statusTitle, color: statusColor)
                }
                .padding(.bottom, 2)
            }

            AppTablerIcon(icon)
                .appIcon(.s20)
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(titleColor)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(subtitleColor)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 26, alignment: .top)

            AppTablerIcon("chevron-right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.tertiaryLabel.opacity(0.7))
                .rotationEffect(.degrees(90))
        }
        .frame(maxWidth: .infinity, minHeight: layout.minHeight, alignment: .center)
        .padding(.horizontal, layout.contentPaddingHorizontal)
        .padding(.vertical, layout.contentPaddingVertical)
        .modifier(ActionButtonChromeBottom(cornerRadius: cornerRadius, borderOpacity: borderOpacity, borderLineWidth: borderWidth))
        .padding(.vertical, layout.outerPaddingVertical)
        .contentShape(Rectangle())
    }
}

/// Одна колонка на всю ширину: слева иконка (или аватар), заголовок и блок подписи, справа шеврон.
struct WideActionButtonToOneColumn: View {
    enum Leading {
        case tablerIcon(name: String, color: Color)
        /// `sideLength` — сторона квадрата фона под иконкой (например 36 в списке профилей, 44 в крупных блоках).
        case avatar(icon: String, iconColor: Color, background: Color, cornerRadius: CGFloat, sideLength: CGFloat)
    }

    private let leading: Leading
    let title: String
    private let subtitle: String
    private let detail: AnyView?

    var showChevron: Bool
    var prominentTitle: Bool
    var titleColor: Color
    var subtitleColor: Color
    var chevronColor: Color
    var accent: Color? = nil
    var showsLeadingAccentBar: Bool = true
    var statusTitle: String? = nil
    var statusColor: Color = AppColors.accent
    var layout: ActionButtonLayout = .wideDefault

    @Environment(\.colorScheme) private var colorScheme

    private let cornerRadius: CGFloat = 12
    private let borderOpacity: CGFloat = 0.30
    private let borderWidth: CGFloat = 0.55

    init(
        icon: String,
        title: String,
        subtitle: String = "",
        showChevron: Bool = true,
        prominentTitle: Bool = false,
        iconColor: Color = AppColors.accent,
        titleColor: Color = AppColors.label,
        subtitleColor: Color = AppColors.secondaryLabel,
        chevronColor: Color = AppColors.tertiaryLabel,
        accent: Color? = nil,
        showsLeadingAccentBar: Bool = true,
        statusTitle: String? = nil,
        statusColor: Color = AppColors.accent,
        layout: ActionButtonLayout = .wideDefault
    ) {
        leading = .tablerIcon(name: icon, color: iconColor)
        self.title = title
        self.subtitle = subtitle
        detail = nil
        self.showChevron = showChevron
        self.prominentTitle = prominentTitle
        self.titleColor = titleColor
        self.subtitleColor = subtitleColor
        self.chevronColor = chevronColor
        self.accent = accent
        self.showsLeadingAccentBar = showsLeadingAccentBar
        self.statusTitle = statusTitle
        self.statusColor = statusColor
        self.layout = layout
    }

    init(
        leading: Leading,
        title: String,
        subtitle: String = "",
        showChevron: Bool = true,
        prominentTitle: Bool = false,
        titleColor: Color = AppColors.label,
        subtitleColor: Color = AppColors.secondaryLabel,
        chevronColor: Color = AppColors.tertiaryLabel,
        accent: Color? = nil,
        showsLeadingAccentBar: Bool = true,
        statusTitle: String? = nil,
        statusColor: Color = AppColors.accent,
        layout: ActionButtonLayout = .wideDefault
    ) {
        self.leading = leading
        self.title = title
        self.subtitle = subtitle
        detail = nil
        self.showChevron = showChevron
        self.prominentTitle = prominentTitle
        self.titleColor = titleColor
        self.subtitleColor = subtitleColor
        self.chevronColor = chevronColor
        self.accent = accent
        self.showsLeadingAccentBar = showsLeadingAccentBar
        self.statusTitle = statusTitle
        self.statusColor = statusColor
        self.layout = layout
    }

    init(
        icon: String,
        title: String,
        showChevron: Bool = true,
        prominentTitle: Bool = false,
        iconColor: Color = AppColors.accent,
        titleColor: Color = AppColors.label,
        subtitleColor: Color = AppColors.secondaryLabel,
        chevronColor: Color = AppColors.tertiaryLabel,
        accent: Color? = nil,
        showsLeadingAccentBar: Bool = true,
        statusTitle: String? = nil,
        statusColor: Color = AppColors.accent,
        layout: ActionButtonLayout = .wideDefault,
        @ViewBuilder detail: () -> some View
    ) {
        leading = .tablerIcon(name: icon, color: iconColor)
        self.title = title
        subtitle = ""
        self.detail = AnyView(detail())
        self.showChevron = showChevron
        self.prominentTitle = prominentTitle
        self.titleColor = titleColor
        self.subtitleColor = subtitleColor
        self.chevronColor = chevronColor
        self.accent = accent
        self.showsLeadingAccentBar = showsLeadingAccentBar
        self.statusTitle = statusTitle
        self.statusColor = statusColor
        self.layout = layout
    }

    var body: some View {
        HStack(alignment: .center, spacing: AppDesign.rowSpacing) {
            leadingView

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(prominentTitle ? .headline.weight(.semibold) : .subheadline.weight(.semibold))
                    .foregroundStyle(titleColor)
                    .lineLimit(prominentTitle ? 2 : 1)

                if let detail {
                    detail
                } else if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(subtitleColor)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let statusTitle, !statusTitle.isEmpty {
                ActionStatusChip(title: statusTitle, color: statusColor)
            }

            if showChevron {
                AppTablerIcon("chevron-right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(chevronColor)
                    .frame(width: 22, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity, minHeight: layout.minHeight, alignment: .leading)
        .padding(.horizontal, layout.contentPaddingHorizontal)
        .padding(.vertical, layout.contentPaddingVertical)
        .modifier(ActionButtonChromeRight(cornerRadius: cornerRadius, borderOpacity: borderOpacity, borderLineWidth: borderWidth))
        .overlay(alignment: .leading) {
            if showsLeadingAccentBar {
                Capsule(style: .continuous)
                    .fill((accent ?? AppColors.accent).opacity(0.92))
                    .frame(width: 3)
                    .padding(.vertical, 7)
                    .padding(.leading, 1)
            }
        }
        .padding(.vertical, layout.outerPaddingVertical)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var leadingView: some View {
        switch leading {
        case .tablerIcon(let name, color: let color):
            AppTablerIcon(name)
                .appIcon(.s16)
                .foregroundStyle(color)
                .frame(width: 24, height: 24, alignment: .center)
        case .avatar(let icon, let iconColor, let background, let cornerRadius, let sideLength):
            let iconSize: AppIconSize = sideLength >= 44 ? .s20 : .s16
            AppTablerIcon(icon)
                .appIcon(iconSize)
                .foregroundStyle(iconColor)
                .frame(width: sideLength, height: sideLength)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

// MARK: - Raw full-width action rows (tap / long tap host)

/// Универсальная "сырая" строка-кнопка на всю ширину: leading-иконка, заголовок, опционально subtitle/value/trailing.
/// Используется как базовый слой для `CardRow`, `ActionBlockRow`, `AddActionRow`.
struct RawActionButton<Trailing: View>: View {
    var icon: String? = nil
    var iconColor: Color = .secondary

    let title: String
    var subtitle: String? = nil
    var titleColor: Color = .primary
    var subtitleColor: Color = AppColors.secondaryLabel

    var value: String? = nil
    var valueColor: Color = .secondary
    var accent: Color? = nil
    var showsLeadingAccentBar: Bool = true
    var statusTitle: String? = nil
    var statusColor: Color = AppColors.accent

    var verticalPadding: CGFloat = 12
    var horizontalPadding: CGFloat = AppDesign.cardPadding

    var minHeight: CGFloat? = nil
    /// Если `true`, применяется "кнопочный" хром (3D+бордер+тени).
    var isInteractive: Bool = false

    @ViewBuilder var trailing: () -> Trailing

    private let cornerRadius: CGFloat = 12
    private let borderOpacity: CGFloat = 0.30
    private let borderWidth: CGFloat = 0.55

    init(
        icon: String? = nil,
        iconColor: Color = .secondary,
        title: String,
        subtitle: String? = nil,
        titleColor: Color = .primary,
        subtitleColor: Color = AppColors.secondaryLabel,
        value: String? = nil,
        valueColor: Color = .secondary,
        accent: Color? = nil,
        showsLeadingAccentBar: Bool = true,
        statusTitle: String? = nil,
        statusColor: Color = AppColors.accent,
        verticalPadding: CGFloat = 12,
        horizontalPadding: CGFloat = AppDesign.cardPadding,
        minHeight: CGFloat? = nil,
        isInteractive: Bool = false,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.titleColor = titleColor
        self.subtitleColor = subtitleColor
        self.value = value
        self.valueColor = valueColor
        self.accent = accent
        self.showsLeadingAccentBar = showsLeadingAccentBar
        self.statusTitle = statusTitle
        self.statusColor = statusColor
        self.verticalPadding = verticalPadding
        self.horizontalPadding = horizontalPadding
        self.minHeight = minHeight
        self.isInteractive = isInteractive
        self.trailing = trailing
    }

    var body: some View {
        let row = HStack(alignment: .center, spacing: AppDesign.rowSpacing) {
            if let icon {
                AppTablerIcon(icon)
                    .foregroundStyle(iconColor)
                    .frame(width: 28, alignment: .center)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(titleColor)
                    .lineLimit(2)

                if let subtitle, !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(subtitleColor)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let statusTitle, !statusTitle.isEmpty {
                ActionStatusChip(title: statusTitle, color: statusColor)
            }

            if let value, !value.isEmpty {
                Text(value)
                    .foregroundStyle(valueColor)
            }

            trailing()
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        .contentShape(Rectangle())

        if isInteractive {
            row
                .modifier(ActionButtonChrome(cornerRadius: cornerRadius, borderOpacity: borderOpacity, borderLineWidth: borderWidth))
                .overlay(alignment: .leading) {
                    if showsLeadingAccentBar {
                        Capsule(style: .continuous)
                            .fill((accent ?? iconColor).opacity(0.92))
                            .frame(width: 3)
                            .padding(.vertical, 7)
                            .padding(.leading, 1)
                    }
                }
        } else {
            row
        }
    }
}

// MARK: - Unified list/grid rows for tappable content

struct ListActionRow<Content: View, Trailing: View>: View {
    var verticalPadding: CGFloat = 14
    var horizontalPadding: CGFloat = AppDesign.cardPadding
    var minHeight: CGFloat? = nil
    var cornerRadius: CGFloat = 12
    var isInteractive: Bool = true
    @ViewBuilder var content: () -> Content
    @ViewBuilder var trailing: () -> Trailing

    private let borderOpacity: CGFloat = 0.30
    private let borderWidth: CGFloat = 0.55

    init(
        verticalPadding: CGFloat = 14,
        horizontalPadding: CGFloat = AppDesign.cardPadding,
        minHeight: CGFloat? = nil,
        cornerRadius: CGFloat = 12,
        isInteractive: Bool = true,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.verticalPadding = verticalPadding
        self.horizontalPadding = horizontalPadding
        self.minHeight = minHeight
        self.cornerRadius = cornerRadius
        self.isInteractive = isInteractive
        self.content = content
        self.trailing = trailing
    }

    var body: some View {
        let row = HStack(alignment: .top, spacing: 16) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        .contentShape(Rectangle())

        if isInteractive {
            row.modifier(ActionButtonChrome(cornerRadius: cornerRadius, borderOpacity: borderOpacity, borderLineWidth: borderWidth))
        } else {
            if cornerRadius == 0 {
                row
            } else {
                row
                    .background(
                        AppColors.secondarySystemGroupedBackground,
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(AppColors.tertiaryLabel.opacity(borderOpacity), lineWidth: borderWidth)
                    )
            }
        }
    }
}

struct GridActionTile<Content: View, Trailing: View>: View {
    var paddingHorizontal: CGFloat = 10
    var paddingVertical: CGFloat = 8
    var minHeight: CGFloat = 72
    var cornerRadius: CGFloat = 12
    var isInteractive: Bool = true
    @ViewBuilder var content: () -> Content
    @ViewBuilder var trailing: () -> Trailing

    private let borderOpacity: CGFloat = 0.28
    private let borderWidth: CGFloat = 0.55

    init(
        paddingHorizontal: CGFloat = 10,
        paddingVertical: CGFloat = 8,
        minHeight: CGFloat = 72,
        cornerRadius: CGFloat = 12,
        isInteractive: Bool = true,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.paddingHorizontal = paddingHorizontal
        self.paddingVertical = paddingVertical
        self.minHeight = minHeight
        self.cornerRadius = cornerRadius
        self.isInteractive = isInteractive
        self.content = content
        self.trailing = trailing
    }

    var body: some View {
        let tile = VStack(alignment: .leading, spacing: 8) {
            content()
            Spacer(minLength: 0)
            HStack {
                Spacer()
                trailing()
            }
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        .padding(.horizontal, paddingHorizontal)
        .padding(.vertical, paddingVertical)
        .contentShape(Rectangle())

        if isInteractive {
            tile.modifier(ActionButtonChrome(cornerRadius: cornerRadius, borderOpacity: borderOpacity, borderLineWidth: borderWidth))
        } else {
            tile
                .background(
                    AppColors.secondarySystemGroupedBackground,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(AppColors.tertiaryLabel.opacity(borderOpacity), lineWidth: borderWidth)
                )
        }
    }
}

/// Строка «Добавить что‑то» для списков: иконка + жирный заголовок.
struct AddActionRow: View {
    let title: String
    let appIcon: String

    var body: some View {
        RawActionButton(
            icon: appIcon,
            iconColor: AppColors.secondaryLabel,
            title: title,
            titleColor: .primary,
            isInteractive: true
        )
        .font(.headline)
    }
}

/// Переиспользуемая строка для карточек и блоков: иконка, заголовок, опциональное значение справа, опционально шеврон.
struct CardRow: View {
    let icon: String
    let title: String
    var value: String? = nil
    var showsDisclosure: Bool = false

    var body: some View {
        RawActionButton(
            icon: icon,
            iconColor: .secondary,
            title: title,
            titleColor: .primary,
            value: value,
            valueColor: .secondary,
            isInteractive: showsDisclosure
        ) {
            if showsDisclosure {
                AppTablerIcon("chevron-right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

/// Блок-строка: иконка, заголовок, опционально значение справа. Для навигации или действия.
struct ActionBlockRow: View {
    var icon: String? = nil
    let title: String
    var value: String? = nil
    var action: (() -> Void)? = nil
    var destructive: Bool = false

    private var foreground: Color { destructive ? .red : .primary }

    var body: some View {
        if let action {
            Button(action: action) { rowContent }
                .buttonStyle(PressableButtonStyle())
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        RawActionButton(
            icon: icon,
            iconColor: destructive ? .red : .secondary,
            title: title,
            titleColor: foreground,
            value: value,
            valueColor: destructive ? .red : .secondary,
            isInteractive: action != nil
        )
    }
}

/// Home-адаптер над `WideActionButtonToOneColumn` (оставлен ради читаемости).
struct HomeActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var showChevron: Bool = true
    var iconColor: Color = AppColors.accent
    var titleColor: Color = AppColors.label
    var subtitleColor: Color = AppColors.secondaryLabel
    var accent: Color? = nil
    var showsLeadingAccentBar: Bool = true
    var statusTitle: String? = nil
    var statusColor: Color = AppColors.accent

    var body: some View {
        WideActionButtonToOneColumn(
            icon: icon,
            title: title,
            subtitle: subtitle,
            showChevron: showChevron,
            iconColor: iconColor,
            titleColor: titleColor,
            subtitleColor: subtitleColor,
            accent: accent,
            showsLeadingAccentBar: showsLeadingAccentBar,
            statusTitle: statusTitle,
            statusColor: statusColor
        )
    }
}

