import SwiftUI
import UIKit

/// Единый источник всех цветов приложения (включая semantic system colors).
/// Используем только токены из этого файла — не создаём новые `Color(...)` по месту.
enum AppColors {
    // MARK: - Brand / Accent

    /// Основной акцент приложения (синий из бренд-иконки).
    static let accent = Color(red: 0.29, green: 0.40, blue: 0.76)

    /// Акцент в профиле (аватар/шапка и т.п.).
    /// Сейчас совпадает с брендовым акцентом, чтобы не плодить отдельные дублирующие оттенки.
    static let profileAccent = accent

    // MARK: - Gender (avatar)

    /// Синий iOS (#007AFF) — совмещён с defaultColor и первой палитрой событий.
    static let genderMale = Color(red: 0, green: 0.478, blue: 1) // == EventColor.defaultColor / palette[0] / palette[5]
    static let genderFemale = Color(red: 0.96, green: 0.55, blue: 0.7)

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

    static let visitsBySubscription = Color(.systemGreen)
    /// Совмещён с палитрой событий (ближайший голубой #5AC8FA).
    static let visitsOneTimePaid = Color(red: 0.353, green: 0.784, blue: 0.980) // == EventColor.palette[3]
    static let visitsOneTimeDebt = Color(.systemOrange)
    /// Совмещён с палитрой событий (красный #FF3B30).
    static let visitsCancelled = Color(red: 1, green: 0.231, blue: 0.188) // == EventColor.palette[1]
}

// MARK: - Event colors (calendar palette)

enum EventColor {
    /// Цвет по умолчанию, если у события не задан colorHex.
    static let defaultColor = AppColors.genderMale // синий (#007AFF)

    /// Палитра для выбора цвета события: (hex без #, Color).
    static let palette: [(hex: String, color: Color)] = [
        ("007AFF", AppColors.genderMale),                            // синий
        ("FF3B30", AppColors.visitsCancelled),                       // красный
        ("AF52DE", Color(red: 0.686, green: 0.322, blue: 0.871)),    // фиолетовый
        ("5AC8FA", AppColors.visitsOneTimePaid),                     // голубой
        ("FF2D55", Color(red: 1, green: 0.176, blue: 0.333)),        // розовый
        // Объединено с #007AFF (чтобы не плодить лишние цвета в приложении).
        ("5856D6", AppColors.genderMale),                             // индиго (в UI используем тот же цвет)
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

