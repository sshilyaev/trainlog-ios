import SwiftUI
import UIKit

/// Единый источник всех цветов приложения (включая semantic system colors).
/// Используем только токены из этого файла — не создаём новые `Color(...)` по месту.
enum AppColors {
    // MARK: - Brand / Accent

    // Базовая палитра по логотипу (используем только эти цвета и их прозрачности).
    static let logoTeal = Color(hex: "#48AA8D")
    static let logoRose = Color(hex: "#AA4865")
    static let logoPurple = Color(hex: "#8D48AA")
    static let logoBrown = Color(hex: "#B98A46")
    static let logoIndigo = Color(hex: "#535BB4")
    static let logoGreen = Color(hex: "#5BB453")
    static let logoMagenta = Color(hex: "#AC53B4")
    static let logoOlive = Color(hex: "#B4AC53")
    static let logoSky = Color(hex: "#538CB4")
    static let logoViolet = Color(hex: "#7B53B4")

    /// Основной акцент приложения.
    static let accent = logoIndigo

    /// Акцент в профиле (аватар/шапка и т.п.).
    static let profileAccent = logoTeal

    // MARK: - Gender (avatar)

    static let genderMale = logoSky
    static let genderFemale = logoRose

    // MARK: - Surfaces (system semantic)

    static let systemGroupedBackground = Color(.systemGroupedBackground)
    static let secondarySystemGroupedBackground = Color(.secondarySystemGroupedBackground)
    static let tertiarySystemFill = Color(.tertiarySystemFill)
    static let tertiarySystemGroupedBackground = Color(.tertiarySystemGroupedBackground)

    // MARK: - Text (system semantic)

    static let label = Color(.label)
    static let secondaryLabel = Color(.secondaryLabel)
    static let tertiaryLabel = Color(.tertiaryLabel)

    // MARK: - Common

    static let white = Color.white
    static let black = Color.black
    static let clear = Color.clear

    static let shadow = Color.black.opacity(0.18)

    /// Затемнение для оверлеев (лоадер поверх экрана).
    static let overlayDim = Color.black.opacity(0.35)
    static let overlayDimLight = Color.black.opacity(0.2)
    /// Лёгкий скрим для диалогов/подложек поверх экрана.
    static let overlayScrim = Color.black.opacity(0.28)

    /// Деструктивный/ошибка (сообщения об ошибке, удаления).
    static let destructive = Color(.systemRed)

    /// Нейтральная разделительная линия/рамка.
    static let separator = Color(.separator)

    // MARK: - Screen backgrounds (custom)

    static let screenBackgroundLight = Color(red: 0.93, green: 0.93, blue: 0.95)
    static let screenBackgroundDark = Color(red: 0.08, green: 0.22, blue: 0.24)

    // MARK: - Avatar defaults

    /// Нейтральный фон круга аватара/иконки.
    static let avatarBackground = tertiarySystemFill
    /// Нейтральный цвет иконки (person и т.д.), когда нет пола.
    static let avatarIcon = secondaryLabel

    /// Цвет аватара/иконки по полу профиля (синий — мужской, нежно-розовый — женский).
    static func avatarColor(gender: ProfileGender?, defaultColor: Color = .secondary) -> Color {
        switch gender {
        case .male: return genderMale
        case .female: return genderFemale
        case nil: return defaultColor
        }
    }

    // MARK: - Splash

    static let splashGradientTop = Color(red: 0.06, green: 0.22, blue: 0.24)
    static let splashGradientBottom = Color(red: 0.04, green: 0.14, blue: 0.16)

    // MARK: - Charts (coach statistics)

    static let visitsBySubscription = logoGreen
    static let visitsOneTimePaid = logoSky
    static let visitsOneTimeDebt = logoBrown
    static let visitsCancelled = logoRose
}

// MARK: - Event colors (calendar palette)

enum EventColor {
    /// Цвет по умолчанию, если у события не задан colorHex.
    static let defaultColor = AppColors.accent

    /// Палитра для выбора цвета события: (hex без #, Color).
    static let palette: [(hex: String, color: Color)] = [
        ("48AA8D", AppColors.logoTeal),
        ("AA4865", AppColors.logoRose),
        ("8D48AA", AppColors.logoPurple),
        ("A9754B", AppColors.logoBrown),
        ("535BB4", AppColors.logoIndigo),
        ("5BB453", AppColors.logoGreen),
        ("AC53B4", AppColors.logoMagenta),
        ("B4AC53", AppColors.logoOlive),
        ("538CB4", AppColors.logoSky),
        ("7B53B4", AppColors.logoViolet),
    ]

    /// Цвет по hex-строке (без #). Если nil или невалидный — defaultColor.
    static func color(from hex: String?) -> Color {
        guard let hex = hex?.trimmingCharacters(in: .whitespaces).uppercased(),
              !hex.isEmpty else { return defaultColor }
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var r: UInt64 = 0, g: UInt64 = 0, b: UInt64 = 0
        if s.count == 6 {
            guard Scanner(string: String(s.prefix(2))).scanHexInt64(&r),
                  Scanner(string: String(s.dropFirst(2).prefix(2))).scanHexInt64(&g),
                  Scanner(string: String(s.suffix(2))).scanHexInt64(&b) else { return defaultColor }
        } else if s.count == 3 {
            guard Scanner(string: String(s.prefix(1))).scanHexInt64(&r),
                  Scanner(string: String(s.dropFirst(1).prefix(1))).scanHexInt64(&g),
                  Scanner(string: String(s.suffix(1))).scanHexInt64(&b) else { return defaultColor }
            r = r * 17; g = g * 17; b = b * 17
        } else {
            return defaultColor
        }
        return Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}

private extension Color {
    init(hex: String) {
        let value = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let s = value.hasPrefix("#") ? String(value.dropFirst()) : value
        var r: UInt64 = 0, g: UInt64 = 0, b: UInt64 = 0
        guard s.count == 6,
              Scanner(string: String(s.prefix(2))).scanHexInt64(&r),
              Scanner(string: String(s.dropFirst(2).prefix(2))).scanHexInt64(&g),
              Scanner(string: String(s.suffix(2))).scanHexInt64(&b) else {
            self = .clear
            return
        }
        self = Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}

