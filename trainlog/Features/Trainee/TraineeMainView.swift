//
//  TraineeMainView.swift
//  TrainLog
//

import SwiftUI

struct TraineeMainView: View {
    let profile: Profile
    let measurementService: MeasurementServiceProtocol
    let goalService: GoalServiceProtocol
    let personalRecordService: PersonalRecordServiceProtocol
    let connectionTokenService: ConnectionTokenServiceProtocol
    let profileService: ProfileServiceProtocol
    let membershipService: MembershipServiceProtocol
    let visitService: VisitServiceProtocol
    let eventService: EventServiceProtocol
    let linkService: CoachTraineeLinkServiceProtocol
    let calendarSummaryService: CalendarSummaryServiceProtocol
    let healthService: HealthServiceProtocol
    let nutritionService: NutritionServiceProtocol
    let calculatorsService: CalculatorsServiceProtocol
    let onSwitchProfile: () -> Void
    let onDeleteProfile: () async -> Void
    let onProfileUpdated: (Profile) -> Void
    /// Если равен profile.id — показываем онбординг после регистрации (цели + замеры).
    var postRegistrationOnboardingProfileId: String?
    var onClearPostRegistrationOnboarding: (() -> Void)?

    @AppStorage("healthDemoModeEnabled") private var healthDemoModeEnabled = false
    @State private var showAddMeasurement = false
    @State private var goals: [Goal] = []
    @State private var measurements: [Measurement] = []
    @State private var showAddGoal = false
    @State private var addForTodayItem: AddForTodaySheetItem?
    @State private var showConnectionTokenSheet = false
    @State private var showDeleteProfileConfirmation = false
    @State private var showEditProfile = false
    @State private var isDeleting = false
    @State private var isDeletingMeasurement = false
    @State private var selectedTab = 0
    @State private var errorMessage: String?
    /// Пока true — дашборд показывает лоадер до первой загрузки замеров и целей.
    @State private var isDashboardLoading = true
    @State private var coachLinks: [CoachTraineeLink] = []
    @State private var coachProfiles: [Profile] = []
    @State private var membershipsCount: Int = 0
    @State private var membershipsSummary: String?
    @State private var primaryActiveMembership: Membership?
    @State private var activeMembershipsCount: Int = 0
    /// Пока true — блоки «Занятия с тренером» и «Мои абонементы» не показываем, чтобы не было прыжка контента.
    @State private var isProfileBlockDataLoading = true
    @State private var showHealthDetails = false
    @State private var mockHealthService = MockHealthService()
    @State private var showPostRegistrationOnboarding = false
    @State private var showGoalCreatedMeasurementOffer = false
    @State private var showPersonalRecords = false
    @State private var showQuickAddRecordSheet = false
    @State private var recordActivities: [RecordActivity] = []
    @State private var showMeasurementsAndCharts = false
    @State private var showAddMeasurementOrGoal = false
    @State private var progressAddSheetKind: ProgressAddSheetKind = .measurement
    @State private var standaloneMeasurementSavePulse = 0
    @State private var standaloneGoalSavePulse = 0
    @State private var standaloneMeasurementToolbar = ProgressAddFormToolbarState(canSave: false, isLoading: false)
    @State private var standaloneGoalToolbar = ProgressAddFormToolbarState(canSave: false, isLoading: false)

    private var shouldShowHealthIntegration: Bool {
        AppConfig.enableAppleHealthIntegration || profile.isDeveloperModeEnabled
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            homeTab
                .tag(0)
            progressTab
                .tag(1)
            workoutsTab
                .tag(2)
            profileTab
                .tag(3)
        }
        .tabViewStyle(.automatic)
        .onAppear {
            if let id = postRegistrationOnboardingProfileId, id == profile.id {
                showPostRegistrationOnboarding = true
                onClearPostRegistrationOnboarding?()
            }
        }
        .fullScreenCover(isPresented: $showPostRegistrationOnboarding) {
            TraineePostRegistrationOnboardingView(
                userName: profile.name,
                onAddMeasurementsGoals: {
                    showPostRegistrationOnboarding = false
                    progressAddSheetKind = .measurement
                    showAddMeasurementOrGoal = true
                },
                onAddAchievement: {
                    showPostRegistrationOnboarding = false
                    Task {
                        await ensureRecordActivitiesLoaded()
                        await MainActor.run { showQuickAddRecordSheet = true }
                    }
                },
                onSkip: { showPostRegistrationOnboarding = false }
            )
        }
        .fullScreenCover(isPresented: $showGoalCreatedMeasurementOffer) {
            GoalCreatedMeasurementOfferView(
                onAddMeasurement: {
                    showGoalCreatedMeasurementOffer = false
                    progressAddSheetKind = .measurement
                    showAddMeasurementOrGoal = true
                },
                onSkip: { showGoalCreatedMeasurementOffer = false }
            )
        }
        .sheet(isPresented: $showAddMeasurement) {
            MainSheet(
                title: "Добавить замер",
                onBack: { showAddMeasurement = false },
                trailing: {
                    Button {
                        standaloneMeasurementSavePulse += 1
                    } label: {
                        if standaloneMeasurementToolbar.isLoading {
                            ProgressView().scaleEffect(0.9)
                        } else {
                            Text("Сохранить")
                                .font(.body)
                                .fontWeight(.regular)
                        }
                    }
                    .disabled(!standaloneMeasurementToolbar.canSave || standaloneMeasurementToolbar.isLoading)
                },
                content: {
                    AddMeasurementView(
                        profile: profile,
                        lastMeasurement: measurements.sorted { $0.date > $1.date }.first,
                        embedsNavigationStack: false,
                        useHostNavigationChrome: true,
                        hostSavePulse: $standaloneMeasurementSavePulse,
                        onSave: { m in
                            let ok = await saveMeasurement(m)
                            guard ok else { return }
                            await MainActor.run { showAddMeasurement = false }
                            await showToastAfterSheetDismiss(kind: .success, message: "Замер сохранен")
                        },
                        onCancel: { showAddMeasurement = false }
                    )
                    .onPreferenceChange(ProgressAddFormToolbarPreferenceKey.self) { standaloneMeasurementToolbar = $0 }
                }
            )
            .mainSheetPresentation(.half)
        }
        .sheet(isPresented: $showAddGoal) {
            MainSheet(
                title: "Добавить цель",
                onBack: { showAddGoal = false },
                trailing: {
                    Button {
                        standaloneGoalSavePulse += 1
                    } label: {
                        if standaloneGoalToolbar.isLoading {
                            ProgressView().scaleEffect(0.9)
                        } else {
                            Text("Сохранить")
                                .font(.body)
                                .fontWeight(.regular)
                        }
                    }
                    .disabled(!standaloneGoalToolbar.canSave || standaloneGoalToolbar.isLoading)
                },
                content: {
                    AddGoalView(
                        profile: profile,
                        embedsNavigationStack: false,
                        useHostNavigationChrome: true,
                        hostSavePulse: $standaloneGoalSavePulse,
                        onSave: { goals in
                            let ok = await saveGoalsBatch(goals)
                            guard ok else { return }
                            await MainActor.run { showAddGoal = false }
                            await showToastAfterSheetDismiss(kind: .success, message: "Цели сохранены")
                            await MainActor.run {
                                showGoalCreatedMeasurementOffer = true
                            }
                        },
                        onCancel: { showAddGoal = false }
                    )
                    .onPreferenceChange(ProgressAddFormToolbarPreferenceKey.self) { standaloneGoalToolbar = $0 }
                }
            )
            .mainSheetPresentation(.half)
        }
        .sheet(isPresented: $showAddMeasurementOrGoal) {
            AddMeasurementOrGoalSheet(
                selectedKind: $progressAddSheetKind,
                profile: profile,
                lastMeasurement: measurements.sorted { $0.date > $1.date }.first,
                onSaveMeasurement: { m in
                    let ok = await saveMeasurement(m)
                    guard ok else { return }
                    await MainActor.run { showAddMeasurementOrGoal = false }
                    await showToastAfterSheetDismiss(kind: .success, message: "Замер сохранен")
                },
                onSaveGoals: { newGoals in
                    let ok = await saveGoalsBatch(newGoals)
                    guard ok else { return }
                    await MainActor.run {
                        showAddMeasurementOrGoal = false
                        showGoalCreatedMeasurementOffer = true
                    }
                    await showToastAfterSheetDismiss(kind: .success, message: "Цели сохранены")
                },
                onCancel: { showAddMeasurementOrGoal = false }
            )
            .mainSheetPresentation(.half)
        }
        .sheet(item: $addForTodayItem) { item in
            AddMeasurementForTodaySheet(
                profile: profile,
                metric: item.metric,
                lastMeasurement: measurements.sorted { $0.date > $1.date }.first,
                onSave: { m in
                    let ok = await saveMeasurement(m)
                    guard ok else { return }
                    await MainActor.run { addForTodayItem = nil }
                    await showToastAfterSheetDismiss(kind: .success, message: "Замер сохранен")
                },
                onCancel: { addForTodayItem = nil }
            )
            .mainSheetPresentation(.half)
        }
        .sheet(isPresented: $showConnectionTokenSheet) {
            ConnectionTokenSheet(
                profile: profile,
                tokenService: connectionTokenService,
                onDismiss: { showConnectionTokenSheet = false }
            )
            .mainSheetPresentation(.half)
        }
        .sheet(isPresented: $showQuickAddRecordSheet) {
            AddEditPersonalRecordSheet(
                profileId: profile.id,
                service: personalRecordService,
                activities: recordActivities,
                record: nil,
                onSaved: {
                    showQuickAddRecordSheet = false
                    Task { await showToastAfterSheetDismiss(kind: .success, message: "Достижение сохранено") }
                },
                onCancel: { showQuickAddRecordSheet = false }
            )
            .mainSheetPresentation(.half)
        }
        .task {
            await loadMeasurements()
            await loadGoals()
            await loadProfileBlockData()
            await MainActor.run { isDashboardLoading = false }
        }
        .overlay {
            if isDeleting {
                LoadingOverlayView(message: "Удаляю профиль")
            } else if isDeletingMeasurement {
                LoadingOverlayView(message: "Удаление…")
            }
        }
        .allowsHitTesting(!isDeleting && !isDeletingMeasurement)
        .appConfirmationDialog(
            title: "Удалить профиль?",
            message: "Все замеры и цели этого профиля будут удалены. Это действие нельзя отменить",
            isPresented: $showDeleteProfileConfirmation,
            confirmTitle: "Удалить",
            confirmRole: .destructive,
            onConfirm: {
                showDeleteProfileConfirmation = false
                Task {
                    isDeleting = true
                    await onDeleteProfile()
                    await MainActor.run { isDeleting = false }
                }
            },
            onCancel: {
                showDeleteProfileConfirmation = false
            }
        )
        .appConfirmationDialog(
            title: "Ошибка",
            message: errorMessage ?? "Произошла ошибка.",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ),
            confirmTitle: "OK",
            onConfirm: { errorMessage = nil },
            onCancel: { errorMessage = nil }
        )
    }

    private var workoutsTab: some View {
        TraineeWorkoutsView(
            profile: profile,
            linkService: linkService,
            visitService: visitService,
            eventService: eventService,
            calendarSummaryService: calendarSummaryService,
            membershipService: membershipService,
            profileService: profileService
        )
        .trackAPIScreen("Мой календарь")
        .tabItem {
            AppTablerIcon("calendar-default")
            Text("Мой календарь")
        }
    }

    private var homeTab: some View {
        NavigationStack {
            TraineeHomeView(
                profile: profile,
                measurements: measurements,
                goals: goals,
                coachLinks: coachLinks,
                coachProfiles: coachProfiles,
                membershipsCount: membershipsCount,
                activeMembershipsCount: activeMembershipsCount,
                isLoading: isProfileBlockDataLoading,
                onOpenProgress: { selectedTab = 1 },
                onOpenCalendar: { selectedTab = 2 },
                onShareWithCoach: { showConnectionTokenSheet = true },
                nutritionDestination: {
                    TraineeNutritionPlansView(
                        trainee: profile,
                        nutritionService: nutritionService,
                        profileService: profileService,
                        measurementService: measurementService,
                        fallbackCoachProfiles: coachProfiles
                    )
                },
                membershipsDestination: {
                    TraineeMembershipsView(
                        traineeProfileId: profile.id,
                        membershipService: membershipService,
                        visitService: visitService
                    )
                },
                calculatorsDestination: {
                    CalculatorsCatalogView(
                        calculatorsService: calculatorsService,
                        profileId: profile.id
                    )
                }
            )
            .navigationTitle("Главная")
            .navigationBarTitleDisplayMode(.inline)
        }
        .trackAPIScreen("Главная")
        .tabItem {
            AppTablerIcon("home-simple")
            Text("Главная")
        }
    }

    private var profileTab: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    profileHeader
                    blockGender
                    blockDateOfBirth
                    blockHeight
                    blockWeight
                    blockContact
                    blockNotes
                    blockDelete
                }
                .padding(.bottom, AppDesign.sectionSpacing)
            }
            .background(AdaptiveScreenBackground())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onSwitchProfile) {
                        AppTablerIcon("replace-user")
                            .font(.subheadline)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showEditProfile = true } label: {
                        AppTablerIcon("pencil-edit")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(
                profileId: profile.id,
                profileService: profileService,
                measurementService: measurementService,
                onSaved: { updated in
                    onProfileUpdated(updated)
                    showEditProfile = false
                },
                onCancel: { showEditProfile = false },
                onDismiss: { showEditProfile = false }
            )
            .mainSheetPresentation(.half)
        }
        .trackAPIScreen("Профиль")
        .tabItem {
            AppTablerIcon("user-circle")
            Text("Профиль")
        }
    }

    private var profileHeader: some View {
        let genderAccent = AppColors.avatarColor(gender: profile.gender, defaultColor: AppColors.accent)
        return VStack(spacing: 16) {
            ZStack {
                LinearGradient(
                    colors: [
                        genderAccent.opacity(0.25),
                        genderAccent.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.avatarCornerRadiusLarge))

                AppTablerIcon("file-default")
                    .appIcon(.s32)
                    .foregroundStyle(.white)
            }
            VStack(spacing: 4) {
                Button {
                    showEditProfile = true
                } label: {
                    Text(profile.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(PressableButtonStyle())

                if let age = profile.ageFormatted, !age.isEmpty {
                    Text(age)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    @ViewBuilder
    private var profileTopBlocks: some View {
        if isProfileBlockDataLoading {
            VStack(spacing: AppDesign.blockSpacing) {
                profileCoachPlaceholder
                profileMembershipsPlaceholder
            }
            .padding(.horizontal, AppDesign.cardPadding)
            .padding(.top, AppDesign.blockSpacing)
        } else {
            VStack(spacing: AppDesign.blockSpacing) {
                profileCoachBlock
                profileMembershipsBlockIfAny
                profileNutritionBlockIfAny
            }
            .padding(.horizontal, AppDesign.cardPadding)
            .padding(.top, AppDesign.blockSpacing)
        }
    }

    private var profileCoachBlock: some View {
        Group {
            if !coachLinks.isEmpty {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Занятия с тренером")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        if coachProfiles.isEmpty {
                            Text(profileCoachSubtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(coachProfiles.prefix(2).enumerated()), id: \.offset) { _, coach in
                                    let gym = coach.gymName?.trimmingCharacters(in: .whitespacesAndNewlines)
                                    Text([coach.name, (gym?.isEmpty == false ? gym : nil)].compactMap { $0 }.joined(separator: " · "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                if coachLinks.count > 2 {
                                    Text("И ещё \(coachLinks.count - 2) тренера(ов)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                    Spacer()
                    if coachLinks.count > 1 {
                        Text("+\(coachLinks.count - 1)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(AppColors.tertiarySystemFill, in: Capsule())
                    }
                }
                .padding(AppDesign.cardPadding)
                .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
            }
        }
    }

    private var profileCoachPlaceholder: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.tertiarySystemFill)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppColors.tertiarySystemFill)
                    .frame(width: 180, height: 14)
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppColors.tertiarySystemFill)
                    .frame(width: 220, height: 12)
            }
            Spacer()
        }
        .padding(AppDesign.cardPadding)
        .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
    }

    private var profileCoachSubtitle: String {
        guard let first = coachProfiles.first else {
            return coachLinks.count == 1 ? "К вам привязан 1 тренер" : "К вам привязано тренеров: \(coachLinks.count)"
        }
        var parts: [String] = []
        if !first.name.isEmpty { parts.append(first.name) }
        if let gym = first.gymName?.trimmingCharacters(in: .whitespacesAndNewlines), !gym.isEmpty {
            parts.append(gym)
        }
        let main = parts.joined(separator: " · ")
        if coachLinks.count > 1 {
            let extra = coachLinks.count - 1
            return main.isEmpty ? "И ещё \(extra) тренеров" : "\(main), и ещё \(extra) тренеров"
        }
        return main.isEmpty ? "К вам привязан тренер" : main
    }

    @ViewBuilder
    private var profileMembershipsBlockIfAny: some View {
        if membershipsCount > 0 {
            NavigationLink {
                TraineeMembershipsView(
                    traineeProfileId: profile.id,
                    membershipService: membershipService,
                    visitService: visitService
                )
            } label: {
                WideActionButtonToOneColumn(
                    icon: "tag",
                    title: "Мои абонементы",
                    prominentTitle: true,
                    iconColor: AppColors.accent,
                    chevronColor: AppColors.secondaryLabel
                ) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let m = primaryActiveMembership {
                            MembershipProgressInlineView(membership: m, tint: AppColors.accent)
                            if activeMembershipsCount > 1 {
                                Text("и ещё \(activeMembershipsCount - 1)")
                                    .font(.caption2)
                                    .foregroundStyle(AppColors.tertiaryLabel)
                                    .lineLimit(1)
                            }
                        } else if let s = membershipsSummary, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(s)
                                .font(.caption)
                                .foregroundStyle(AppColors.secondaryLabel)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    @ViewBuilder
    private var profileNutritionBlockIfAny: some View {
        if !coachLinks.isEmpty {
            NavigationLink {
                TraineeNutritionPlansView(
                    trainee: profile,
                    nutritionService: nutritionService,
                    profileService: profileService,
                    measurementService: measurementService,
                    fallbackCoachProfiles: coachProfiles
                )
            } label: {
                WideActionButtonToOneColumn(
                    icon: "coffee-cup-01",
                    title: "Питание",
                    subtitle: coachLinks.count == 1 ? "План от тренера" : "Планы от \(coachLinks.count) тренеров",
                    prominentTitle: true,
                    iconColor: AppColors.accent,
                    chevronColor: AppColors.secondaryLabel
                )
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private var profileMembershipsPlaceholder: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.tertiarySystemFill)
                .frame(width: 28, height: 28)
            RoundedRectangle(cornerRadius: 6)
                .fill(AppColors.tertiarySystemFill)
                .frame(width: 140, height: 14)
            Spacer()
            RoundedRectangle(cornerRadius: 6)
                .fill(AppColors.tertiarySystemFill)
                .frame(width: 18, height: 14)
        }
        .padding(AppDesign.cardPadding)
        .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
    }

    /// Загружает связи с тренерами, профили тренеров и количество абонементов; по завершении обновляет состояние одним разом.
    private func loadProfileBlockData() async {
        async let links = fetchCoachLinksForProfileBlock()
        async let membershipsInfo = fetchMembershipsInfoForProfileBlock()
        let (loadedLinks, loadedMembershipsInfo) = await (links, membershipsInfo)
        var loadedProfiles: [Profile] = []
        for link in loadedLinks {
            if let p = try? await profileService.fetchProfile(id: link.coachProfileId) {
                loadedProfiles.append(p)
            }
        }
        await MainActor.run {
            coachLinks = loadedLinks
            coachProfiles = loadedProfiles
            membershipsCount = loadedMembershipsInfo.count
            membershipsSummary = loadedMembershipsInfo.summary
            primaryActiveMembership = loadedMembershipsInfo.primaryActive
            activeMembershipsCount = loadedMembershipsInfo.activeCount
            isProfileBlockDataLoading = false
        }
    }

    private func fetchCoachLinksForProfileBlock() async -> [CoachTraineeLink] {
        do {
            return try await linkService.fetchLinksForTrainee(traineeProfileId: profile.id)
        } catch {
            return []
        }
    }

    private struct MembershipsInfo {
        let count: Int
        let activeCount: Int
        let summary: String?
        let primaryActive: Membership?
    }

    private func fetchMembershipsInfoForProfileBlock() async -> MembershipsInfo {
        do {
            let list = try await membershipService.fetchMembershipsForTrainee(traineeProfileId: profile.id)
            let active = list.filter { $0.isActive }
            // Приоритет: абонемент по занятиям → по дате создания (чем раньше, тем выше).
            let primary = active.sorted(by: { lhs, rhs in
                if lhs.kind != rhs.kind {
                    return lhs.kind == .byVisits
                }
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.id < rhs.id
            }).first
            let summary = primary.map { membershipSummaryLine($0, activeCount: active.count) }
            return MembershipsInfo(count: list.count, activeCount: active.count, summary: summary, primaryActive: primary)
        } catch {
            return MembershipsInfo(count: 0, activeCount: 0, summary: nil, primaryActive: nil)
        }
    }

    private func membershipSummaryLine(_ m: Membership, activeCount: Int) -> String {
        let calendar = Calendar.current
        let tail: String? = activeCount > 1 ? " · и ещё \(activeCount - 1)" : nil
        switch m.kind {
        case .byVisits:
            let base = "Осталось \(m.remainingSessions) занятий"
            return base + (tail ?? "")
        case .unlimited:
            guard let end = m.effectiveEndDate else {
                let base = "Активный абонемент"
                return base + (tail ?? "")
            }
            let startDay = m.startDate.map { calendar.startOfDay(for: $0) }
            let endDay = calendar.startOfDay(for: end)
            let now = calendar.startOfDay(for: Date())
            let left = now > endDay ? 0 : (max(0, calendar.dateComponents([.day], from: now, to: endDay).day ?? 0) + 1)
            let total: Int? = startDay.map { max(0, (calendar.dateComponents([.day], from: $0, to: endDay).day ?? 0)) + 1 }
            let base: String
            if let total {
                base = "Осталось \(left) из \(total) дней · до \(end.formattedRuDayMonth)"
            } else {
                base = "До \(end.formattedRuDayMonth)"
            }
            return base + (tail ?? "")
        }
    }

    private var blockGender: some View {
        ActionBlockRow(icon: "user-default", title: "Пол", value: profile.gender?.displayName ?? "Не указан")
            .actionBlockStyle()
    }

    @ViewBuilder
    private var blockDateOfBirth: some View {
        if profile.dateOfBirth != nil {
            ActionBlockRow(
                icon: "calendar-default",
                title: "Дата рождения",
                value: [profile.dateOfBirth?.formattedRuShort, profile.ageFormatted].compactMap { $0 }.joined(separator: " · ")
            )
            .actionBlockStyle()
        }
    }

    @ViewBuilder
    private var blockHeight: some View {
        if let h = profile.height {
            ActionBlockRow(icon: "pencil-scale", title: "Рост", value: "\(h.measurementFormatted) см")
                .actionBlockStyle()
        }
    }

    @ViewBuilder
    private var blockWeight: some View {
        if let w = profile.weight {
            ActionBlockRow(icon: "pencil-scale", title: "Вес", value: "\(w.measurementFormatted) кг")
                .actionBlockStyle()
        }
    }

    @ViewBuilder
    private var blockNotes: some View {
        if let notes = profile.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
            NotesBlockView(notes: notes)
        }
    }

    @ViewBuilder
    private var blockContact: some View {
        ProfileContactSection(
            phoneNumber: profile.phoneNumber,
            telegramUsername: profile.telegramUsername
        )
    }

    private var blockDelete: some View {
        ProfileManagementSection(
            showsDeveloperSettings: profile.isDeveloperModeEnabled,
            deleteSubtitle: "Удаляется только этот профиль. Замеры и цели будут удалены. Вход в аккаунт сохранится",
            onDeleteTap: { showDeleteProfileConfirmation = true }
        ) {
            DeveloperSettingsView(profile: profile)
        }
    }

    private var progressTab: some View {
        NavigationStack {
            ProgressHubView(
                measurements: measurements,
                goals: goals,
                showHealthIntegration: shouldShowHealthIntegration,
                onAddMeasurementOrGoal: {
                    progressAddSheetKind = .measurement
                    showAddMeasurementOrGoal = true
                },
                onAddRecord: {
                    Task {
                        await ensureRecordActivitiesLoaded()
                        await MainActor.run { showQuickAddRecordSheet = true }
                    }
                },
                onOpenMeasurementsAndCharts: { showMeasurementsAndCharts = true },
                onOpenHealth: { showHealthDetails = true },
                onOpenRecords: {
                    showPersonalRecords = true
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AdaptiveScreenBackground())
            .navigationDestination(isPresented: $showMeasurementsAndCharts) {
                MeasurementsAndChartsScreen(
                    profile: profile,
                    measurements: measurements,
                    goals: goals
                )
            }
            .navigationDestination(isPresented: $showHealthDetails) {
                HealthMetricsView(
                    service: effectiveHealthService,
                    isDemoMode: healthDemoModeEnabled
                )
            }
            .overlay {
                if isDashboardLoading {
                    LoadingOverlayView(message: "Загружаю")
                }
            }
            .navigationDestination(isPresented: $showPersonalRecords) {
                PersonalRecordsView(
                    profile: profile,
                    service: personalRecordService,
                    readOnly: false
                )
            }
        }
        .trackAPIScreen("Прогресс")
        .tabItem {
            AppTablerIcon("grid-dashboard-circle")
            Text("Прогресс")
        }
    }

    private func loadMeasurements() async {
        do {
            let list = try await measurementService.fetchMeasurements(profileId: profile.id)
            await MainActor.run { measurements = list }
        } catch {
            await MainActor.run {
                if let msg = AppErrors.userMessageIfNeeded(for: error) { errorMessage = msg }
            }
        }
    }

    private var blockCalculators: some View {
        NavigationLink {
            CalculatorsCatalogView(
                calculatorsService: calculatorsService,
                profileId: profile.id
            )
        } label: {
            WideActionButtonToOneColumn(
                icon: "grid-dashboard-02",
                title: "Калькуляторы",
                subtitle: "Быстрые расчёты для прогресса",
                prominentTitle: true,
                iconColor: AppColors.accent,
                chevronColor: AppColors.secondaryLabel
            )
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.horizontal, AppDesign.cardPadding)
        .padding(.top, AppDesign.blockSpacing)
    }

    private func loadGoals() async {
        do {
            let list = try await goalService.fetchGoals(profileId: profile.id)
            await MainActor.run { goals = list }
        } catch {
            await MainActor.run { goals = [] }
        }
    }

    private func ensureRecordActivitiesLoaded() async {
        if !recordActivities.isEmpty { return }
        do {
            let activities = try await personalRecordService.fetchActivities()
            await MainActor.run { recordActivities = activities }
        } catch {
            await MainActor.run { recordActivities = [] }
        }
    }

    private func saveMeasurement(_ m: Measurement) async -> Bool {
        do {
            try await measurementService.saveMeasurement(m)
            if let newWeight = m.weight {
                try await syncProfileWeightFromMeasurement(measurementDate: m.date, weightKg: newWeight)
            }
            await MainActor.run {
                var next = measurements.filter { $0.id != m.id }
                next.insert(m, at: next.firstIndex(where: { $0.date < m.date }) ?? next.endIndex)
                measurements = next
            }
            AppDesign.triggerSuccessHaptic()
            await loadMeasurements()
            return true
        } catch {
            await MainActor.run {
                errorMessage = nil
                ToastCenter.shared.error(from: error, fallback: "Не удалось сохранить замер")
            }
            return false
        }
    }

    private func syncProfileWeightFromMeasurement(measurementDate: Date, weightKg: Double) async throws {
        let latestKnownWeightDate = measurements
            .filter { $0.weight != nil }
            .map(\.date)
            .max()
        guard latestKnownWeightDate == nil || measurementDate >= latestKnownWeightDate! else { return }

        try await profileService.updateProfile(
            id: profile.id,
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
            ownerCoachProfileId: profile.ownerCoachProfileId,
            mergedIntoProfileId: profile.mergedIntoProfileId,
            height: profile.height,
            weight: weightKg
        )

        let updatedProfile = Profile(
            id: profile.id,
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
            ownerCoachProfileId: profile.ownerCoachProfileId,
            mergedIntoProfileId: profile.mergedIntoProfileId,
            height: profile.height,
            weight: weightKg,
            developerMode: profile.developerMode
        )
        await MainActor.run {
            onProfileUpdated(updatedProfile)
        }
    }

    private func saveGoal(_ g: Goal) async {
        do {
            try await goalService.saveGoal(g)
            await loadGoals()
        } catch {
            if let msg = AppErrors.userMessageIfNeeded(for: error) { await MainActor.run { errorMessage = msg } }
        }
    }

    private func saveGoalsBatch(_ goals: [Goal]) async -> Bool {
        do {
            for g in goals {
                try await goalService.saveGoal(g)
            }
            await loadGoals()
            await MainActor.run { AppDesign.triggerSuccessHaptic() }
            return true
        } catch {
            await MainActor.run {
                errorMessage = nil
                ToastCenter.shared.error(from: error, fallback: "Не удалось сохранить цели")
            }
            return false
        }
    }

    private func deleteGoal(_ goal: Goal) async {
        do {
            try await goalService.deleteGoal(goal)
            await loadGoals()
            await MainActor.run { ToastCenter.shared.success("Цель удалена") }
        } catch {
            await MainActor.run {
                errorMessage = nil
                ToastCenter.shared.error(from: error, fallback: "Не удалось удалить цель")
            }
        }
    }

    private func deleteMeasurement(_ m: Measurement) async {
        await MainActor.run { isDeletingMeasurement = true }
        do {
            try await measurementService.deleteMeasurement(m)
            await loadMeasurements()
            await MainActor.run { ToastCenter.shared.success("Замер удален") }
        } catch {
            await MainActor.run {
                errorMessage = nil
                ToastCenter.shared.error(from: error, fallback: "Не удалось удалить замер")
            }
        }
        await MainActor.run { isDeletingMeasurement = false }
    }

    private var effectiveHealthService: HealthServiceProtocol {
        healthDemoModeEnabled ? mockHealthService : healthService
    }

    private func showToastAfterSheetDismiss(kind: ToastKind, message: String) async {
        // Небольшая пауза гарантирует, что тост рисуется уже поверх закрытого sheet.
        try? await Task.sleep(nanoseconds: 350_000_000)
        await MainActor.run {
            ToastCenter.shared.show(kind: kind, message: message)
        }
    }
}

#Preview {
    let client = APIClient(baseURL: ApiConfig.baseURL, getIDToken: { _ in nil })
    TraineeMainView(
        profile: Profile(id: "1", userId: "u1", type: .trainee, name: "Мой дневник"),
        measurementService: MockMeasurementService(),
        goalService: MockGoalService(),
        personalRecordService: MockPersonalRecordService(),
        connectionTokenService: MockConnectionTokenService(),
        profileService: MockProfileService(),
        membershipService: MockMembershipService(),
        visitService: MockVisitService(),
        eventService: MockEventService(),
        linkService: MockCoachTraineeLinkService(),
        calendarSummaryService: MockCalendarSummaryService(),
        healthService: MockHealthService(),
        nutritionService: MockNutritionService(),
        calculatorsService: APICalculatorsService(client: client),
        onSwitchProfile: {},
        onDeleteProfile: { },
        onProfileUpdated: { _ in }
    )
}

private struct AddForTodaySheetItem: Identifiable {
    let metric: MeasurementType
    var id: String { metric.rawValue }
}
