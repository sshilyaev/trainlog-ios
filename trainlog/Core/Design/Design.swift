//
//  Design.swift
//  TrainLog
//

import SwiftUI
import UIKit

/// Лёгкий дизайн-слой: отступы, размеры, скругления. Цвета — только из AppColors.
enum AppDesign {
    /// Отступ между секциями контента
    static let sectionSpacing: CGFloat = 20

    /// Внутренний отступ карточек и блоков (SettingsCard, кнопки добавления)
    static let cardPadding: CGFloat = 16
    /// Отступ между элементами в строке (HStack/VStack в рядах)
    static let rowSpacing: CGFloat = 12
    /// Малый отступ (например в overlay)
    static let blockSpacing: CGFloat = 8
    /// Скругление карточек и кнопок
    static let cornerRadius: CGFloat = 12

    /// Минимальный размер касания для иконок-кнопок (Apple HIG).
    static let minTouchTarget: CGFloat = 44

    /// Высота основной кнопки (Войти, Сохранить, Создать, Обновить)
    static let primaryButtonHeight: CGFloat = 50

    /// Скругление углов подложки аватара (квадрат со скруглёнными углами). Малая подложка 44pt.
    static let avatarCornerRadiusSmall: CGFloat = 12
    /// Подложка иконки в `WideActionButtonToOneColumn` в списке выбора профиля (компактнее 44pt).
    static let profileSwitchWideAvatarSide: CGFloat = 36
    static let profileSwitchWideAvatarCornerRadius: CGFloat = 10
    /// Скругление углов подложки аватара для большой шапки профиля 80pt.
    static let avatarCornerRadiusLarge: CGFloat = 20

    /// Прозрачность фона деструктивных кнопок (удалить, отвязать)
    static let destructiveBackgroundOpacity: Double = 0.12

    // MARK: - Типы блоков (дизайн-система)
    /// Длинный узкий блок — одна строка на всю ширину (профиль, список действий). Использование: `.actionBlockStyle()`.
    /// Длинный высокий блок — на всю ширину, высота больше одной строки (зарезервировано для будущего).
    /// Прямоугольный блок (плитка) — компактная карточка, несколько в ряд. Использование: `RectangularBlockContent` + `.rectangularBlockStyle()`.
    static let rectangularBlockMinHeight: CGFloat = 88
    static let rectangularBlockSpacing: CGFloat = 8

    // MARK: - Lists (rows/dividers)

    /// Базовый отступ для разделителя внутри списков (когда слева есть leading-иконка шириной 28 и spacing 12).
    static let listDividerLeading: CGFloat = 40
    /// Компактный отступ разделителя (когда слева нет leading-иконки, но нужен визуальный inset).
    static let listDividerLeadingCompact: CGFloat = 12
}

// MARK: - Состояние загрузки (унифицированный вид)

extension AppDesign {
    static let loadingSpacing: CGFloat = 12
    static let loadingMessageFont: Font = .subheadline
    static let loadingScale: CGFloat = 1.2
}

/// Для вставки в контент (например под кнопкой): ограниченная высота, не на весь экран.
struct LoadingBlockView: View {
    var message: String = "Загрузка…"

    var body: some View {
        VStack(spacing: AppDesign.loadingSpacing) {
            ProgressView()
                .scaleEffect(AppDesign.loadingScale)
            Text(message)
                .appTypography(.secondary)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 200)
    }
}

/// Оверлей загрузки поверх экрана: полупрозрачный фон + спиннер + текст «Загружаю». Блокирует нажатия.
struct LoadingOverlayView: View {
    var message: String = "Загружаю"

    var body: some View {
        AppColors.overlayDim
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: AppDesign.loadingSpacing) {
                    ProgressView()
                        .scaleEffect(AppDesign.loadingScale)
                        .tint(AppColors.white)
                    Text(message)
                        .appTypography(.secondary)
                        .foregroundStyle(AppColors.white)
                }
            }
            .allowsHitTesting(true)
    }
}

// MARK: - Фон экранов (адаптивный под светлую/тёмную тему)

struct AdaptiveScreenBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if colorScheme == .dark {
                AppColors.systemGroupedBackground
            } else {
                AppColors.screenBackgroundLight
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Тема приложения (светлая / тёмная / системная)

enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"

    var displayName: String {
        switch self {
        case .light: return "Светлая"
        case .dark: return "Тёмная"
        case .system: return "Как в системе"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

// MARK: - Заглушка «нет данных» (единый формат: иконка, заголовок, описание)

struct EmptyStateView<Actions: View>: View {
    let icon: String
    let title: String
    let description: String
    let animateIcon: Bool
    let ctaAppearDelay: Double
    @ViewBuilder let actions: () -> Actions

    @State private var ctaAppeared: Bool = false

    init(
        icon: String,
        title: String,
        description: String,
        animateIcon: Bool = false,
        ctaAppearDelay: Double = 0,
        @ViewBuilder actions: @escaping () -> Actions = { EmptyView() }
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.animateIcon = animateIcon
        self.ctaAppearDelay = ctaAppearDelay
        self.actions = actions
    }

    var body: some View {
        VStack(spacing: AppDesign.emptyStateSpacing) {
            AppTablerIcon(icon)
                .fontSystemWithAppExtra(size: AppDesign.emptyStateIconSize)
                .foregroundStyle(.secondary)

            Text(title)
                .appTypography(.screenTitle)

            Text(description)
                .appTypography(.secondary)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            actions()
                .opacity(ctaAppearDelay > 0 ? (ctaAppeared ? 1 : 0) : 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppDesign.emptyStateVerticalPadding)
        .onAppear {
            if ctaAppearDelay > 0 {
                withAnimation(.easeOut(duration: 0.25).delay(ctaAppearDelay)) {
                    ctaAppeared = true
                }
            } else {
                ctaAppeared = true
            }
        }
    }
}

// MARK: - Модификаторы анимации для кастомных empty state

/// Один раз лёгкое появление иконки на экране «нет данных» (без повторяющегося пульса).
struct EmptyStateIconPulseModifier: ViewModifier {
    @State private var scale: CGFloat = 0.96
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4)) {
                    scale = 1
                }
            }
    }
}

/// Появление CTA-кнопки с небольшой задержкой (только opacity, без сдвига).
struct EmptyStateCtaAppearModifier: ViewModifier {
    var delay: Double = 0.15
    @State private var appeared = false
    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.25).delay(delay)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func emptyStateIconPulse() -> some View {
        modifier(EmptyStateIconPulseModifier())
    }
    func emptyStateCtaAppear(delay: Double = 0.3) -> some View {
        modifier(EmptyStateCtaAppearModifier(delay: delay))
    }
}

extension AppDesign {
    /// Лёгкая вибрация при успешном действии (сохранить замер, добавить цель, привязать подопечного).
    static func triggerSuccessHaptic() {
        #if os(iOS)
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.prepare()
        gen.impactOccurred(intensity: 0.7)
        #endif
    }

    /// Лёгкая вибрация при нажатии на кнопку/строку (feedback «нажалось»).
    static func triggerSelectionHaptic() {
        #if os(iOS)
        let gen = UISelectionFeedbackGenerator()
        gen.prepare()
        gen.selectionChanged()
        #endif
    }

    /// Вибрация при ошибке (валидация, сетевая ошибка, алерт).
    static func triggerWarningHaptic() {
        #if os(iOS)
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.warning)
        #endif
    }

    /// Размер иконки в заглушке «нет данных»
    static let emptyStateIconSize: CGFloat = 64
    /// Отступ между элементами в заглушке
    static let emptyStateSpacing: CGFloat = 12
    /// Вертикальный отступ заглушки
    static let emptyStateVerticalPadding: CGFloat = 24
    /// Deprecated: используйте AppTypographyRole.
    static let emptyStateTitleFont: Font = .title2
    /// Deprecated: используйте AppTypographyRole.
    static let emptyStateDescriptionFont: Font = .subheadline
}

// MARK: - Единый стиль основной кнопки

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: AppDesign.primaryButtonHeight)
            .background(AppColors.accent)
            .foregroundStyle(AppColors.white)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

// MARK: - Эффект нажатия (визуальный + тактильный) для кнопок и строк

/// Стиль кнопки: при нажатии — подсветка фона, сжатие и затемнение, как у системных кнопок (Отмена, Добавить). Надевать на все нажимаемые строки и карточки.
struct PressableButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = AppDesign.cornerRadius

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if configuration.isPressed {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(AppColors.secondarySystemGroupedBackground)
                        .opacity(0.75)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    AppDesign.triggerSelectionHaptic()
                }
            }
    }
}

// MARK: - Скрытие клавиатуры по тапу и перед действием

extension View {
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            #if canImport(UIKit)
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            #endif
        }
    }
}

extension AppDesign {
    /// Сначала скрывает клавиатуру, через заданную задержку выполняет действие. Использовать при «Сохранить»/«Готово» в формах-шитах.
    static func dismissKeyboardThen(delay: TimeInterval = 0.28, action: @escaping () -> Void) {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
    }
}

// MARK: - EventColor перенесён в Core/Design/Colors.swift
