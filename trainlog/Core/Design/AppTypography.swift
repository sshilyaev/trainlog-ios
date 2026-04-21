import SwiftUI

/// Единый набор типографических ролей для всего приложения.
enum AppTypographyRole {
    case screenTitle
    case sectionTitle
    case body
    case bodyEmphasis
    case secondary
    case caption
    case button
    case numericMetric
    case formValue

    var font: Font {
        switch self {
        case .screenTitle: return .title2.weight(.semibold)
        case .sectionTitle: return .headline
        case .body: return .body
        case .bodyEmphasis: return .body.weight(.semibold)
        case .secondary: return .subheadline
        case .caption: return .caption
        case .button: return .body.weight(.medium)
        case .numericMetric: return .title3.weight(.semibold)
        case .formValue: return .subheadline
        }
    }
}

extension View {
    /// Накладывает типографический токен вместо локального `.font(...)`.
    func appTypography(_ role: AppTypographyRole) -> some View {
        font(role.font)
    }
}

