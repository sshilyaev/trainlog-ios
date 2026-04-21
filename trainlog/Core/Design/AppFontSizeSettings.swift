import SwiftUI

enum AppFontSizeStepStorage {
    static let appStorageKey = "appFontSizeStep"

    /// 0...1, значение сохраняется в UserDefaults.
    static func clamp(_ raw: Int) -> Int { min(max(raw, 0), 1) }
}

/// Дополнительные пункты к фиксированным размерам (иконки, кастомные system(size:)).
enum AppFontFixedSizeExtra {
    static func points(forStep step: Int) -> CGFloat {
        switch AppFontSizeStepStorage.clamp(step) {
        case 1: return 2
        case 2: return 4
        default: return 0
        }
    }
}

private struct AppFontExtraPointsKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// Доп. pt к фиксированным шрифтам и иконкам: 0 / 2
    var appFontExtraPoints: CGFloat {
        get { self[AppFontExtraPointsKey.self] }
        set { self[AppFontExtraPointsKey.self] = newValue }
    }
}

extension DynamicTypeSize {
    fileprivate static let trainlogAscending: [DynamicTypeSize] = [
        .xSmall, .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge,
        .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5,
    ]

    func trainlogAdvanced(by steps: Int) -> DynamicTypeSize {
        let steps = max(0, steps)
        guard steps > 0 else { return self }
        guard let i = Self.trainlogAscending.firstIndex(of: self) else { return self }
        let j = min(i + steps, Self.trainlogAscending.count - 1)
        return Self.trainlogAscending[j]
    }
}

private struct AppFontSizeStepEnvironmentModifier: ViewModifier {
    @AppStorage(AppFontSizeStepStorage.appStorageKey) private var appFontSizeStep = 0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        let step = AppFontSizeStepStorage.clamp(appFontSizeStep)
        let resolved: DynamicTypeSize = step == 0
            ? dynamicTypeSize
            : dynamicTypeSize.trainlogAdvanced(by: step)
        content.environment(\.dynamicTypeSize, resolved)
    }
}

extension View {
    /// Применять у корня: увеличивает семантические шрифты SwiftUI относительно выбранного шага.
    func appFontSizeStepFromUserSettings() -> some View {
        modifier(AppFontSizeStepEnvironmentModifier())
    }

    /// Аналог .font(.system(size:...)), но с учётом appFontExtraPoints.
    func fontSystemWithAppExtra(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(AppFixedSystemFontModifier(baseSize: size, weight: weight, design: design))
    }
}

private struct AppFixedSystemFontModifier: ViewModifier {
    @Environment(\.appFontExtraPoints) private var extra
    let baseSize: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    func body(content: Content) -> some View {
        content.font(.system(size: baseSize + extra, weight: weight, design: design))
    }
}

