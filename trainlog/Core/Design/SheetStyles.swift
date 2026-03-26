import SwiftUI

/// Правила щитов:
/// - Кнопки действий — только в заголовке (toolbar), не жирные.
/// - Заголовок — по центру (`.navigationBarTitleDisplayMode(.inline)`).
/// - Высота по умолчанию — `.medium`; если контента много, разрешаем раскрытие до `.large` (стандартное поведение iOS).
enum AppSheetDetents {
    /// Компактный календарь/выбор даты.
    static let calendar: Set<PresentationDetent> = [.height(420), .medium]

    /// Небольшой щит по высоте контента (пример: заморозка).
    static let small: Set<PresentationDetent> = [.height(340)]

    /// Обычный щит: стартует с `.medium`, может раскрыться до `.large` при скролле.
    static let mediumOnly: Set<PresentationDetent> = [.medium, .large]
}

// MARK: - Стиль презентации шита (скругление, фон)

extension View {
    /// Единый стиль презентации шита: скругление верхних углов, опционально — взаимодействие с фоном.
    func sheetPresentationStyle(allowBackgroundInteraction: Bool = false) -> some View {
        self
            .presentationCornerRadius(AppSheetDetents.cornerRadius)
            .modifier(SheetBackgroundInteractionModifier(allow: allowBackgroundInteraction))
    }
}

private struct SheetBackgroundInteractionModifier: ViewModifier {
    let allow: Bool
    func body(content: Content) -> some View {
        if allow {
            content.presentationBackgroundInteraction(.enabled(upThrough: .medium))
        } else {
            content
        }
    }
}

extension AppSheetDetents {
    static let cornerRadius: CGFloat = 20
}

// MARK: - Плавное появление контента шита

struct SheetContentEntranceModifier: ViewModifier {
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.2)) {
                    appeared = true
                }
            }
    }
}

extension View {
    /// Плавное появление контента при открытии шита (opacity + небольшой offset снизу).
    func sheetContentEntrance() -> some View {
        modifier(SheetContentEntranceModifier())
    }
}

