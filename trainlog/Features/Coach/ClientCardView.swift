//
//  ClientCardView.swift
//  TrainLog
//

import SwiftUI
import UIKit

struct ClientCardView: View {
    @EnvironmentObject private var offlineMode: OfflineMode
    let trainee: Profile
    var isArchived: Bool = false
    /// Связь тренер–подопечный (для редактирования и быстрых действий). Если nil — кнопка «Редактировать» не показывается.
    var link: CoachTraineeLink? = nil
    let profileService: ProfileServiceProtocol
    let measurementService: MeasurementServiceProtocol
    let goalService: GoalServiceProtocol
    let personalRecordService: PersonalRecordServiceProtocol
    let membershipService: MembershipServiceProtocol
    let visitService: VisitServiceProtocol
    let eventService: EventServiceProtocol
    let nutritionService: NutritionServiceProtocol
    /// Опционально: для одного запроса card-summary и смены месяца через calendar.
    var calendarSummaryService: CalendarSummaryServiceProtocol? = nil
    let connectionTokenService: ConnectionTokenServiceProtocol
    let managedTraineeMergeService: ManagedTraineeMergeServiceProtocol
    /// Тренер: для отображения кнопки «Отвязать». Если nil — кнопка не показывается.
    var coachProfileId: String? = nil
    var linkService: CoachTraineeLinkServiceProtocol? = nil
    var onUnlink: (() -> Void)? = nil
    var onArchiveChanged: (() async -> Void)? = nil
    /// Вызывается после сохранения редактирования подопечного (чтобы обновить список).
    var onTraineeEdited: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var measurements: [Measurement] = []
    @State private var goals: [Goal] = []
    @State private var isLoading = true
    @State private var activeMembership: Membership?
    @State private var visits: [Visit] = []
    @State private var events: [Event] = []
    @State private var memberships: [Membership] = []
    @State private var isUnlinking = false
    @State private var isArchiving = false
    @State private var isSavingVisit = false
    @State private var showMergeSheet = false
    @State private var errorMessage: String?
    @State private var showEditTrainee = false
    @State private var nutritionPlan: NutritionPlan?
    /// Профиль для отображения: обновляется после сохранения в EditTraineeSheet, чтобы заметки и др. сразу отображались.
    @State private var displayedTrainee: Profile?
    @State private var selectedMonthForVisits = Date()
    @State private var didAppearOnce = false

    private var traineeForDisplay: Profile { displayedTrainee ?? trainee }

    /// В заголовке: имя для списка, если задано, иначе имя профиля.
    private var headerDisplayName: String {
        let listName = link?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let listName, !listName.isEmpty { return listName }
        return traineeForDisplay.name
    }

    private var mainContent: some View {
        Group {
            if isLoading {
                ClientCardSkeletonView()
            } else {
                cardList
            }
        }
    }

    private var cardList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if let coachId = coachProfileId {
                    // MARK: 1. Действия тренера (приоритет)
                    ContentCard(
                        title: "Действия тренера",
                        description: "Абонементы, питание и посещения"
                    ) {
                        ClientCardVisitsBlock(
                            selectedMonth: $selectedMonthForVisits,
                            visits: visits,
                            events: events,
                            trainee: traineeForDisplay,
                            coachProfileId: coachId,
                            visitService: visitService,
                            eventService: eventService,
                            membershipService: membershipService,
                            initialMemberships: memberships,
                            onVisitsChanged: { await loadData() }
                        )

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)
                            ],
                            spacing: 10
                        ) {
                            NavigationLink {
                                ClientMembershipsNewView(
                                    trainee: traineeForDisplay,
                                    coachProfileId: coachId,
                                    membershipService: membershipService,
                                    visitService: visitService,
                                    eventService: eventService,
                                    initialMemberships: memberships
                                )
                            } label: {
                                let hasActive = activeMembership != nil
                                BigActionButtonToTwoColumn(
                                    icon: "tag",
                                    title: "Абонементы",
                                    subtitle: hasActive ? "Есть активный" : "Нет активных"
                                )
                            }
                            .buttonStyle(PressableButtonStyle(cornerRadius: 12))

                            NavigationLink {
                                CoachNutritionPlanView(
                                    coachProfileId: coachId,
                                    trainee: traineeForDisplay,
                                    nutritionService: nutritionService,
                                    profileService: profileService,
                                    measurementService: measurementService
                                )
                            } label: {
                                BigActionButtonToTwoColumn(
                                    icon: "tools-kitchen-2",
                                    title: "Питание и добавки",
                                    subtitle: nutritionPlan == nil ? "Не задано" : "Есть план"
                                )
                            }
                            .buttonStyle(PressableButtonStyle(cornerRadius: 12))
                        }
                        .padding(.top, 10)

                        // Дополнительные пункты «Действия тренера»: добавлять сюда.
                    }

                    // MARK: 2. О клиенте
                    ContentCard(
                        title: "О клиенте",
                        description: "Профиль, контакты и управление связью",
                        trailing: (link != nil && linkService != nil)
                        ? .action(icon: "pencil", action: { showEditTrainee = true })
                        : nil
                    ) {
                        VStack(spacing: AppDesign.blockSpacing) {
                            VStack(spacing: 0) {
                                CardRow(
                                    icon: "user-default",
                                    title: "Пол",
                                    value: traineeForDisplay.gender?.displayName ?? "Не указан",
                                    showsDisclosure: false
                                )
                                if traineeForDisplay.dateOfBirth != nil {
                                    Divider()
                                    CardRow(
                                        icon: "calendar-default",
                                        title: "Дата рождения",
                                        value: traineeForDisplay.dateOfBirth?.formattedRuShort,
                                        showsDisclosure: false
                                    )
                                }
                                if let age = traineeForDisplay.ageFormatted, !age.isEmpty {
                                    Divider()
                                    CardRow(
                                        icon: "clock-01",
                                        title: "Возраст",
                                        value: age,
                                        showsDisclosure: false
                                    )
                                }
                                if let h = traineeForDisplay.height {
                                    Divider()
                                    CardRow(
                                        icon: "pencil-scale",
                                        title: "Рост",
                                        value: "\(h.measurementFormatted) см",
                                        showsDisclosure: false
                                    )
                                }
                                if let w = traineeForDisplay.weight {
                                    Divider()
                                    CardRow(
                                        icon: "pencil-scale",
                                        title: "Вес",
                                        value: "\(w.measurementFormatted) кг",
                                        showsDisclosure: false
                                    )
                                }
                            }

                            if traineeForDisplay.phoneNumber != nil || traineeForDisplay.telegramUsername != nil {
                                VStack(spacing: 0) {
                                    if let phone = traineeForDisplay.phoneNumber, !phone.isEmpty {
                                        ClientCardContactRow(
                                            icon: "phone",
                                            title: "Телефон",
                                            value: PhoneFormatter.displayString(phone),
                                            url: URL(string: "tel:" + phone.filter { $0.isNumber })
                                        )
                                        if traineeForDisplay.telegramUsername != nil, !(traineeForDisplay.telegramUsername?.isEmpty ?? true) {
                                            Divider()
                                                .padding(.leading, 40)
                                        }
                                    }
                                    if let tg = traineeForDisplay.telegramUsername, !tg.isEmpty {
                                        ClientCardContactRow(
                                            icon: "send-plane-horizontal",
                                            title: "Telegram",
                                            value: "@" + tg,
                                            url: URL(string: "https://t.me/\(tg.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? tg)")
                                        )
                                    }
                                }
                                .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
                            }

                            if linkService != nil {
                                NavigationLink {
                                    TraineeManagementView(
                                        trainee: traineeForDisplay,
                                        isArchived: isArchived,
                                        isArchiving: isArchiving,
                                        isUnlinking: isUnlinking,
                                        onMergeTapped: { showMergeSheet = true },
                                        onArchiveTapped: { targetArchived in
                                            Task { await performSetArchived(targetArchived) }
                                        },
                                        onUnlinkConfirmed: { Task { await performUnlink() } }
                                    )
                                } label: {
                                    WideActionButtonToOneColumn(
                                        icon: "settings-01",
                                        title: "Управлять",
                                        subtitle: "Архив, отвязка и объединение по коду",
                                        showChevron: true,
                                        iconColor: AppColors.profileAccent
                                    )
                                }
                                .buttonStyle(PressableButtonStyle())
                            }

                            if let notes = traineeForDisplay.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                                VStack(spacing: 0) {
                                    HStack(spacing: 12) {
                                        AppTablerIcon("file-default")
                                            .foregroundStyle(.secondary)
                                            .frame(width: 28, alignment: .center)
                                        Text(notes)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.leading)
                                            .lineLimit(nil)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal, AppDesign.cardPadding)
                                    .padding(.vertical, 12)
                                }
                                .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
                            }
                        }
                    }

                    // MARK: 3. Просмотр
                    ContentCard(
                        title: "Просмотр",
                        description: "Динамические данные подопечного"
                    ) {
                        NavigationLink {
                            MeasurementsAndChartsScreen(
                                profile: traineeForDisplay,
                                measurements: measurements,
                                goals: goals
                            )
                        } label: {
                            WideActionButtonToOneColumn(
                                icon: "world",
                                title: "Замеры и графики",
                                subtitle: "Сводка, история замеров и динамика метрик",
                                showChevron: true,
                                iconColor: AppColors.profileAccent
                            )
                        }
                        .buttonStyle(PressableButtonStyle())

                        NavigationLink {
                            PersonalRecordsView(
                                profile: traineeForDisplay,
                                service: personalRecordService,
                                readOnly: true
                            )
                        } label: {
                            WideActionButtonToOneColumn(
                                icon: "award-medal",
                                title: "Мои достижения",
                                subtitle: "Личные достижения подопечного",
                                showChevron: true,
                                iconColor: AppColors.accent
                            )
                        }
                        .buttonStyle(PressableButtonStyle())

                        // Дополнительные read-only пункты: добавлять сюда NavigationLink.
                    }
                } else {
                    clientCardLegacyNoCoachLayout
                }
            }
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .background(AdaptiveScreenBackground())
    }

    /// Редкий случай без `coachProfileId`: только профиль и замеры без секций тренера.
    private var clientCardLegacyNoCoachLayout: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                CardRow(
                    icon: "user-default",
                    title: "Пол",
                    value: traineeForDisplay.gender?.displayName ?? "Не указан",
                    showsDisclosure: false
                )
                if traineeForDisplay.dateOfBirth != nil {
                    Divider()
                        .padding(.leading, 40)
                    CardRow(
                        icon: "calendar-default",
                        title: "Дата рождения",
                        value: traineeForDisplay.dateOfBirth?.formattedRuShort,
                        showsDisclosure: false
                    )
                }
                if let age = traineeForDisplay.ageFormatted, !age.isEmpty {
                    Divider()
                        .padding(.leading, 40)
                    CardRow(
                        icon: "clock-01",
                        title: "Возраст",
                        value: age,
                        showsDisclosure: false
                    )
                }
            }
            .actionBlockStyle()

            NavigationLink {
                MeasurementsAndChartsScreen(
                    profile: traineeForDisplay,
                    measurements: measurements,
                    goals: goals
                )
            } label: {
                WideActionButtonToOneColumn(
                    icon: "world",
                    title: "Замеры и графики",
                    subtitle: "Сводка, история замеров и динамика метрик",
                    iconColor: AppColors.profileAccent,
                    chevronColor: AppColors.tertiaryLabel
                )
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.horizontal, AppDesign.cardPadding)
            .padding(.top, AppDesign.blockSpacing)

            NavigationLink {
                PersonalRecordsView(
                    profile: traineeForDisplay,
                    service: personalRecordService,
                    readOnly: true
                )
            } label: {
                WideActionButtonToOneColumn(
                    icon: "award-medal",
                    title: "Мои достижения",
                    subtitle: "Достижения подопечного",
                    prominentTitle: true,
                    iconColor: AppColors.accent,
                    chevronColor: AppColors.tertiaryLabel
                )
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.horizontal, AppDesign.cardPadding)
            .padding(.top, AppDesign.blockSpacing)
        }
    }

    var body: some View {
        mainContent
        .trackAPIScreen("Карточка подопечного")
        .navigationTitle(headerDisplayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackToolbarButton(action: { dismiss() })
            }
        }
        .task {
            await loadData()
        }
        .onAppear {
            // При возвращении с дочерних экранов (например, абонементов) обновляем блоки.
            if didAppearOnce {
                Task { await loadData() }
            } else {
                didAppearOnce = true
            }
        }
        .refreshable {
            await loadData()
        }
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
        .sheet(isPresented: $showMergeSheet) {
            MergeManagedTraineeSheet(
                coachProfileId: coachProfileId ?? "",
                managedTrainee: traineeForDisplay,
                tokenService: connectionTokenService,
                mergeService: managedTraineeMergeService,
                onMerged: {
                    showMergeSheet = false
                    dismiss()
                    onUnlink?()
                },
                onCancel: { showMergeSheet = false }
            )
            .mainSheetPresentation(.half)
        }
        .sheet(isPresented: $showEditTrainee) {
            if let link = link, let coachId = coachProfileId, let linkService = linkService {
                EditTraineeSheet(
                    coachProfileId: coachId,
                    link: link,
                    profile: traineeForDisplay,
                    profileService: profileService,
                    measurementService: measurementService,
                    linkService: linkService,
                    onSaved: { updated in
                        displayedTrainee = updated
                        showEditTrainee = false
                        onTraineeEdited?()
                    },
                    onCancel: { showEditTrainee = false }
                )
                .mainSheetPresentation(.half)
            }
        }
        .onChange(of: trainee.id) { _, _ in
            displayedTrainee = nil
        }
        .onChange(of: selectedMonthForVisits) { _, _ in
            guard let coachId = coachProfileId, let calSvc = calendarSummaryService else { return }
            Task { await loadCalendarOnly(coachProfileId: coachId) }
        }
        .overlay {
            if isArchiving {
                AppColors.overlayDim
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(AppColors.white)
                                .scaleEffect(1.1)
                            Text("Обновляю…")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.white)
                        }
                    }
            }
        }
        .allowsHitTesting(!isArchiving)
    }

    private func performUnlink() async {
        guard let coachId = coachProfileId, let svc = linkService else { return }
        isUnlinking = true
        defer { isUnlinking = false }
        do {
            try await svc.removeLink(coachProfileId: coachId, traineeProfileId: trainee.id)
            await MainActor.run {
                ToastCenter.shared.success("Подопечный отвязан")
                dismiss()
                onUnlink?()
            }
        } catch {
            await MainActor.run {
                ToastCenter.shared.error(from: error, fallback: "Не удалось отвязать подопечного")
                if let msg = AppErrors.userMessageIfNeeded(for: error) { errorMessage = msg }
            }
        }
    }

    private func performSetArchived(_ archived: Bool) async {
        guard let coachId = coachProfileId, let svc = linkService else { return }
        isArchiving = true
        defer { isArchiving = false }
        do {
            try await svc.setArchived(coachProfileId: coachId, traineeProfileId: trainee.id, isArchived: archived)
            if let onArchiveChanged {
                await onArchiveChanged()
            }
            await MainActor.run {
                ToastCenter.shared.success(archived ? "Подопечный перенесен в архив" : "Подопечный возвращен из архива")
                dismiss()
            }
        } catch {
            await MainActor.run {
                ToastCenter.shared.error(from: error, fallback: "Не удалось изменить статус архива")
                if let msg = AppErrors.userMessageIfNeeded(for: error) { errorMessage = msg }
            }
        }
    }

    private func loadData() async {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }
        let coachId = coachProfileId
        func isOfflineError(_ error: Error) -> Bool {
            let ns = error as NSError
            guard ns.domain == NSURLErrorDomain else { return false }
            return ns.code == NSURLErrorNotConnectedToInternet || ns.code == NSURLErrorNetworkConnectionLost
        }

        if let coachId {
            // В ручном офлайне не делаем сетевые запросы: показываем то, что можем из кэша.
            if AppConfig.enableOfflineMode, offlineMode.isOffline {
                let cachedVisits = (try? await visitService.fetchVisits(coachProfileId: coachId, traineeProfileId: trainee.id)) ?? []
                await MainActor.run {
                    measurements = []
                    goals = []
                    nutritionPlan = nil
                    activeMembership = nil
                    visits = cachedVisits
                    events = []
                    memberships = []
                    errorMessage = nil
                }
                return
            }

            let cal = Calendar.current
            let monthInterval = cal.dateInterval(of: .month, for: selectedMonthForVisits)
            let calendarFrom = monthInterval?.start
            let calendarTo = monthInterval?.end

            var meas: [Measurement] = []
            var gols: [Goal] = []
            var active: Membership?
            var list: [Visit] = []
            var evts: [Event] = []
            var allMemberships: [Membership] = []
            var offlineHit = false
            var firstNonOfflineError: Error?
            var cardSummaryProfile: Profile?
            var loadedNutritionPlan: NutritionPlan?

            if let calSvc = calendarSummaryService, let from = calendarFrom, let to = calendarTo {
                do {
                    let summary = try await calSvc.fetchCardSummary(coachProfileId: coachId, traineeProfileId: trainee.id, calendarFrom: from, calendarTo: to)
                    cardSummaryProfile = summary.profile
                    list = summary.visits
                    evts = summary.events
                    allMemberships = summary.memberships
                } catch {
                    if isOfflineError(error) { offlineHit = true } else { firstNonOfflineError = error }
                    // Fallback: отдельные запросы ниже
                }
            }

            if cardSummaryProfile == nil {
                do { active = try await membershipService.fetchActiveMembership(coachProfileId: coachId, traineeProfileId: trainee.id) }
                catch { if isOfflineError(error) { offlineHit = true } else { firstNonOfflineError = error } }
                if list.isEmpty && evts.isEmpty {
                    do { list = try await visitService.fetchVisits(coachProfileId: coachId, traineeProfileId: trainee.id) }
                    catch { if isOfflineError(error) { offlineHit = true } else { firstNonOfflineError = error } }
                    do { evts = try await eventService.fetchEvents(coachProfileId: coachId, traineeProfileId: trainee.id) }
                    catch { if isOfflineError(error) { offlineHit = true } else { firstNonOfflineError = error } }
                }
                if allMemberships.isEmpty {
                    do { allMemberships = try await membershipService.fetchMemberships(coachProfileId: coachId, traineeProfileId: trainee.id) }
                    catch { if isOfflineError(error) { offlineHit = true } else { firstNonOfflineError = error } }
                }
            }

            do { meas = try await measurementService.fetchMeasurements(profileId: trainee.id) }
            catch { if isOfflineError(error) { offlineHit = true } else { firstNonOfflineError = error } }
            do { gols = try await goalService.fetchGoals(profileId: trainee.id) }
            catch { if isOfflineError(error) { offlineHit = true } else { firstNonOfflineError = error } }
            do { loadedNutritionPlan = try await nutritionService.fetchNutritionPlan(coachProfileId: coachId, traineeProfileId: trainee.id) }
            catch { if isOfflineError(error) { offlineHit = true } else { firstNonOfflineError = error } }

            await MainActor.run {
                if let p = cardSummaryProfile { displayedTrainee = p }
                measurements = meas
                goals = gols
                nutritionPlan = loadedNutritionPlan
                let activeFromList = allMemberships
                    .filter { $0.isActive }
                    .sorted { lhs, rhs in
                        if lhs.kind != rhs.kind { return lhs.kind == .byVisits }
                        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
                        return lhs.id < rhs.id
                    }
                    .first
                activeMembership = active ?? activeFromList
                visits = list
                events = evts
                memberships = allMemberships.sorted { $0.createdAt > $1.createdAt }
                if let err = firstNonOfflineError, let msg = AppErrors.userMessageIfNeeded(for: err) {
                    errorMessage = msg
                } else if offlineHit {
                    errorMessage = nil
                }
            }
            if AppConfig.enableOfflineMode, !list.isEmpty {
                OfflineStore.shared.mergeVisitsForTrainee(trainee.id, visits: list)
            }
        } else {
            do {
                async let measTask = measurementService.fetchMeasurements(profileId: trainee.id)
                async let goalsTask = goalService.fetchGoals(profileId: trainee.id)
                let (meas, gols) = try await (measTask, goalsTask)
                await MainActor.run {
                    measurements = meas
                    goals = gols
                    nutritionPlan = nil
                    activeMembership = nil
                    visits = []
                    memberships = []
                    errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    if let msg = AppErrors.userMessageIfNeeded(for: error) {
                        measurements = []
                        goals = []
                        nutritionPlan = nil
                        activeMembership = nil
                        visits = []
                        memberships = []
                        errorMessage = msg
                    }
                }
            }
        }
    }

    /// Обновляет только визиты и события при смене месяца (один запрос calendar). В офлайне — из кэша по месяцу.
    private func loadCalendarOnly(coachProfileId: String) async {
        if AppConfig.enableOfflineMode, offlineMode.isOffline {
            let allCached = (try? await visitService.fetchVisits(coachProfileId: coachProfileId, traineeProfileId: trainee.id)) ?? []
            let cal = Calendar.current
            guard let interval = cal.dateInterval(of: .month, for: selectedMonthForVisits) else { return }
            let inMonth = allCached.filter { $0.date >= interval.start && $0.date < interval.end }.sorted { $0.date > $1.date }
            await MainActor.run {
                visits = inMonth
                events = []
            }
            return
        }
        guard let calSvc = calendarSummaryService else { return }
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: selectedMonthForVisits) else { return }
        do {
            let feed = try await calSvc.fetchCalendar(coachProfileId: coachProfileId, traineeProfileId: trainee.id, from: interval.start, to: interval.end)
            await MainActor.run {
                visits = feed.visits
                events = feed.events
            }
            if AppConfig.enableOfflineMode, !feed.visits.isEmpty {
                let existing = OfflineStore.shared.loadSnapshot()?.visitsByTrainee[trainee.id] ?? []
                let existingIds = Set(existing.map(\.id))
                let merged = (existing + feed.visits.filter { !existingIds.contains($0.id) }).sorted { $0.date > $1.date }
                OfflineStore.shared.mergeVisitsForTrainee(trainee.id, visits: merged)
            }
        } catch { }
    }
}

// MARK: - Экран «Управление» (архив, отвязка, объединение по коду). По дизайн-коду как блок «Управление профилем».

private struct TraineeManagementView: View {
    @Environment(\.dismiss) private var dismiss
    let trainee: Profile
    let isArchived: Bool
    let isArchiving: Bool
    let isUnlinking: Bool
    let onMergeTapped: () -> Void
    let onArchiveTapped: (_ targetArchived: Bool) -> Void
    /// После подтверждения в диалоге (запуск отвязки на стороне карточки).
    let onUnlinkConfirmed: () -> Void
    @State private var showArchiveConfirmation = false
    @State private var showUnlinkConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if trainee.isManaged && trainee.mergedIntoProfileId == nil {
                    SingleContentCard(
                        title: "Объединение",
                        description: "Если клиент установил приложение и вошёл в свой профиль — введите его код. Данные с этой карточки переедут в его аккаунт"
                    ) {
                        Button(action: onMergeTapped) {
                            managementRowContent(
                                icon: "arrow.triangle.2.circlepath",
                                title: "Объединить по коду",
                                subtitle: "",
                                destructive: false
                            )
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }

                SingleContentCard(
                    title: "Архив",
                    description: isArchived
                    ? "Снова показывать в основном списке подопечных"
                    : "Скрыть из основного списка. Клиент останется в разделе «В архиве» — его можно вернуть в любой момент"
                ) {
                    Button {
                        showArchiveConfirmation = true
                    } label: {
                        managementRowContent(
                            icon: isArchived ? "archivebox.fill" : "archivebox",
                            title: isArchived ? "Вернуть из архива" : "В архив",
                            subtitle: "",
                            destructive: false
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(isArchiving)
                }

                if !trainee.isManaged {
                    SingleContentCard(
                        title: "Связь",
                        description: "Исчезнет из списка. Его данные не удаляются"
                    ) {
                        Button { showUnlinkConfirmation = true } label: {
                            managementRowContent(
                                icon: "minus-square",
                                title: "Отвязать подопечного",
                                subtitle: "",
                                destructive: true
                            )
                        }
                        .buttonStyle(PressableButtonStyle())
                        .disabled(isUnlinking)
                    }
                }
            }
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .background(AdaptiveScreenBackground())
        .navigationTitle("Связь с подопечным")
        .navigationBarTitleDisplayMode(.inline)
        .archiveToggleConfirmationDialog(
            isPresented: $showArchiveConfirmation,
            isArchived: isArchived,
            onConfirm: {
                onArchiveTapped(!isArchived)
                // Закрываем экран управления сразу после подтверждения действия.
                dismiss()
            }
        )
        .appConfirmationDialog(
            title: "Отвязать подопечного?",
            message: "Подопечный исчезнет из вашего списка. Его данные не удаляются.",
            isPresented: $showUnlinkConfirmation,
            confirmTitle: "Отвязать",
            confirmRole: .destructive,
            onConfirm: { onUnlinkConfirmed() },
            onCancel: {}
        )
    }

    /// Строка по дизайн-коду: иконка 28pt, заголовок + подпись, шеврон справа. Как в блоке «Управление профилем».
    private func managementRowContent(icon: String, title: String, subtitle: String, destructive: Bool) -> some View {
        WideActionButtonToOneColumn(
            icon: icon,
            title: title,
            subtitle: subtitle,
            showChevron: true,
            iconColor: destructive ? .red : AppColors.secondaryLabel,
            titleColor: destructive ? .red : AppColors.label
        )
    }
}

private struct MergeManagedTraineeSheet: View {
    let coachProfileId: String
    let managedTrainee: Profile
    let tokenService: ConnectionTokenServiceProtocol
    let mergeService: ManagedTraineeMergeServiceProtocol
    let onMerged: () -> Void
    let onCancel: () -> Void

    @State private var codeInput = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var realTraineeProfileIdToConfirm: String?
    @State private var pendingToken: String?

    var body: some View {
        MainSheet(
            title: "Объединить",
            onBack: onCancel,
            trailing: {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.9)
                } else {
                    Button("Подтвердить") {
                        Task { await submitCode(codeInput.trimmingCharacters(in: .whitespacesAndNewlines)) }
                    }
                    .fontWeight(.regular)
                    .disabled(codeInput.trimmingCharacters(in: .whitespacesAndNewlines).count < 4)
                }
            },
            content: {
                ScrollView {
                    VStack(spacing: 0) {
                        SettingsCard(title: "Ввести код") {
                            TextField("Код из приложения клиента", text: $codeInput)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .textFieldStyle(.plain)
                                .formInputStyle()

                            Button {
                                if let s = UIPasteboard.general.string {
                                    codeInput = s.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    AppTablerIcon("copy-default")
                                    Text("Вставить из буфера")
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)

                            if let msg = errorMessage, !msg.isEmpty {
                                Text(msg)
                                    .font(.footnote)
                                    .foregroundStyle(AppColors.destructive)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(.bottom, AppDesign.sectionSpacing)
                }
                .background(AdaptiveScreenBackground())
                .appConfirmationDialog(
                    title: "Объединить профили?",
                    message: "Перенести все данные из «\(managedTrainee.name)» в реальный профиль клиента?",
                    isPresented: Binding(
                        get: { realTraineeProfileIdToConfirm != nil },
                        set: { if !$0 { realTraineeProfileIdToConfirm = nil } }
                    ),
                    confirmTitle: "Объединить",
                    onConfirm: {
                        if let realId = realTraineeProfileIdToConfirm, let token = pendingToken {
                            Task { await confirmMerge(realTraineeProfileId: realId, token: token) }
                        }
                        realTraineeProfileIdToConfirm = nil
                    },
                    onCancel: { realTraineeProfileIdToConfirm = nil; pendingToken = nil }
                )
            }
        )
    }

    private func submitCode(_ code: String) async {
        guard !code.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            guard let token = try await tokenService.getToken(token: code.uppercased()) else {
                await MainActor.run { errorMessage = "Код не найден или истёк" }
                return
            }
            guard token.isValid else {
                await MainActor.run { errorMessage = "Код уже использован или истёк" }
                return
            }
            // С текущими safe-rules тренер не имеет доступа читать чужие profiles/{id}.
            // Для объединения достаточно traineeProfileId из токена.
            await MainActor.run {
                realTraineeProfileIdToConfirm = token.traineeProfileId
                pendingToken = code.uppercased()
            }
        } catch {
            if let msg = AppErrors.userMessageIfNeeded(for: error) { await MainActor.run { errorMessage = msg } }
        }
    }

    private func confirmMerge(realTraineeProfileId: String, token: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false; pendingToken = nil }
        do {
            try await mergeService.mergeManagedTrainee(
                coachProfileId: coachProfileId,
                managedTraineeProfileId: managedTrainee.id,
                realTraineeProfileId: realTraineeProfileId
            )
            try await tokenService.markTokenUsed(token: token)
            await MainActor.run {
                AppDesign.triggerSuccessHaptic()
                onMerged()
            }
        } catch {
            if let msg = AppErrors.userMessageIfNeeded(for: error) { await MainActor.run { errorMessage = msg } }
        }
    }
}

// MARK: - Строка в карточке клиента и вспомогательные элементы

/// Обёртка даты для шита «За день» в карточке подопечного.
private struct ClientCardDaySheetItem: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}

/// Блок посещений в карточке: календарь (с добавлением/отменой посещений) + кнопка «Показать подробнее».
private struct ClientCardVisitsBlock: View {
    @Binding var selectedMonth: Date
    let visits: [Visit]
    let events: [Event]
    let trainee: Profile
    let coachProfileId: String
    let visitService: VisitServiceProtocol
    let eventService: EventServiceProtocol
    let membershipService: MembershipServiceProtocol
    let initialMemberships: [Membership]
    var onVisitsChanged: () async -> Void

    @State private var pendingOneOffDate: Date?
    @State private var pendingEventDate: Date?
    @State private var eventToEdit: Event?
    @State private var visitToCancel: Visit?
    @State private var showCancelConfirmation = false
    @State private var isCancelling = false
    @State private var isSavingVisit = false
    @State private var visitsErrorMessage: String?
    @State private var dayDetailItem: ClientCardDaySheetItem?

    private let calendar = Calendar.current
    private var activeMemberships: [Membership] {
        initialMemberships.filter { $0.isActive }
    }

    private func onCancelDayTap(date: Date) {
        let sameDay = visits
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .filter { $0.status != .cancelled }
            .sorted { $0.date > $1.date }
        if let v = sameDay.first {
            visitToCancel = v
            showCancelConfirmation = true
        }
    }

    private func cancelVisitAfterConfirmation(_ v: Visit) {
        Task {
            await MainActor.run { isCancelling = true }
            do {
                try await visitService.cancelVisit(v)
                invalidateMembershipCache()
                await onVisitsChanged()
            } catch {
                if let msg = AppErrors.userMessageIfNeeded(for: error) { await MainActor.run { visitsErrorMessage = msg } }
            }
            await MainActor.run { isCancelling = false }
        }
    }

    private func invalidateMembershipCache() {
        membershipService.invalidateMembershipsCache(
            coachProfileId: coachProfileId,
            traineeProfileId: trainee.id
        )
    }

    private var detailLinkFooter: AnyView {
        AnyView(
            NavigationLink {
                ClientVisitsManageView(
                    trainee: trainee,
                    coachProfileId: coachProfileId,
                    visitService: visitService,
                    eventService: eventService,
                    membershipService: membershipService,
                    initialVisits: visits,
                    initialMemberships: initialMemberships
                )
            } label: {
                WideActionButtonToOneColumn(
                    icon: "map",
                    title: "Показать подробнее",
                    showChevron: true,
                    iconColor: AppColors.secondaryLabel,
                    chevronColor: AppColors.tertiaryLabel
                )
            }
            .buttonStyle(PressableButtonStyle(cornerRadius: 12))
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VisitsCalendarView(
                selectedMonth: $selectedMonth,
                visits: visits,
                events: events,
                onDayTapped: onCancelDayTap,
                addVisitMemberships: activeMemberships,
                onAddOneOffVisit: { date in pendingOneOffDate = date },
                onAddVisitWithMembership: { date, m in
                    Task {
                        await MainActor.run { isSavingVisit = true }
                        do {
                            let startOfDay = Calendar.current.startOfDay(for: date)
                            let visit = try await visitService.createVisit(coachProfileId: coachProfileId, traineeProfileId: trainee.id, date: startOfDay, paymentStatus: nil, membershipId: nil, idempotencyKey: UUID().uuidString)
                            try await visitService.markVisitPaidWithMembership(visit, membershipId: m.id)
                            invalidateMembershipCache()
                            await onVisitsChanged()
                            await MainActor.run {
                                AppDesign.triggerSuccessHaptic()
                                isSavingVisit = false
                            }
                        } catch {
                            await MainActor.run { isSavingVisit = false }
                            if let msg = AppErrors.userMessageIfNeeded(for: error) { await MainActor.run { visitsErrorMessage = msg } }
                        }
                    }
                },
                onAddEvent: { date in pendingEventDate = date },
                onEditEvent: { e in
                    dayDetailItem = nil
                    eventToEdit = e
                },
                onCancelEvent: { ev in
                    Task {
                        var updated = ev
                        updated.isCancelled = true
                        try? await eventService.updateEvent(updated)
                        await onVisitsChanged()
                    }
                },
                dayVisitActions: (
                    payableMemberships: activeMemberships,
                    onMarkAsPaid: { visit in
                        Task {
                            do {
                                try await visitService.markVisitPaid(visit)
                                invalidateMembershipCache()
                                await onVisitsChanged()
                            } catch {
                                if let msg = AppErrors.userMessageIfNeeded(for: error) { await MainActor.run { visitsErrorMessage = msg } }
                            }
                        }
                    },
                    onPayWithMembership: { visit, membership in
                        Task {
                            do {
                                try await visitService.markVisitPaidWithMembership(visit, membershipId: membership.id)
                                invalidateMembershipCache()
                                await onVisitsChanged()
                            } catch {
                                if let msg = AppErrors.userMessageIfNeeded(for: error) { await MainActor.run { visitsErrorMessage = msg } }
                            }
                        }
                    },
                    onCancelVisit: { v in
                        visitToCancel = v
                        showCancelConfirmation = true
                    }
                ),
                onShowDayDetail: { dayDetailItem = ClientCardDaySheetItem(date: $0) },
                footerContent: detailLinkFooter,
                cardTitle: "",
                containerStyle: .embedded
            )
        }
        .padding(.top, 0)
        .sheet(item: $dayDetailItem) { item in
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
                            invalidateMembershipCache()
                            await onVisitsChanged()
                        } catch {
                            if let msg = AppErrors.userMessageIfNeeded(for: error) { await MainActor.run { visitsErrorMessage = msg } }
                        }
                    }
                },
                onMarkAsPaid: { visit in
                    Task {
                        do {
                            try await visitService.markVisitPaid(visit)
                            invalidateMembershipCache()
                            await onVisitsChanged()
                        } catch {
                            await MainActor.run { isSavingVisit = false }
                            if let msg = AppErrors.userMessageIfNeeded(for: error) { await MainActor.run { visitsErrorMessage = msg } }
                        }
                    }
                },
                onCancelVisit: { v in
                    cancelVisitAfterConfirmation(v)
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
                        await onVisitsChanged()
                    }
                },
                onDismiss: { dayDetailItem = nil },
                onAddOneOffVisit: { date in
                    dayDetailItem = nil
                    pendingOneOffDate = date
                },
                addVisitMemberships: activeMemberships,
                onAddVisitWithMembership: { date, m in
                    dayDetailItem = nil
                    Task {
                        await MainActor.run { isSavingVisit = true }
                        do {
                            let startOfDay = Calendar.current.startOfDay(for: date)
                            let visit = try await visitService.createVisit(coachProfileId: coachProfileId, traineeProfileId: trainee.id, date: startOfDay, paymentStatus: nil, membershipId: nil, idempotencyKey: UUID().uuidString)
                            try await visitService.markVisitPaidWithMembership(visit, membershipId: m.id)
                            invalidateMembershipCache()
                            await onVisitsChanged()
                            await MainActor.run {
                                AppDesign.triggerSuccessHaptic()
                                isSavingVisit = false
                            }
                        } catch {
                            if let msg = AppErrors.userMessageIfNeeded(for: error) { await MainActor.run { visitsErrorMessage = msg } }
                        }
                    }
                },
                onAddEvent: { date in
                    dayDetailItem = nil
                    pendingEventDate = date
                }
            )
            .mainSheetPresentation(.half)
        }
        .sheet(isPresented: Binding(
            get: { pendingOneOffDate != nil },
            set: { if !$0 { pendingOneOffDate = nil } }
        )) {
            if let date = pendingOneOffDate {
                QuickAddVisitSheet(
                    traineeName: trainee.name,
                    coachProfileId: coachProfileId,
                    traineeProfileId: trainee.id,
                    visitService: visitService,
                    membershipService: membershipService,
                    initialDate: date,
                    preselectedMembershipId: nil,
                    onAdded: { Task { await onVisitsChanged(); await MainActor.run { pendingOneOffDate = nil } } },
                    onCancel: { pendingOneOffDate = nil }
                )
                .mainSheetPresentation(.half)
            }
        }
        .sheet(isPresented: Binding(
            get: { pendingEventDate != nil },
            set: { if !$0 { pendingEventDate = nil } }
        )) {
            if let date = pendingEventDate {
                AddEditEventSheet(
                    mode: .create(initialDate: date),
                    coachProfileId: coachProfileId,
                    traineeProfileId: trainee.id,
                    eventService: eventService,
                    onSaved: { Task { await onVisitsChanged(); await MainActor.run { pendingEventDate = nil } } },
                    onError: { msg in Task { await MainActor.run { visitsErrorMessage = msg } } },
                    onCancel: { pendingEventDate = nil }
                )
                .mainSheetPresentation(.half)
            }
        }
        .sheet(item: $eventToEdit) { ev in
            AddEditEventSheet(
                mode: .edit(ev),
                coachProfileId: coachProfileId,
                traineeProfileId: trainee.id,
                eventService: eventService,
                onSaved: { Task { await onVisitsChanged(); await MainActor.run { eventToEdit = nil } } },
                onError: { msg in Task { await MainActor.run { visitsErrorMessage = msg } } },
                onCancel: { eventToEdit = nil }
            )
            .mainSheetPresentation(.half)
        }
        .appConfirmationDialog(
            title: "Ошибка",
            message: visitsErrorMessage ?? "Произошла ошибка.",
            isPresented: Binding(
                get: { visitsErrorMessage != nil },
                set: { if !$0 { visitsErrorMessage = nil } }
            ),
            confirmTitle: "OK",
            onConfirm: { visitsErrorMessage = nil },
            onCancel: { visitsErrorMessage = nil }
        )
        .appConfirmationDialog(
            title: "Отменить посещение?",
            message: "Посещение будет помечено как отменённое. Оплата и списание с абонемента будут сняты.",
            isPresented: $showCancelConfirmation,
            confirmTitle: "Отменить",
            confirmRole: .destructive,
            onConfirm: {
                showCancelConfirmation = false
                guard let v = visitToCancel else { return }
                visitToCancel = nil
                cancelVisitAfterConfirmation(v)
            },
            onCancel: { showCancelConfirmation = false; visitToCancel = nil }
        )
        .overlay {
            if isCancelling || isSavingVisit {
                AppColors.overlayDim
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(AppColors.white)
                                .scaleEffect(1.1)
                            Text(isSavingVisit ? "Сохраняю…" : "Обновляю…")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.white)
                        }
                    }
            }
        }
        .allowsHitTesting(!isCancelling && !isSavingVisit)
    }
}

private struct ClientCardContactRow: View {
    let icon: String
    let title: String
    let value: String
    let url: URL?

    var body: some View {
        Group {
            if let url {
                Link(destination: url) {
                    HStack(spacing: 12) {
                        AppTablerIcon(icon)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .center)
                        Text(title)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(value)
                            .foregroundStyle(.secondary)
                        AppTablerIcon("upload-up")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, AppDesign.cardPadding)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
            } else {
                HStack(spacing: 12) {
                    AppTablerIcon(icon)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .center)
                    Text(title)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(value)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, AppDesign.cardPadding)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

