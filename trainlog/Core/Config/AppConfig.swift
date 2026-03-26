import Foundation

enum AppConfig {
    /// Включить офлайн-режим (кэш + очередь операций).
    static let enableOfflineMode: Bool = {
        // При необходимости можно вынести в Info.plist / Remote Config.
        return true
    }()

    /// Включить отображение интеграции Apple Health для обычных пользователей.
    /// Если false — блок доступен только в developer mode профиля.
    /// Можно переопределить через Info.plist ключ `AppleHealthIntegrationEnabled` (Bool).
    static let enableAppleHealthIntegration: Bool = {
        if let value = Bundle.main.object(forInfoDictionaryKey: "AppleHealthIntegrationEnabled") as? Bool {
            return value
        }
        return false
    }()

}

