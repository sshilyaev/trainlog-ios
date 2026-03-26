//
//  AppState.swift
//  TrainLog
//

import Foundation
import Observation

@Observable
@MainActor
final class AppState {
    enum AuthStatus: Equatable {
        case loading
        case unauthenticated
        case authenticated(userId: String)
    }

    enum Screen: Equatable {
        case splash
        case auth
        case profileSelection
        case createProfile
        case main(Profile)
    }

    var authStatus: AuthStatus = .loading
    var currentScreen: Screen = .splash
    var profiles: [Profile] = []
    var currentProfile: Profile?
    var createProfileError: String?
    /// Ошибка загрузки профилей (показывается на экране выбора профиля).
    var profilesLoadError: String?
    /// Общая ошибка для показа в alert (загрузка профилей, удаление профиля и т.д.).
    var globalError: String?
    /// Пока true — на экране выбора профиля показывается лоадер вместо контента (профили ещё грузятся).
    var isLoadingProfiles = false
    /// Автовход в последний профиль только один раз — после запуска/входа.
    private var shouldRestoreLastProfile = true

    /// Профиль, для которого нужно показать онбординг сразу после регистрации (тренер или дневник).
    var profileIdForPostRegistrationOnboarding: String?

    /// Используется как .id контента RootView, чтобы при смене экрана (например после удаления профиля) SwiftUI гарантированно перерисовал интерфейс.
    var rootViewContentId: String {
        switch currentScreen {
        case .splash: return "splash"
        case .auth: return "auth"
        // Важно: создание профиля показываем как sheet поверх выбора профиля.
        // Если менять .id при открытии sheet, SwiftUI пересоздаёт дерево и sheet "появляется", а не выезжает.
        case .profileSelection, .createProfile: return "profileSelection"
        case .main(let p): return "main-\(p.id)"
        }
    }

    var isAuthenticated: Bool {
        if case .authenticated = authStatus { return true }
        return false
    }

    var userId: String? {
        if case .authenticated(let id) = authStatus { return id }
        return nil
    }

    func showProfileSelection() {
        currentScreen = .profileSelection
    }

    func selectProfile(_ profile: Profile) {
        currentProfile = profile
        currentScreen = .main(profile)
        if let uid = userId {
            UserDefaults.standard.set(profile.id, forKey: "lastSelectedProfileId_\(uid)")
        }
    }

    func showCreateProfile() {
        createProfileError = nil
        currentScreen = .createProfile
    }

    func showMain(afterCreating profile: Profile) {
        let p = profile
        profiles.append(p)
        currentProfile = nil
        currentScreen = .profileSelection
    }

    func showAuth() {
        authStatus = .unauthenticated
        currentScreen = .auth
        profiles = []
        currentProfile = nil
        shouldRestoreLastProfile = true
    }

    func didAuthenticate(userId: String) {
        authStatus = .authenticated(userId: userId)
        currentScreen = .profileSelection
        isLoadingProfiles = true
        shouldRestoreLastProfile = true
    }

    func didLoadProfiles(_ list: [Profile]) {
        profiles = list
        isLoadingProfiles = false
        profilesLoadError = nil
        if let uid = userId {
            saveProfilesCache(list, userId: uid)
        }
        if shouldRestoreLastProfile,
           let uid = userId,
           let lastId = UserDefaults.standard.string(forKey: "lastSelectedProfileId_\(uid)"),
           let profile = list.first(where: { $0.id == lastId }) {
            currentProfile = profile
            currentScreen = .main(profile)
            shouldRestoreLastProfile = false
        } else {
            currentScreen = .profileSelection
        }
    }

    func didFailLoadingProfiles(_ message: String) {
        profiles = []
        isLoadingProfiles = false
        profilesLoadError = message
        globalError = message
    }

    func loadProfilesCache(userId: String) -> [Profile]? {
        guard let data = UserDefaults.standard.data(forKey: profilesCacheKey(userId: userId)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([Profile].self, from: data)
    }

    func saveProfilesCache(_ profiles: [Profile], userId: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(profiles) {
            UserDefaults.standard.set(data, forKey: profilesCacheKey(userId: userId))
        }
    }

    private func profilesCacheKey(userId: String) -> String {
        "profiles_cache_\(userId)"
    }

    func didCreateProfile(_ profile: Profile) {
        profiles.append(profile)
    }

    func didDeleteProfile(_ profile: Profile) {
        profiles.removeAll { $0.id == profile.id }
        if currentProfile?.id == profile.id {
            currentProfile = profiles.isEmpty ? nil : profiles.first
            currentScreen = .profileSelection
        }
    }

    func updateProfile(_ profile: Profile) {
        guard let i = profiles.firstIndex(where: {
            $0.userId == profile.userId && $0.type == profile.type &&
            abs($0.createdAt.timeIntervalSince(profile.createdAt)) < 2
        }) else { return }
        let existing = profiles[i]
        let existingId = existing.id
        let fixedProfile = Profile(
            id: existingId,
            userId: profile.userId,
            type: profile.type,
            name: profile.name,
            gymName: profile.gymName,
            createdAt: profile.createdAt,
            gender: profile.gender,
            dateOfBirth: profile.dateOfBirth,
            iconEmoji: profile.iconEmoji,
            phoneNumber: profile.phoneNumber,
            telegramUsername: profile.telegramUsername,
            notes: profile.notes,
            ownerCoachProfileId: existing.ownerCoachProfileId,
            mergedIntoProfileId: existing.mergedIntoProfileId,
            height: profile.height,
            weight: profile.weight,
            developerMode: profile.developerMode
        )
        profiles[i] = fixedProfile
        if currentProfile?.id == existingId {
            currentProfile = fixedProfile
            currentScreen = .main(fixedProfile)
        }
    }
}
