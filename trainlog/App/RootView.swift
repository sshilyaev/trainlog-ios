//
//  RootView.swift
//  TrainLog
//

import SwiftUI
import UIKit
import AudioToolbox

struct RootView: View {
    @Bindable var appState: AppState
    @AppStorage("appTheme") private var appThemeRaw = AppTheme.system.rawValue
    @AppStorage(AppFontSizeStepStorage.appStorageKey) private var appFontSizeStep = 0
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var offlineMode = OfflineMode.shared
    @State private var showOfflineInfo = false
    let authService: AuthServiceProtocol
    let profileService: ProfileServiceProtocol
    let measurementService: MeasurementServiceProtocol
    let goalService: GoalServiceProtocol
    let personalRecordService: PersonalRecordServiceProtocol
    let linkService: CoachTraineeLinkServiceProtocol
    let connectionTokenService: ConnectionTokenServiceProtocol
    let membershipService: MembershipServiceProtocol
    let visitService: VisitServiceProtocol
    /// Сервис для синхронизации офлайн-очереди (всегда API).
    let visitServiceForSync: VisitServiceProtocol
    let eventService: EventServiceProtocol
    let managedTraineeMergeService: ManagedTraineeMergeServiceProtocol
    let coachStatisticsService: CoachStatisticsServiceProtocol
    let healthService: HealthServiceProtocol
    let calendarSummaryService: CalendarSummaryServiceProtocol
    let nutritionService: NutritionServiceProtocol
    let calculatorsService: CalculatorsServiceProtocol
    let coachOverviewService: CoachOverviewServiceProtocol
    private let startupTimeoutSeconds: Double = 15

    var body: some View {
        screenContent
            .id(appState.rootViewContentId)
            .appFontSizeStepFromUserSettings()
            .environment(\.appFontExtraPoints, AppFontFixedSizeExtra.points(forStep: appFontSizeStep))
            .animation(.easeInOut(duration: 0.35), value: appFontSizeStep)
            .preferredColorScheme(AppTheme(rawValue: appThemeRaw)?.preferredColorScheme)
            .environmentObject(offlineMode)
            .overlay(alignment: .topTrailing) { offlineOverlayContent }
            .onAppear {
                RootView.triggerLaunchHaptic()
                ToastOverlayPresenter.shared.attachIfNeeded()
                InfoHintPopupPresenter.shared.attachIfNeeded()
                AppConfirmationDialogPresenter.shared.attachIfNeeded()
            }
            .task { await runSplashAndInit() }
            .onChange(of: appState.authStatus, runAuthStatusChange)
            .onChange(of: scenePhase, runScenePhaseChange)
            .appConfirmationDialog(
                title: "Ошибка",
                message: appState.globalError ?? "Произошла ошибка.",
                isPresented: globalErrorBinding,
                confirmTitle: "OK",
                onConfirm: { appState.globalError = nil },
                onCancel: { appState.globalError = nil }
            )
    }

    @ViewBuilder
    private var screenContent: some View {
        switch appState.currentScreen {
        case .splash:
            SplashView()

        case .auth:
            authViewContent

        case .profileSelection, .createProfile:
            profileSelectionContent

        case .main(let profile):
            mainView(for: profile)
        }
    }

    private var authViewContent: some View {
        AuthView(
            onSignIn: { email, password in
                let uid = try await authService.signIn(email: email, password: password)
                await MainActor.run { appState.didAuthenticate(userId: uid) }
                await loadProfiles(userId: uid)
            },
            onSignUp: { displayName, email, password, profileType, gender in
                let uid = try await authService.signUp(email: email, password: password, displayName: displayName)
                await MainActor.run { appState.didAuthenticate(userId: uid) }
                let draft = Profile(
                    id: UUID().uuidString,
                    userId: uid,
                    type: profileType,
                    name: displayName,
                    gender: gender
                )
                let created = try await profileService.createProfile(draft, name: displayName)
                await loadProfiles(userId: uid)
                await MainActor.run {
                    appState.profileIdForPostRegistrationOnboarding = created.id
                    appState.selectProfile(created)
                }
            }
        )
    }

    private var profileSelectionContent: some View {
        ProfileSelectionView(
            profiles: appState.profiles,
            authService: authService,
            profileService: profileService,
            accountDisplayName: authService.currentUserDisplayName,
            onSelect: { appState.selectProfile($0) },
            onCreate: { appState.showCreateProfile() },
            onSignOut: {
                try? authService.signOut()
                appState.showAuth()
            },
            onQuickCreate: { type, gender, name in
                guard let uid = appState.userId else { return }
                let draft = Profile(id: UUID().uuidString, userId: uid, type: type, name: name, gender: gender)
                let created = try await profileService.createProfile(draft, name: name)
                await loadProfiles(userId: uid)
                await MainActor.run {
                    if let p = appState.profiles.first(where: { $0.id == created.id }) {
                        appState.profileIdForPostRegistrationOnboarding = p.id
                        appState.selectProfile(p)
                    }
                }
            }
        )
        .overlay {
            if appState.isLoadingProfiles {
                LoadingOverlayView(message: "Загружаю")
            }
        }
        .sheet(isPresented: createProfileSheetBinding) {
            if let uid = appState.userId {
                CreateProfileView(
                    userId: uid,
                    profileService: profileService,
                    measurementService: measurementService,
                    initialName: authService.currentUserDisplayName,
                    onCreated: { createdId, _ in
                        Task {
                            await MainActor.run { appState.createProfileError = nil }
                            await loadProfiles(userId: uid)
                            await MainActor.run {
                                guard let p = appState.profiles.first(where: { $0.id == createdId }) else { return }
                                appState.profileIdForPostRegistrationOnboarding = p.id
                                appState.selectProfile(p)
                            }
                        }
                    },
                    onCancel: {
                        appState.createProfileError = nil
                        appState.currentScreen = .profileSelection
                    },
                    createProfileError: appState.createProfileError,
                    onClearError: { appState.createProfileError = nil },
                    onError: { appState.createProfileError = $0 }
                )
                .mainSheetPresentation(.half)
            } else {
                SplashView()
            }
        }
    }

    private var createProfileSheetBinding: Binding<Bool> {
        Binding(
            get: { if case .createProfile = appState.currentScreen { return true }; return false },
            set: { if !$0 { appState.showProfileSelection() } }
        )
    }

    private var globalErrorBinding: Binding<Bool> {
        Binding(
            get: { appState.globalError != nil },
            set: { if !$0 { appState.globalError = nil } }
        )
    }

    @ViewBuilder
    private var offlineOverlayContent: some View {
        if offlineMode.isOffline {
            GeometryReader { geo in
                HStack(spacing: 10) {
                    if showOfflineInfo {
                        Text("Офлайн‑режим: данные берём из кэша. Действия сохраняются локально и синхронизируются при появлении связи (после открытия приложения).")
                            .font(.footnote)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                            .frame(maxWidth: min(320, geo.size.width * 0.68), alignment: .leading)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                    Button {
                        withAnimation(.snappy(duration: 0.22)) { showOfflineInfo.toggle() }
                    } label: { OfflineSticker() }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, 0)
                .offset(y: geo.size.height * 0.33)
            }
            .zIndex(100)
        }
    }

    private func runAuthStatusChange(_: AppState.AuthStatus, _ newStatus: AppState.AuthStatus) {
        if case .authenticated(let uid) = newStatus {
            Task { await loadProfiles(userId: uid) }
        }
    }

    private func runScenePhaseChange(_: ScenePhase, _ newPhase: ScenePhase) {
        if newPhase == .active {
            Task { await OfflineSyncWorker.shared.syncAllIfNeeded(visitService: visitServiceForSync) }
        }
    }

    @ViewBuilder
    private func mainView(for profile: Profile) -> some View {
        Group {
            if profile.isCoach {
                CoachMainView(
                    profile: profile,
                    onSwitchProfile: { appState.showProfileSelection() },
                    onDeleteProfile: { await deleteCurrentProfile() },
                    onProfileUpdated: { appState.updateProfile($0) },
                    linkService: linkService,
                    profileService: profileService,
                    measurementService: measurementService,
                    goalService: goalService,
                    personalRecordService: personalRecordService,
                    connectionTokenService: connectionTokenService,
                    membershipService: membershipService,
                    visitService: visitService,
                    eventService: eventService,
                    managedTraineeMergeService: managedTraineeMergeService,
                    coachStatisticsService: coachStatisticsService,
                    coachOverviewService: coachOverviewService,
                    calendarSummaryService: calendarSummaryService,
                    nutritionService: nutritionService,
                    calculatorsService: calculatorsService,
                    myTraineeProfiles: appState.profiles.filter { $0.type == .trainee },
                    postRegistrationOnboardingProfileId: appState.profileIdForPostRegistrationOnboarding,
                    onClearPostRegistrationOnboarding: { appState.profileIdForPostRegistrationOnboarding = nil }
                )
            } else {
                TraineeMainView(
                    profile: profile,
                    measurementService: measurementService,
                    goalService: goalService,
                    personalRecordService: personalRecordService,
                    connectionTokenService: connectionTokenService,
                    profileService: profileService,
                    membershipService: membershipService,
                    visitService: visitService,
                    eventService: eventService,
                    linkService: linkService,
                    calendarSummaryService: calendarSummaryService,
                    healthService: healthService,
                    nutritionService: nutritionService,
                    calculatorsService: calculatorsService,
                    onSwitchProfile: { appState.showProfileSelection() },
                    onDeleteProfile: { await deleteCurrentProfile() },
                    onProfileUpdated: { appState.updateProfile($0) },
                    postRegistrationOnboardingProfileId: appState.profileIdForPostRegistrationOnboarding,
                    onClearPostRegistrationOnboarding: { appState.profileIdForPostRegistrationOnboarding = nil }
                )
            }
        }
    }

    private func runSplashAndInit() async {
        let minSplashSeconds: Double = 4.0
        let startedAt = Date()
        authService.addAuthStateListener { _ in }
        if let uid = authService.currentUserId {
            await MainActor.run {
                appState.authStatus = .authenticated(userId: uid)
            }
            switch await fetchProfilesForStartup(userId: uid, timeoutSeconds: startupTimeoutSeconds) {
            case .loaded(let list):
                let elapsed = Date().timeIntervalSince(startedAt)
                if elapsed < minSplashSeconds {
                    try? await Task.sleep(nanoseconds: UInt64((minSplashSeconds - elapsed) * 1_000_000_000))
                }
                await MainActor.run {
                    offlineMode.isOffline = false
                    appState.didLoadProfiles(list)
                }
            case .failed(let error):
                let elapsed = Date().timeIntervalSince(startedAt)
                if elapsed < minSplashSeconds {
                    try? await Task.sleep(nanoseconds: UInt64((minSplashSeconds - elapsed) * 1_000_000_000))
                }
                await applyStartupProfilesFailure(userId: uid, error: error)
            case .timeout:
                let elapsed = Date().timeIntervalSince(startedAt)
                if elapsed < minSplashSeconds {
                    try? await Task.sleep(nanoseconds: UInt64((minSplashSeconds - elapsed) * 1_000_000_000))
                }
                await applyStartupTimeoutFallback(userId: uid)
            }
        } else {
            let elapsed = Date().timeIntervalSince(startedAt)
            if elapsed < minSplashSeconds {
                try? await Task.sleep(nanoseconds: UInt64((minSplashSeconds - elapsed) * 1_000_000_000))
            }
            await MainActor.run {
                appState.authStatus = .unauthenticated
                appState.currentScreen = .auth
            }
        }
    }

    private enum StartupProfilesFetchResult {
        case loaded([Profile])
        case failed(Error)
        case timeout
    }

    private func fetchProfilesForStartup(userId: String, timeoutSeconds: Double) async -> StartupProfilesFetchResult {
        await withTaskGroup(of: StartupProfilesFetchResult.self) { group in
            group.addTask {
                do {
                    let list = try await profileService.fetchProfiles(userId: userId)
                    return .loaded(list)
                } catch {
                    return .failed(error)
                }
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                return .timeout
            }

            let first = await group.next() ?? .timeout
            group.cancelAll()
            return first
        }
    }

    private func applyStartupProfilesFailure(userId: String, error: Error) async {
        await MainActor.run {
            if AppConfig.enableOfflineMode,
               let cached = appState.loadProfilesCache(userId: userId),
               !cached.isEmpty {
                appState.globalError = nil
                offlineMode.isOffline = true
                appState.profiles = cached
                appState.isLoadingProfiles = false
                appState.profilesLoadError = nil
                if let lastId = UserDefaults.standard.string(forKey: "lastSelectedProfileId_\(userId)"),
                   let profile = cached.first(where: { $0.id == lastId }) {
                    appState.currentProfile = profile
                    appState.currentScreen = .main(profile)
                } else {
                    appState.currentScreen = .profileSelection
                }
            } else if let msg = AppErrors.userMessageIfNeeded(for: error) {
                appState.didFailLoadingProfiles(msg)
                appState.currentScreen = .profileSelection
            } else {
                appState.didFailLoadingProfiles("Не удалось загрузить профиль. Попробуйте ещё раз.")
                appState.currentScreen = .profileSelection
            }
        }
    }

    private func applyStartupTimeoutFallback(userId: String) async {
        await MainActor.run {
            if AppConfig.enableOfflineMode,
               let cached = appState.loadProfilesCache(userId: userId),
               !cached.isEmpty {
                appState.globalError = nil
                offlineMode.isOffline = true
                appState.profiles = cached
                appState.isLoadingProfiles = false
                appState.profilesLoadError = nil
                if let lastId = UserDefaults.standard.string(forKey: "lastSelectedProfileId_\(userId)"),
                   let profile = cached.first(where: { $0.id == lastId }) {
                    appState.currentProfile = profile
                    appState.currentScreen = .main(profile)
                } else {
                    appState.currentScreen = .profileSelection
                }
            } else {
                offlineMode.isOffline = true
                appState.didFailLoadingProfiles("Долгая загрузка. Запущен офлайн-режим.")
                appState.currentScreen = .profileSelection
            }
        }
    }

    private func loadProfiles(userId: String) async {
        let minSplashSeconds: Double = 4.0
        let shouldHoldSplash = await MainActor.run {
            if case .splash = appState.currentScreen { return true }
            return false
        }
        let startedAt = Date()
        do {
            let list = try await profileService.fetchProfiles(userId: userId)
            if shouldHoldSplash {
                let elapsed = Date().timeIntervalSince(startedAt)
                if elapsed < minSplashSeconds {
                    try? await Task.sleep(nanoseconds: UInt64((minSplashSeconds - elapsed) * 1_000_000_000))
                }
            }
            await MainActor.run {
                offlineMode.isOffline = false
                appState.didLoadProfiles(list)
            }
        } catch {
            if shouldHoldSplash {
                let elapsed = Date().timeIntervalSince(startedAt)
                if elapsed < minSplashSeconds {
                    try? await Task.sleep(nanoseconds: UInt64((minSplashSeconds - elapsed) * 1_000_000_000))
                }
            }
            await MainActor.run {
                if AppConfig.enableOfflineMode, let cached = appState.loadProfilesCache(userId: userId), !cached.isEmpty {
                    appState.globalError = nil
                    offlineMode.isOffline = true
                    // В офлайне всё равно выставляем экраны так же, как при обычной загрузке.
                    appState.profiles = cached
                    appState.isLoadingProfiles = false
                    appState.profilesLoadError = nil
                    if let lastId = UserDefaults.standard.string(forKey: "lastSelectedProfileId_\(userId)"),
                       let profile = cached.first(where: { $0.id == lastId }) {
                        appState.currentProfile = profile
                        appState.currentScreen = .main(profile)
                    } else {
                        appState.currentScreen = .profileSelection
                    }
                } else if let msg = AppErrors.userMessageIfNeeded(for: error) {
                    appState.didFailLoadingProfiles(msg)
                }
            }
        }
    }

    private func deleteCurrentProfile() async {
        guard let profile = appState.currentProfile else { return }
        do {
            try await profileService.deleteProfile(profile)
            await MainActor.run {
                appState.didDeleteProfile(profile)
                ToastCenter.shared.success("Профиль удален")
            }
        } catch {
            await MainActor.run {
                ToastCenter.shared.error(from: error, fallback: "Не удалось удалить профиль")
                if let msg = AppErrors.userMessageIfNeeded(for: error) { appState.globalError = msg }
            }
        }
    }

}

// MARK: - Вибрация при запуске: мягкая и подлиннее (серия лёгких ударов)

private extension RootView {
    static var hasTriggeredLaunchHaptic = false

    static func triggerLaunchHaptic() {
        guard !hasTriggeredLaunchHaptic else { return }
        hasTriggeredLaunchHaptic = true
        #if os(iOS)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            runLaunchHapticOnMainThread()
        }
        #endif
    }

    static func runLaunchHapticOnMainThread() {
        #if os(iOS)
        let lightGen = UIImpactFeedbackGenerator(style: .light)
        let mediumGen = UIImpactFeedbackGenerator(style: .medium)
        lightGen.prepare()
        mediumGen.prepare()

        let count = 160
        let interval: Double = 0.004

        func fire(at index: Int) {
            guard index < count else { return }
            if index <= 40 {
                mediumGen.impactOccurred(intensity: 0.55)
            } else if index < 40 && index > count - 60 {
                mediumGen.impactOccurred(intensity: 0.99)
            } else {
                lightGen.impactOccurred(intensity: 0.25)
            }
            
            let nextDelay = {
                switch (index, count) {
                case let (i, _) where i < 4:
                    return 0.7
                case let (i, c) where i >= c - 0:
                    return 0.05
                default:
                    return interval
                }
            }()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + nextDelay) {
                fire(at: index + 1)
            }
        }
        fire(at: 0)
        #endif
    }
}
