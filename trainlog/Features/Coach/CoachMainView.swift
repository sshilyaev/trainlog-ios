//
//  CoachMainView.swift
//  TrainLog
//

import SwiftUI

struct CoachMainView: View {
    @EnvironmentObject private var offlineMode: OfflineMode
    let profile: Profile
    let onSwitchProfile: () -> Void
    let onDeleteProfile: () async -> Void
    let onProfileUpdated: (Profile) -> Void
    let linkService: CoachTraineeLinkServiceProtocol
    let profileService: ProfileServiceProtocol
    let measurementService: MeasurementServiceProtocol
    let goalService: GoalServiceProtocol
    let personalRecordService: PersonalRecordServiceProtocol
    let connectionTokenService: ConnectionTokenServiceProtocol
    let membershipService: MembershipServiceProtocol
    let visitService: VisitServiceProtocol
    let eventService: EventServiceProtocol
    let managedTraineeMergeService: ManagedTraineeMergeServiceProtocol
    let coachStatisticsService: CoachStatisticsServiceProtocol
    let coachOverviewService: CoachOverviewServiceProtocol
    let calendarSummaryService: CalendarSummaryServiceProtocol
    let nutritionService: NutritionServiceProtocol
    let calculatorsService: CalculatorsServiceProtocol
    let myTraineeProfiles: [Profile]
    /// Если равен profile.id — показываем онбординг после регистрации (добавить подопечного → предложить абонемент).
    var postRegistrationOnboardingProfileId: String?
    var onClearPostRegistrationOnboarding: (() -> Void)?

    @State private var traineeItems: [TraineeItem] = []
    @State private var searchText = ""
    @State private var isSearchPresented = false
    /// 0 = Главная, 1 = Подопечные, 2 = Профиль.
    @State private var selectedTab = 0
    @State private var showDeleteProfileConfirmation = false
    @State private var showEditProfile = false
    @State private var isDeleting = false
    @State private var isLoadingTrainees = false
    @State private var isReloadQueued = false
    @State private var showArchiveConfirmation = false
    @State private var archiveTarget: (item: TraineeItem, archived: Bool)?
    @State private var isArchiving = false
    @State private var editTraineeItem: TraineeItem?
    private struct QuickVisitRequest: Identifiable {
        let id = UUID()
        let item: TraineeItem
        let date: Date?
    }
    private struct QuickEventRequest: Identifiable {
        let id = UUID()
        let item: TraineeItem
        let date: Date
    }

    @State private var quickVisitRequest: QuickVisitRequest?
    @State private var quickEventRequest: QuickEventRequest?
    @State private var expandedTraineeIds: Set<String> = []
    @State private var traineesScrollToId: String?
    /// false = Активные, true = В архиве
    @State private var traineesShowingArchived = false
    /// Сортировка списка подопечных
    @State private var traineeSortOrder: TraineeSortOrder = .byDisplayNameAsc
    /// Онбординг после регистрации: добавить подопечного, затем предложить абонемент.
    @State private var showPostRegistrationOnboarding = false
    @State private var showAddTraineeFromOnboarding = false
    @State private var linkedIdsBeforeAdd: Set<String>?
    /// Показываем продающую страницу «Создать абонемент» после добавления подопечного (всегда: и из онбординга, и с экрана списка).
    @State private var traineeForMembershipOffer: TraineeItem?
    @State private var traineeForAddMembershipSheet: TraineeItem?
    @State private var showAddTraineeByNavigation = false
    @State private var isCreatingMembershipFromOnboarding = false
    @State private var weekSummaryClients: Int = 0
    @State private var weekSummaryOneOffVisits: Int = 0
    @State private var weekSummarySubscriptionVisits: Int = 0
    @State private var weekSummaryRangeCaption: String = ""
    @State private var homeNavigationPath = NavigationPath()

    private var filteredTraineeItems: [TraineeItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var base = query.isEmpty ? traineeItems : traineeItems.filter { item in
            let name = item.profile.name.lowercased()
            let displayName = (item.link.displayName ?? "").lowercased()
            return name.contains(query) || displayName.contains(query)
        }
        base.sort { a, b in
            if a.link.isArchived != b.link.isArchived { return !a.link.isArchived && b.link.isArchived }
            switch traineeSortOrder {
            case .byDisplayNameAsc:
                return displayNameForSort(a).localizedCaseInsensitiveCompare(displayNameForSort(b)) == .orderedAscending
            case .byDisplayNameDesc:
                return displayNameForSort(a).localizedCaseInsensitiveCompare(displayNameForSort(b)) == .orderedDescending
            case .byDateAddedNewest:
                return a.link.createdAt > b.link.createdAt
            case .byDateAddedOldest:
                return a.link.createdAt < b.link.createdAt
            }
        }
        return base
    }

    private func displayNameForSort(_ item: TraineeItem) -> String {
        (item.link.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? item.profile.name
    }

    private var activeTraineeItems: [TraineeItem] {
        filteredTraineeItems.filter { !$0.link.isArchived }
    }

    private var archivedTraineeItems: [TraineeItem] {
        filteredTraineeItems.filter(\.link.isArchived)
    }

    private var homeQuickPickRows: [CoachHomeQuickPickRow] {
        traineeItems
            .filter { !$0.link.isArchived }
            .sorted { displayNameForSort($0).localizedCaseInsensitiveCompare(displayNameForSort($1)) == .orderedAscending }
            .map { CoachHomeQuickPickRow(id: $0.id, title: displayNameForSort($0)) }
    }

    // MARK: - Вкладка «Подопечные» (новый экран)

    private var traineesTabContent: some View {
        TraineesListScreen(
            activeItems: activeTraineeItems,
            archivedItems: archivedTraineeItems,
            showingArchived: $traineesShowingArchived,
            searchText: $searchText,
            isEmptySearch: !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            scrollToItemId: $traineesScrollToId,
            isLoadingTrainees: isLoadingTrainees,
            rowContent: { item, isArchived in
                traineeRow(item: item, isArchived: isArchived)
            },
            activeEmptyContent: {
            if isLoadingTrainees {
                TraineeListSkeletonView()
            } else {
            VStack(spacing: 18) {
                Spacer().frame(height: 16)
                AppTablerIcon("user-default")
                    .appIcon(.s44)
                    .foregroundStyle(AppColors.accent.opacity(0.85))
                    .symbolRenderingMode(.hierarchical)
                    .emptyStateIconPulse()
                Text("Пока нет подопечных")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Добавьте клиента по коду или подключите свой профиль дневника — и начните отмечать посещения.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                Text("Совет: можно отмечать посещения даже офлайн — синхронизация произойдёт позже.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 4)
                Button {
                    linkedIdsBeforeAdd = Set(traineeItems.map(\.profile.id))
                    showAddTraineeByNavigation = true
                } label: {
                    Text("Добавить подопечного")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 32)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            }
            },
            activeSearchEmptyContent: {
            ContentUnavailableView(
                "Нет результатов",
                image: "tabler-outline-search",
                description: Text("По запросу «\(searchText)» никого не найдено.")
            )
            .padding(.vertical, 32)
            },
            archivedEmptyContent: {
            if isLoadingTrainees {
                TraineeListSkeletonView()
            } else {
            VStack(spacing: 18) {
                Spacer().frame(height: 16)
                AppTablerIcon("folder-default")
                    .appIcon(.s44)
                    .foregroundStyle(.secondary.opacity(0.8))
                    .symbolRenderingMode(.hierarchical)
                    .emptyStateIconPulse()
                Text("В архиве пусто")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Сюда попадают клиенты, которые перестали заниматься. Вы всегда сможете вернуть их обратно.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            }
            },
            archivedSearchEmptyContent: {
                ContentUnavailableView(
                    "Нет результатов",
                    image: "tabler-outline-search",
                    description: Text("По запросу «\(searchText)» в архиве никого не найдено.")
                )
                .padding(.vertical, 32)
            }
        )
    }

    private func traineeRow(item: TraineeItem, isArchived: Bool) -> some View {
        VStack(spacing: 0) {
            NavigationLink {
                clientCardView(for: item)
            } label: {
                TraineeCardRow(
                    profile: item.profile,
                    displayName: item.link.displayName,
                    membershipSummary: item.membershipSummary,
                    isArchived: isArchived,
                    isExpanded: expandedTraineeIds.contains(item.id),
                    onToggleExpand: !isArchived ? {
                        let willExpand = !expandedTraineeIds.contains(item.id)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if willExpand { expandedTraineeIds.insert(item.id) }
                            else { expandedTraineeIds.remove(item.id) }
                        }
                        if willExpand {
                            traineesScrollToId = item.id
                        }
                    } : nil,
                    onQuickVisit: !isArchived ? {
                        quickVisitRequest = QuickVisitRequest(item: item, date: nil)
                    } : nil,
                    onQuickEvent: nil,
                    onEdit: { editTraineeItem = item },
                    onArchive: isArchived ? nil : { archiveTarget = (item: item, archived: true); showArchiveConfirmation = true },
                    onUnarchive: isArchived ? { archiveTarget = (item: item, archived: false); showArchiveConfirmation = true } : nil
                )
            }
            .buttonStyle(.plain)
            .accessibilityHint("Открывает карточку: календарь, абонементы, питание и замеры")

            if expandedTraineeIds.contains(item.id), !isArchived {
                TraineeInlineCalendar(
                    coachProfileId: profile.id,
                    trainee: item.profile,
                    visitService: visitService,
                    eventService: eventService,
                    membershipService: membershipService,
                    onAddVisit: { date in
                        quickVisitRequest = QuickVisitRequest(item: item, date: date)
                    },
                    onAddEvent: { date in
                        quickEventRequest = QuickEventRequest(item: item, date: date)
                    }
                )
                .padding(.top, 2)
                .transition(.opacity)
            }
        }
        .animation(nil, value: expandedTraineeIds) // анимацию делаем только для вставки календаря
    }

    @ViewBuilder
    private func clientCardView(for item: TraineeItem) -> some View {
        ClientCardView(
            trainee: item.profile,
            isArchived: item.link.isArchived,
            link: item.link,
            profileService: profileService,
            measurementService: measurementService,
            goalService: goalService,
            personalRecordService: personalRecordService,
            membershipService: membershipService,
            visitService: visitService,
            eventService: eventService,
            nutritionService: nutritionService,
            calendarSummaryService: calendarSummaryService,
            connectionTokenService: connectionTokenService,
            managedTraineeMergeService: managedTraineeMergeService,
            coachProfileId: profile.id,
            linkService: linkService,
            onUnlink: { Task { await loadTrainees(forceNetwork: true) } },
            onArchiveChanged: { await loadTrainees(forceNetwork: true) },
            onTraineeEdited: { Task { await loadTrainees(forceNetwork: true) } }
        )
    }

    /// Добавление с «Главной»: один `navigationDestination` остаётся на стеке «Подопечные».
    private func openAddTraineeFromHome() {
        linkedIdsBeforeAdd = Set(traineeItems.map(\.profile.id))
        selectedTab = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            showAddTraineeByNavigation = true
        }
    }

    private var homeTab: some View {
        NavigationStack(path: $homeNavigationPath) {
            CoachHomeView(
                weekSummaryClients: weekSummaryClients,
                weekSummaryOneOffVisits: weekSummaryOneOffVisits,
                weekSummarySubscriptionVisits: weekSummarySubscriptionVisits,
                weekSummaryRangeCaption: weekSummaryRangeCaption,
                isLoading: isLoadingTrainees,
                coachProfileId: profile.id,
                calculatorsService: calculatorsService,
                coachStatisticsService: coachStatisticsService,
                quickPickRows: homeQuickPickRows,
                onAddTrainee: { openAddTraineeFromHome() },
                onOpenAllTrainees: { selectedTab = 1 },
                onSelectQuickPickTrainee: { homeNavigationPath.append($0) }
            )
            .navigationTitle("Главная")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await loadTrainees() }
            .navigationDestination(for: String.self) { linkId in
                if let item = traineeItems.first(where: { $0.id == linkId }) {
                    clientCardView(for: item)
                } else {
                    ContentUnavailableView(
                        "Не найдено",
                        image: "tabler-outline-circle-x",
                        description: Text("Обновите список на вкладке «Подопечные».")
                    )
                }
            }
        }
        .trackAPIScreen("Главная")
        .tabItem {
            AppTablerIcon("home-simple")
            Text("Главная")
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            homeTab
                .tag(0)

            NavigationStack {
                Group {
                    if isSearchPresented {
                        traineesTabContent
                            .searchable(text: $searchText, isPresented: $isSearchPresented, prompt: "По имени")
                    } else {
                        traineesTabContent
                    }
                }
                .navigationTitle("Подопечные")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear { expandedTraineeIds = [] }
                .refreshable { await loadTrainees() }
                .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            HStack(spacing: 12) {
                                Menu {
                                    Section {
                                        Button {
                                            traineeSortOrder = .byDisplayNameAsc
                                        } label: {
                                            HStack {
                                                Text("По имени (А–Я)")
                                                Spacer()
                                                if traineeSortOrder == .byDisplayNameAsc {
                                                    AppTablerIcon("check-tick-circle")
                                                        .foregroundStyle(AppColors.accent)
                                                }
                                            }
                                        }
                                        Button {
                                            traineeSortOrder = .byDisplayNameDesc
                                        } label: {
                                            HStack {
                                                Text("По имени (Я–А)")
                                                Spacer()
                                                if traineeSortOrder == .byDisplayNameDesc {
                                                    AppTablerIcon("check-tick-circle")
                                                        .foregroundStyle(AppColors.accent)
                                                }
                                            }
                                        }
                                    }
                                    Section {
                                        Button {
                                            traineeSortOrder = .byDateAddedNewest
                                        } label: {
                                            HStack {
                                                Text("Сначала новые")
                                                Spacer()
                                                if traineeSortOrder == .byDateAddedNewest {
                                                    AppTablerIcon("check-tick-circle")
                                                        .foregroundStyle(AppColors.accent)
                                                }
                                            }
                                        }
                                        Button {
                                            traineeSortOrder = .byDateAddedOldest
                                        } label: {
                                            HStack {
                                                Text("Сначала старые")
                                                Spacer()
                                                if traineeSortOrder == .byDateAddedOldest {
                                                    AppTablerIcon("check-tick-circle")
                                                        .foregroundStyle(AppColors.accent)
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    AppTablerIcon("arrows-sort")
                                        .font(.body)
                                }
                                .buttonStyle(PressableButtonStyle())
                                Button {
                                    isSearchPresented = true
                                } label: {
                                    AppTablerIcon("search-default")
                                        .font(.body)
                                }
                                .buttonStyle(PressableButtonStyle())
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            if !traineesShowingArchived {
                                Button {
                                    linkedIdsBeforeAdd = Set(traineeItems.map(\.profile.id))
                                    showAddTraineeByNavigation = true
                                } label: {
                                    AppTablerIcon("plus-square")
                                        .font(.body.weight(.semibold))
                                }
                                .buttonStyle(PressableButtonStyle())
                            }
                        }
                    }
                .navigationDestination(isPresented: $showAddTraineeByNavigation) {
                    AddTraineeView(
                        coachProfile: profile,
                        myTraineeProfiles: myTraineeProfiles,
                        linkedTraineeIds: Set(traineeItems.map(\.profile.id)),
                        linkService: linkService,
                        profileService: profileService,
                        connectionTokenService: connectionTokenService,
                        onLinkAdded: {
                            showAddTraineeByNavigation = false
                            Task {
                                await MainActor.run { selectedTab = 1 }
                                await loadTrainees(forceNetwork: true)
                                await MainActor.run {
                                    guard let before = linkedIdsBeforeAdd else { return }
                                    let after = Set(traineeItems.map(\.profile.id))
                                    let added = after.subtracting(before)
                                    linkedIdsBeforeAdd = nil
                                    if let id = added.first,
                                       let item = traineeItems.first(where: { $0.profile.id == id }) {
                                        traineeForMembershipOffer = item
                                    }
                                }
                            }
                        }
                    )
                }
            }
            .trackAPIScreen("Подопечные")
            .tabItem {
                AppTablerIcon("user-default")
                Text("Подопечные")
            }
            .tag(1)

            profileTab
                .tag(2)
        }
        .tabViewStyle(.automatic)
        .onAppear {
            if let id = postRegistrationOnboardingProfileId, id == profile.id {
                showPostRegistrationOnboarding = true
                onClearPostRegistrationOnboarding?()
            }
        }
        .task {
            await loadTrainees(forceNetwork: false)
        }
        .fullScreenCover(isPresented: $showPostRegistrationOnboarding) {
            CoachPostRegistrationOnboardingView(
                userName: profile.name,
                onAddTrainee: {
                    linkedIdsBeforeAdd = Set(traineeItems.map(\.profile.id))
                    showPostRegistrationOnboarding = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showAddTraineeFromOnboarding = true
                    }
                },
                onSkip: { showPostRegistrationOnboarding = false }
            )
        }
        .fullScreenCover(isPresented: $showAddTraineeFromOnboarding) {
            NavigationStack {
                AddTraineeView(
                coachProfile: profile,
                myTraineeProfiles: myTraineeProfiles,
                linkedTraineeIds: Set(traineeItems.map(\.profile.id)),
                linkService: linkService,
                profileService: profileService,
                connectionTokenService: connectionTokenService,
                onLinkAdded: {
                    showAddTraineeFromOnboarding = false
                    Task {
                        await loadTrainees(forceNetwork: true)
                        await MainActor.run {
                            guard let before = linkedIdsBeforeAdd else { return }
                            let after = Set(traineeItems.map(\.profile.id))
                            let added = after.subtracting(before)
                            linkedIdsBeforeAdd = nil
                            if let id = added.first,
                               let item = traineeItems.first(where: { $0.profile.id == id }) {
                                traineeForMembershipOffer = item
                            }
                        }
                    }
                }
            )
            }
        }
        .sheet(item: $traineeForMembershipOffer) { item in
            MembershipOfferView(
                traineeName: item.link.displayName?.trimmingCharacters(in: .whitespaces).isEmpty == false ? (item.link.displayName ?? item.profile.name) : item.profile.name,
                onCreateMembership: {
                    let trainee = item
                    traineeForMembershipOffer = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        traineeForAddMembershipSheet = trainee
                    }
                },
                onSkip: { traineeForMembershipOffer = nil }
            )
        }
        .sheet(item: $traineeForAddMembershipSheet) { item in
            AddMembershipSheet(
                isCreating: $isCreatingMembershipFromOnboarding,
                onCreate: { kind, totalSessions, startDate, endDate, price in
                    Task {
                        await MainActor.run { isCreatingMembershipFromOnboarding = true }
                        do {
                            _ = try await membershipService.createMembership(
                                coachProfileId: profile.id,
                                traineeProfileId: item.profile.id,
                                kind: kind,
                                totalSessions: totalSessions,
                                startDate: startDate,
                                endDate: endDate,
                                priceRub: price
                            )
                            await loadTrainees(forceNetwork: true)
                            await MainActor.run { traineeForAddMembershipSheet = nil }
                            AppDesign.triggerSuccessHaptic()
                        } catch {
                            if let msg = AppErrors.userMessageIfNeeded(for: error) { }
                        }
                        await MainActor.run { isCreatingMembershipFromOnboarding = false }
                    }
                },
                onCancel: { traineeForAddMembershipSheet = nil }
            )
            .presentationDetents([.medium])
        }
        .archiveToggleConfirmationDialog(
            isPresented: $showArchiveConfirmation,
            isArchived: archiveTarget?.archived == false,
            onConfirm: {
                guard let target = archiveTarget else { return }
                archiveTarget = nil
                Task {
                    await MainActor.run { isArchiving = true }
                    await setArchived(target.item, target.archived)
                    await MainActor.run { isArchiving = false }
                }
            },
            onCancel: {
                archiveTarget = nil
            }
        )
        .sheet(item: $editTraineeItem) { item in
            EditTraineeSheet(
                coachProfileId: profile.id,
                link: item.link,
                profile: item.profile,
                profileService: profileService,
                measurementService: measurementService,
                linkService: linkService,
                onSaved: { _ in
                    editTraineeItem = nil
                    Task { await loadTrainees(forceNetwork: true) }
                },
                onCancel: { editTraineeItem = nil }
            )
            .presentationDetents(AppSheetDetents.mediumOnly)
        }
        .sheet(item: $quickVisitRequest) { req in
            QuickAddVisitSheet(
                traineeName: req.item.link.displayName ?? req.item.profile.name,
                coachProfileId: profile.id,
                traineeProfileId: req.item.profile.id,
                visitService: visitService,
                membershipService: membershipService,
                initialDate: req.date,
                onAdded: {
                    quickVisitRequest = nil
                    Task { await loadTrainees(forceNetwork: true) }
                },
                onCancel: { quickVisitRequest = nil }
            )
            .presentationDetents(AppSheetDetents.mediumOnly)
        }
        .sheet(item: $quickEventRequest) { req in
            AddEditEventSheet(
                mode: .create(initialDate: Calendar.current.startOfDay(for: req.date)),
                coachProfileId: profile.id,
                traineeProfileId: req.item.profile.id,
                eventService: eventService,
                onSaved: { Task { await loadTrainees(forceNetwork: true); await MainActor.run { quickEventRequest = nil } } },
                onError: { _ in },
                onCancel: { quickEventRequest = nil }
            )
            .presentationDetents(AppSheetDetents.mediumOnly)
        }
        .overlay {
            if isDeleting {
                LoadingOverlayView(message: "Удаляю профиль")
            } else if isArchiving {
                LoadingOverlayView(message: "Обновляю…")
            }
        }
        .allowsHitTesting(!isDeleting && !isArchiving)
    }

    private var profileTab: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    profileHeader
                    blockDateOfBirth
                    blockHeight
                    blockGenderGym
                    blockContact
                    blockDelete
                }
                .padding(.bottom, AppDesign.sectionSpacing)
            }
            .background(AdaptiveScreenBackground())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
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
            .presentationDetents(AppSheetDetents.mediumOnly)
        }
        .appConfirmationDialog(
            title: "Удалить профиль?",
            message: "Профиль тренера и связь с подопечными будут удалены. Это действие нельзя отменить",
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

                AppTablerIcon("user-love-heart")
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

                if let gym = profile.gymName?.trimmingCharacters(in: .whitespacesAndNewlines), !gym.isEmpty {
                    Text(gym)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
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

    private var blockGenderGym: some View {
        VStack(spacing: 0) {
            ActionBlockRow(icon: "user-default", title: "Пол", value: profile.gender?.displayName ?? "Не указан")
            if profile.isCoach, let gym = profile.gymName, !gym.isEmpty {
                Divider()
                    .padding(.leading, 52)
                ActionBlockRow(icon: "building-apartment-two", title: "Зал", value: gym)
            }
        }
        .actionBlockStyle()
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
            deleteSubtitle: "Удаляется только этот профиль тренера и связь с подопечными. Вход в аккаунт сохранится",
            onDeleteTap: { showDeleteProfileConfirmation = true }
        ) {
            DeveloperSettingsView(profile: profile)
        }
    }

    private func loadTrainees(forceNetwork: Bool = false) async {
        if forceNetwork {
            coachOverviewService.invalidateCache(coachProfileId: profile.id)
        }
        if await MainActor.run(body: { isLoadingTrainees }) {
            await MainActor.run { isReloadQueued = true }
            return
        }
        await MainActor.run { isLoadingTrainees = true }
        defer {
            Task { @MainActor in
                isLoadingTrainees = false
            }
        }
        if AppConfig.enableOfflineMode, offlineMode.isOffline,
           let snapshot = OfflineStore.shared.loadSnapshot(),
           let links = snapshot.links {
            let coachLinks = links.filter { $0.coachProfileId == profile.id }
            if !coachLinks.isEmpty {
                let profileIds = Set(coachLinks.map(\.traineeProfileId))
                let profilesById = Dictionary(uniqueKeysWithValues: snapshot.trainees.filter { profileIds.contains($0.id) }.map { ($0.id, $0) })
                var fallbackItems: [TraineeItem] = []
                for link in coachLinks {
                    if let p = profilesById[link.traineeProfileId] {
                        fallbackItems.append(TraineeItem(link: link, profile: p, activeMembership: nil))
                    }
                }
                if !fallbackItems.isEmpty {
                    await MainActor.run { traineeItems = fallbackItems }
                    await loadCoachHomeWeekAggregates(from: nil)
                    return
                }
            }
        }

        do {
            let overview = try await coachOverviewService.fetchOverview(coachProfileId: profile.id, includeArchived: true)
            let items = overview.trainees.map {
                TraineeItem(
                    link: $0.link,
                    profile: $0.profile,
                    activeMembership: nil,
                    membershipSummaryOverride: $0.membershipSummary
                )
            }
            if items.isEmpty {
                // Backend overview can be temporarily unavailable/incomplete.
                // Fall back to legacy flow to avoid blank trainee screens.
                let legacy = try await loadTraineesLegacyFromAPI()
                await MainActor.run { traineeItems = legacy }
                if AppConfig.enableOfflineMode, !legacy.isEmpty {
                    OfflineStore.shared.updateSnapshotTraineesAndLinks(trainees: legacy.map(\.profile), links: legacy.map(\.link))
                }
                await loadCoachHomeWeekAggregates(from: nil)
            } else {
                await MainActor.run { traineeItems = items }
                if AppConfig.enableOfflineMode, !items.isEmpty {
                    OfflineStore.shared.updateSnapshotTraineesAndLinks(trainees: items.map(\.profile), links: items.map(\.link))
                }
                await loadCoachHomeWeekAggregates(from: overview.week)
            }
        } catch {
            do {
                let legacy = try await loadTraineesLegacyFromAPI()
                await MainActor.run { traineeItems = legacy }
                if AppConfig.enableOfflineMode, !legacy.isEmpty {
                    OfflineStore.shared.updateSnapshotTraineesAndLinks(trainees: legacy.map(\.profile), links: legacy.map(\.link))
                }
                await loadCoachHomeWeekAggregates(from: nil)
            } catch {
                if AppConfig.enableOfflineMode, let snapshot = OfflineStore.shared.loadSnapshot(), let links = snapshot.links {
                    let coachLinks = links.filter { $0.coachProfileId == profile.id }
                    if !coachLinks.isEmpty {
                        let profileIds = Set(coachLinks.map(\.traineeProfileId))
                        let profilesById = Dictionary(uniqueKeysWithValues: snapshot.trainees.filter { profileIds.contains($0.id) }.map { ($0.id, $0) })
                        var fallbackItems: [TraineeItem] = []
                        for link in coachLinks {
                            if let p = profilesById[link.traineeProfileId] {
                                fallbackItems.append(TraineeItem(link: link, profile: p, activeMembership: nil))
                            }
                        }
                        if !fallbackItems.isEmpty {
                            await MainActor.run { traineeItems = fallbackItems }
                            await loadCoachHomeWeekAggregates(from: nil)
                            return
                        }
                    }
                }
                await MainActor.run { traineeItems = [] }
            }
        }
        if await MainActor.run(body: { isReloadQueued }) {
            await MainActor.run { isReloadQueued = false }
            await loadTrainees(forceNetwork: forceNetwork)
        }
    }

    private func loadTraineesLegacyFromAPI() async throws -> [TraineeItem] {
        let response = try await linkService.fetchLinksWithProfiles(profileId: profile.id, as: "coach")
        let links = response.links
        let profilesById = Dictionary(uniqueKeysWithValues: response.profiles.map { ($0.id, $0) })
        var items: [TraineeItem] = []
        if profilesById.isEmpty {
            for link in links {
                async let profileTask = profileService.fetchProfile(id: link.traineeProfileId)
                async let membershipTask = membershipService.fetchActiveMembership(
                    coachProfileId: profile.id,
                    traineeProfileId: link.traineeProfileId
                )
                let (p, activeMembership) = try await (profileTask, membershipTask)
                if let p {
                    items.append(TraineeItem(link: link, profile: p, activeMembership: activeMembership))
                }
            }
        } else {
            for link in links {
                guard let p = profilesById[link.traineeProfileId] else { continue }
                async let membershipTask = membershipService.fetchActiveMembership(
                    coachProfileId: profile.id,
                    traineeProfileId: link.traineeProfileId
                )
                let activeMembership = try await membershipTask
                items.append(TraineeItem(link: link, profile: p, activeMembership: activeMembership))
            }
        }
        return items
    }

    /// Сводка за календарную неделю: клиенты с визитами «Проведено», разовые и по абонементу.
    private func loadCoachHomeWeekAggregates(from summary: CoachOverviewWeekSummary?) async {
        if let summary {
            await MainActor.run {
                weekSummaryClients = summary.clientsWithDoneVisits
                weekSummaryOneOffVisits = summary.oneOffVisits
                weekSummarySubscriptionVisits = summary.subscriptionVisits
                weekSummaryRangeCaption = summary.rangeCaption
            }
            return
        }
        let cal = Calendar.current
        guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: Date()) else {
            await MainActor.run {
                weekSummaryClients = 0
                weekSummaryOneOffVisits = 0
                weekSummarySubscriptionVisits = 0
                weekSummaryRangeCaption = ""
            }
            return
        }
        await MainActor.run {
            weekSummaryClients = 0
            weekSummaryOneOffVisits = 0
            weekSummarySubscriptionVisits = 0
            weekSummaryRangeCaption = weekInterval.formattedRuWeekRangeCaption
        }
    }

    private func setArchived(_ item: TraineeItem, _ archived: Bool) async {
        do {
            try await linkService.setArchived(coachProfileId: profile.id, traineeProfileId: item.profile.id, isArchived: archived)
            await loadTrainees(forceNetwork: true)
            await MainActor.run {
                ToastCenter.shared.success(archived ? "Подопечный перенесен в архив" : "Подопечный возвращен из архива")
            }
        } catch {
            await MainActor.run {
                ToastCenter.shared.error(from: error, fallback: "Не удалось изменить статус архива")
            }
        }
    }
}

// MARK: - Новый экран списка подопечных

private struct TraineesListScreen<
    RowContent: View,
    Empty1: View,
    Empty2: View,
    Empty3: View,
    Empty4: View
>: View {
    let activeItems: [TraineeItem]
    let archivedItems: [TraineeItem]
    @Binding var showingArchived: Bool
    @Binding var searchText: String
    var isEmptySearch: Bool
    /// Если задан — прокрутить к элементу (после раскрытия).
    @Binding var scrollToItemId: String?
    var isLoadingTrainees: Bool
    @ViewBuilder let rowContent: (TraineeItem, Bool) -> RowContent
    @ViewBuilder let activeEmptyContent: () -> Empty1
    @ViewBuilder let activeSearchEmptyContent: () -> Empty2
    @ViewBuilder let archivedEmptyContent: () -> Empty3
    @ViewBuilder let archivedSearchEmptyContent: () -> Empty4

    private var displayedItems: [TraineeItem] { showingArchived ? archivedItems : activeItems }
    private var showActiveEmpty: Bool { activeItems.isEmpty && !showingArchived }
    private var showArchivedEmpty: Bool { archivedItems.isEmpty && showingArchived }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    segmentBlock
                    listContent
                }
                .padding(.horizontal, AppDesign.cardPadding)
                .padding(.bottom, AppDesign.sectionSpacing)
            }
            .background(AdaptiveScreenBackground())
            .onChange(of: scrollToItemId) { _, newValue in
                guard let id = newValue else { return }
                Task { @MainActor in
                    // Дать лэйауту пересчитаться, чтобы не было "прыжка").
                    try? await Task.sleep(nanoseconds: 120_000_000)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                    scrollToItemId = nil
                }
            }
        }
    }

    private var segmentBlock: some View {
        Picker("", selection: $showingArchived) {
            Text("Активные").tag(false)
            Text("В архиве").tag(true)
        }
        .pickerStyle(.segmented)
        .padding(.top, 12)
        .padding(.bottom, AppDesign.blockSpacing)
    }

    @ViewBuilder
    private var listContent: some View {
        if showActiveEmpty {
            if isEmptySearch { activeSearchEmptyContent() }
            else { activeEmptyContent() }
        } else if showArchivedEmpty {
            if isEmptySearch { archivedSearchEmptyContent() }
            else { archivedEmptyContent() }
        } else {
            LazyVStack(spacing: AppDesign.blockSpacing) {
                ForEach(displayedItems) { item in
                    rowContent(item, showingArchived)
                        .id(item.id)
                }
            }
            .padding(.top, 2)
        }
    }
}

private enum TraineeSortOrder {
    case byDisplayNameAsc
    case byDisplayNameDesc
    case byDateAddedNewest
    case byDateAddedOldest
}

private struct TraineeItem: Identifiable {
    let link: CoachTraineeLink
    let profile: Profile
    var activeMembership: Membership?
    var membershipSummaryOverride: String? = nil
    var id: String { link.id }

    /// Краткая строка для списка: «Осталось N занятий» или «Абонемент до [дата]».
    var membershipSummary: String? {
        if let membershipSummaryOverride, !membershipSummaryOverride.isEmpty {
            return membershipSummaryOverride
        }
        guard let m = activeMembership, m.isActive else { return nil }
        if m.kind == .byVisits {
            return "Осталось \(m.remainingSessions) занятий"
        }
        if let end = m.effectiveEndDate {
            return "Абонемент до \(end.formattedRuDayMonth)"
        }
        return nil
    }
}

private struct TraineeCardRow: View {
    let profile: Profile
    let displayName: String?
    var membershipSummary: String? = nil
    var isArchived: Bool = false
    var isExpanded: Bool = false
    var onToggleExpand: (() -> Void)? = nil
    var onQuickVisit: (() -> Void)? = nil
    var onQuickEvent: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onArchive: (() -> Void)? = nil
    var onUnarchive: (() -> Void)? = nil

    private var title: String { displayName ?? profile.name }
    private var initial: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = t.first else { return "?" }
        return String(first).uppercased()
    }
    private var avatarColor: Color {
        AppColors.avatarColor(gender: profile.gender, defaultColor: isArchived ? .secondary : AppColors.accent)
    }

    var body: some View {
        let hasMenu = onQuickVisit != nil || onQuickEvent != nil || onEdit != nil || onArchive != nil || onUnarchive != nil

        ListActionRow(
            verticalPadding: 10,
            horizontalPadding: 12,
            cornerRadius: 16,
            isInteractive: true
        ) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(avatarColor.opacity(isArchived ? 0.14 : 0.18))
                        .frame(width: 44, height: 44)
                    Text(initial)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(avatarColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isArchived ? .secondary : .primary)
                            .lineLimit(1)
                        if isArchived {
                            AppTablerIcon("folder-default")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let summary = membershipSummary, !summary.isEmpty {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } trailing: {
            HStack(spacing: 6) {
                if let onToggleExpand, !isArchived {
                    Button(action: onToggleExpand) {
                        AppTablerIcon(isExpanded ? "chevron.up" : "chevron.down")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    AppTablerIcon("chevron-right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 22, alignment: .trailing)
                }
            }
        }
        .contextMenu {
            if hasMenu {
                if let onQuickVisit {
                    Button(action: onQuickVisit) {
                        Label("Отметить посещение сегодня", appIcon: "calendar-filled")
                    }
                }
                if let onQuickEvent {
                    Button(action: onQuickEvent) {
                        Label("Добавить событие", appIcon: "award-medal")
                    }
                }
                if let onEdit {
                    EditMenuAction(action: onEdit)
                }
                if let onUnarchive {
                    Button(action: onUnarchive) {
                        Label("Вернуть из архива", appIcon: "folder-default")
                    }
                }
                if let onArchive {
                    Button(action: onArchive) {
                        Label("В архив", appIcon: "folder-default")
                    }
                }
            }
        }
    }
}

// MARK: - Inline календарь в списке подопечных (MVP)

private struct TraineeInlineCalendar: View {
    let coachProfileId: String
    let trainee: Profile
    let visitService: VisitServiceProtocol
    let eventService: EventServiceProtocol
    let membershipService: MembershipServiceProtocol
    let onAddVisit: (Date) -> Void
    let onAddEvent: (Date) -> Void

    @State private var month: Date = Date()
    @State private var visits: [Visit] = []
    @State private var events: [Event] = []
    @State private var memberships: [Membership] = []
    @State private var isLoading = false
    @State private var dayDetailItem: DayDetailRequest?
    @State private var eventToEdit: Event?
    @State private var daySheetDetent: PresentationDetent = .medium

    private struct DayDetailRequest: Identifiable {
        let id = UUID()
        let date: Date
    }

    private var activeMemberships: [Membership] {
        memberships.filter { $0.isActive }.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VisitsCalendarView(
                selectedMonth: $month,
                visits: visits,
                events: events,
                onDayTapped: nil,
                addVisitMemberships: activeMemberships,
                onAddOneOffVisit: { date in onAddVisit(date) },
                onAddVisitWithMembership: { date, _ in onAddVisit(date) },
                onAddEvent: { date in onAddEvent(date) },
                onEditEvent: nil,
                onCancelEvent: nil,
                dayVisitActions: nil,
                onShowDayDetail: { dayDetailItem = DayDetailRequest(date: $0) },
                footerContent: nil,
                cardTitle: "Календарь",
                containerStyle: .inlineCard
            )
        }
        .task { await load() }
        .sheet(item: $dayDetailItem) { item in
            let calendar = Calendar.current
            let dayVisits = visits.filter { calendar.isDate($0.date, inSameDayAs: item.date) }
                .filter { $0.status != .cancelled }
                .sorted { $0.date < $1.date }
            let dayEvents = events.filter { calendar.isDate($0.date, inSameDayAs: item.date) }
                .filter { !$0.isCancelled }
                .sorted { $0.date < $1.date }
            DayDetailSheet(
                date: item.date,
                visits: dayVisits,
                events: dayEvents,
                payableMemberships: activeMemberships,
                onPayWithMembership: { visit, membership in
                    Task {
                        do {
                            try await visitService.markVisitPaidWithMembership(visit, membershipId: membership.id)
                            await load()
                        } catch { }
                    }
                },
                onMarkAsPaid: { visit in
                    Task {
                        do {
                            try await visitService.markVisitPaid(visit)
                            await load()
                        } catch { }
                    }
                },
                onCancelVisit: { v in
                    Task {
                        do {
                            try await visitService.cancelVisit(v)
                            await load()
                        } catch { }
                    }
                },
                onEventTap: { e in
                    dayDetailItem = nil
                    eventToEdit = e
                },
                onCancelEvent: { ev in
                    Task {
                        var updated = ev
                        updated.isCancelled = true
                        try? await eventService.updateEvent(updated)
                        await load()
                    }
                },
                onDismiss: { dayDetailItem = nil },
                onAddOneOffVisit: { date in onAddVisit(date) },
                addVisitMemberships: activeMemberships,
                onAddVisitWithMembership: { date, m in
                    Task {
                        do {
                            let startOfDay = Calendar.current.startOfDay(for: date)
                            let visit = try await visitService.createVisit(
                                coachProfileId: coachProfileId,
                                traineeProfileId: trainee.id,
                                date: startOfDay,
                                paymentStatus: nil,
                                membershipId: nil,
                                idempotencyKey: UUID().uuidString
                            )
                            try await visitService.markVisitPaidWithMembership(visit, membershipId: m.id)
                            await load()
                            await MainActor.run { AppDesign.triggerSuccessHaptic() }
                        } catch { }
                    }
                },
                onAddEvent: { date in onAddEvent(date) }
            )
            .presentationDetents(AppSheetDetents.calendar, selection: $daySheetDetent)
            .presentationDragIndicator(.visible)
            .onAppear { daySheetDetent = .medium }
        }
        .sheet(item: $eventToEdit) { e in
            AddEditEventSheet(
                mode: .edit(e),
                coachProfileId: coachProfileId,
                traineeProfileId: trainee.id,
                eventService: eventService,
                onSaved: { Task { await load(); await MainActor.run { eventToEdit = nil } } },
                onError: { _ in },
                onCancel: { eventToEdit = nil }
            )
            .presentationDetents(AppSheetDetents.mediumOnly)
        }
    }

    private func load() async {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }
        do {
            async let vTask = visitService.fetchVisits(coachProfileId: coachProfileId, traineeProfileId: trainee.id)
            async let eTask = eventService.fetchEvents(coachProfileId: coachProfileId, traineeProfileId: trainee.id)
            async let mTask = membershipService.fetchMemberships(coachProfileId: coachProfileId, traineeProfileId: trainee.id)
            let (v, e, m) = try await (vTask, eTask, mTask)
            await MainActor.run {
                visits = v
                events = e
                memberships = m
            }
        } catch {
            // В MVP просто оставляем пусто — офлайн может подставить визиты через OfflineVisitService.
        }
    }
}

#Preview {
    let client = APIClient(baseURL: ApiConfig.baseURL, getIDToken: { _ in nil })
    CoachMainView(
        profile: Profile(id: "1", userId: "u1", type: .coach, name: "Зал Арбат", gymName: "Фитнес Арбат"),
        onSwitchProfile: {},
        onDeleteProfile: { },
        onProfileUpdated: { _ in },
        linkService: MockCoachTraineeLinkService(),
        profileService: MockProfileService(),
        measurementService: MockMeasurementService(),
        goalService: MockGoalService(),
        personalRecordService: MockPersonalRecordService(),
        connectionTokenService: MockConnectionTokenService(),
        membershipService: MockMembershipService(),
        visitService: MockVisitService(),
        eventService: MockEventService(),
        managedTraineeMergeService: MockManagedTraineeMergeService(),
        coachStatisticsService: MockCoachStatisticsService(),
        coachOverviewService: APICoachOverviewService(client: client),
        calendarSummaryService: MockCalendarSummaryService(),
        nutritionService: MockNutritionService(),
        calculatorsService: APICalculatorsService(client: client),
        myTraineeProfiles: []
    )
}
