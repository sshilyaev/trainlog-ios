//
//  TraineeWorkoutsView.swift
//  TrainLog
//

import SwiftUI

/// Обёртка даты для шита «За день» в дневнике подопечного.
private struct TraineeDaySheetItem: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}

/// Экран «Мой календарь»: календарь посещений и событий, список за месяц; подопечный может добавлять/редактировать только события.
struct TraineeWorkoutsView: View {
    let profile: Profile
    let linkService: CoachTraineeLinkServiceProtocol
    let visitService: VisitServiceProtocol
    let eventService: EventServiceProtocol
    let calendarSummaryService: CalendarSummaryServiceProtocol
    let membershipService: MembershipServiceProtocol
    let profileService: ProfileServiceProtocol

    @State private var selectedMonth = Date()
    @State private var visits: [Visit] = []
    @State private var events: [Event] = []
    @State private var coachLinks: [CoachTraineeLink] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var pendingEventDate: Date?
    @State private var eventToEdit: Event?
    @State private var dayDetailItem: TraineeDaySheetItem?

    private let calendar = Calendar.current

    /// Первый тренер — для добавления события (события привязываются к паре тренер–подопечный).
    private var primaryCoachProfileId: String? {
        coachLinks.first?.coachProfileId
    }

    private var visitsInSelectedMonth: [Visit] {
        guard let interval = calendar.dateInterval(of: .month, for: selectedMonth) else { return [] }
        return visits.filter { $0.date >= interval.start && $0.date < interval.end }
            .sorted { $0.date > $1.date }
    }

    private var eventsInSelectedMonth: [Event] {
        guard let interval = calendar.dateInterval(of: .month, for: selectedMonth) else { return [] }
        return events.filter { $0.date >= interval.start && $0.date < interval.end }
            .sorted { $0.date > $1.date }
    }

    private var calendarItemsInSelectedMonth: [CalendarListItem] {
        (visitsInSelectedMonth.map { CalendarListItem.visit($0) } + eventsInSelectedMonth.map { CalendarListItem.event($0) })
            .sorted { $0.date > $1.date }
    }

    private var monthSummaryTotalVisits: Int {
        visitsInSelectedMonth.filter { $0.status != .cancelled }.count
    }

    private var monthSummaryEvents: Int {
        eventsInSelectedMonth.filter { !$0.isCancelled }.count
    }

    private var monthSummaryRangeCaption: String {
        selectedMonth.formattedRuMonthYear
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    CalendarAndListSkeletonView()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            monthSummarySection
                            calendarBlock
                            CalendarUnifiedListBlockView(
                                        items: calendarItemsInSelectedMonth,
                                        visits: visitsInSelectedMonth,
                                        payableMemberships: [],
                                        visitService: visitService,
                                        onPayWithMembership: nil,
                                        onMarkAsPaid: nil,
                                        onCancelVisit: nil,
                                        onEventTap: { eventToEdit = $0 },
                                        onCancelEvent: { ev in
                                            Task {
                                                var updated = ev
                                                updated.isCancelled = true
                                                try? await eventService.updateEvent(updated)
                                                await load()
                                            }
                                        }
                                    )
                        }
                        .padding(.bottom, AppDesign.sectionSpacing)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AdaptiveScreenBackground())
            .navigationTitle("Мой календарь")
            .navigationBarTitleDisplayMode(.inline)
            .task { await load() }
            .refreshable { await load() }
            .onChange(of: selectedMonth) { _, _ in Task { await load() } }
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
            .sheet(isPresented: Binding(
                get: { pendingEventDate != nil },
                set: { if !$0 { pendingEventDate = nil } }
            )) {
                if let date = pendingEventDate, let coachId = primaryCoachProfileId {
                    AddEditEventSheet(
                        mode: .create(initialDate: date),
                        coachProfileId: coachId,
                        traineeProfileId: profile.id,
                        eventService: eventService,
                        onSaved: { Task { await load(); await MainActor.run { pendingEventDate = nil } } },
                        onError: { msg in Task { await MainActor.run { errorMessage = msg } } },
                        onCancel: { pendingEventDate = nil }
                    )
                    .mainSheetPresentation(.half)
                }
            }
            .sheet(item: $eventToEdit) { event in
                AddEditEventSheet(
                    mode: .edit(event),
                    coachProfileId: event.coachProfileId,
                    traineeProfileId: profile.id,
                    eventService: eventService,
                    onSaved: { Task { await load(); await MainActor.run { eventToEdit = nil } } },
                    onError: { msg in Task { await MainActor.run { errorMessage = msg } } },
                    onCancel: { eventToEdit = nil }
                )
                .mainSheetPresentation(.half)
            }
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
                    payableMemberships: [],
                    onPayWithMembership: nil,
                    onMarkAsPaid: nil,
                    onCancelVisit: nil,
                    onEventTap: { eventToEdit = $0 },
                    onCancelEvent: { ev in
                        Task {
                            var updated = ev
                            updated.isCancelled = true
                            try? await eventService.updateEvent(updated)
                            await load()
                        }
                    },
                    onDismiss: { dayDetailItem = nil },
                    onAddOneOffVisit: nil,
                    addVisitMemberships: nil,
                    onAddVisitWithMembership: nil,
                    onAddEvent: primaryCoachProfileId != nil ? { date in
                        dayDetailItem = nil
                        pendingEventDate = date
                    } : nil
                )
                .mainSheetPresentation(.half)
            }
        }
    }

    @ViewBuilder
    private var monthSummarySection: some View {
        HeroCard(
            icon: "calendar.badge.checkmark",
            title: "Сводка за месяц",
            headline: monthSummaryRangeCaption,
            description: "Краткая активность в вашем дневнике за выбранный месяц.",
            accent: AppColors.profileAccent,
            decoration: .glow
        ) {
            MetricRowLarge(
                items: [
                    InfoValueItem(
                        title: "Посещений",
                        value: "\(monthSummaryTotalVisits)",
                        accentColor: AppColors.visitsBySubscription
                    ),
                    InfoValueItem(
                        title: "Событий",
                        value: "\(monthSummaryEvents)",
                        accentColor: EventColor.defaultColor
                    ),
                    InfoValueItem(
                        title: "Всего",
                        value: "\(monthSummaryTotalVisits + monthSummaryEvents)",
                        accentColor: AppColors.accent
                    ),
                ],
                backgroundColor: AppColors.profileAccent,
                textColor: AppColors.label
            )
            .padding(.top, 4)

            if let primaryCoachProfileId {
                Button {
                    pendingEventDate = Date()
                } label: {
                    Text("Добавить событие на сегодня")
                        .appTypography(.button)
                        .foregroundStyle(AppColors.white)
                        .frame(maxWidth: .infinity, minHeight: AppDesign.minTouchTarget)
                        .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .accessibilityHint("Создать событие в дневнике на текущую дату")
                .id(primaryCoachProfileId)
            }
        }
        .actionBlockStyle()
    }

    @ViewBuilder
    private var calendarBlock: some View {
        VisitsCalendarView(
            selectedMonth: $selectedMonth,
            visits: visits,
            events: events,
            onDayTapped: nil,
            addVisitMemberships: nil,
            onAddOneOffVisit: nil,
            onAddVisitWithMembership: nil,
            onAddEvent: primaryCoachProfileId != nil ? { date in pendingEventDate = date } : nil,
            onEditEvent: { eventToEdit = $0 },
            onCancelEvent: { ev in
                Task {
                    var updated = ev
                    updated.isCancelled = true
                    try? await eventService.updateEvent(updated)
                    await load()
                }
            },
            dayVisitActions: nil,
            onShowDayDetail: { dayDetailItem = TraineeDaySheetItem(date: $0) },
            cardTitle: "Календарь"
        )
    }

    private func load() async {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }
        do {
            let links = try await linkService.fetchLinksForTrainee(traineeProfileId: profile.id)
            await MainActor.run { coachLinks = links }
            let cal = calendar
            guard let interval = cal.dateInterval(of: .month, for: selectedMonth) else { return }
            var allVisits: [Visit] = []
            var allEvents: [Event] = []
            for link in links {
                if let feed = try? await calendarSummaryService.fetchCalendar(coachProfileId: link.coachProfileId, traineeProfileId: profile.id, from: interval.start, to: interval.end) {
                    allVisits.append(contentsOf: feed.visits)
                    allEvents.append(contentsOf: feed.events)
                } else {
                    async let vTask = visitService.fetchVisits(coachProfileId: link.coachProfileId, traineeProfileId: profile.id)
                    async let eTask = eventService.fetchEvents(coachProfileId: link.coachProfileId, traineeProfileId: profile.id)
                    let (visitList, eventList) = try await (vTask, eTask)
                    allVisits.append(contentsOf: visitList)
                    allEvents.append(contentsOf: eventList)
                }
            }
            await MainActor.run {
                visits = allVisits.sorted { $0.date > $1.date }
                events = allEvents.sorted { $0.date > $1.date }
            }
        } catch {
            await MainActor.run {
                if let msg = AppErrors.userMessageIfNeeded(for: error) {
                    visits = []
                    events = []
                    errorMessage = msg
                }
            }
        }
    }
}

// MARK: - Просмотр своих абонементов (только чтение)

struct TraineeMembershipsView: View {
    let traineeProfileId: String
    let membershipService: MembershipServiceProtocol
    let visitService: VisitServiceProtocol

    @State private var memberships: [Membership] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    /// false = Активные, true = Завершённые
    @State private var showArchived = false
    @State private var showVisitsForMembership: Membership? = nil
    @State private var allVisits: [Visit] = []

    private var activeList: [Membership] {
        memberships.filter { $0.isActive }
    }
    private var finishedList: [Membership] {
        memberships.filter { !$0.isActive }
    }

    var body: some View {
        Group {
            if isLoading {
                LoadingBlockView(message: "Загружаю абонементы…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let msg = errorMessage {
                ContentUnavailableView(
                    "Не удалось загрузить абонементы",
                    image: "tabler-outline-minus-square",
                    description: Text(msg)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if memberships.isEmpty {
                VStack(spacing: AppDesign.blockSpacing) {
                    ContentUnavailableView(
                        "Нет абонементов",
                        image: "tag",
                        description: Text("Абонементы, которые оформит тренер, появятся здесь.")
                    )
                    SettingsCard(title: "Что сделать дальше") {
                        Text("Напишите тренеру, какой формат вам нужен: по посещениям или безлимит на период. После создания абонемент появится автоматически.")
                            .appTypography(.secondary)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, AppDesign.cardPadding)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        Picker("", selection: $showArchived) {
                            Text("Активные").tag(false)
                            Text("Завершённые").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, AppDesign.cardPadding)
                        .padding(.top, AppDesign.blockSpacing)
                        .padding(.bottom, AppDesign.blockSpacing)

                        if showArchived {
                            traineeArchivedContent
                        } else {
                            traineeActiveContent
                        }
                    }
            .padding(.bottom, AppDesign.sectionSpacing)
                }
            }
        }
        .background(AdaptiveScreenBackground())
        .navigationTitle("Мои абонементы")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $showVisitsForMembership) { membership in
            let visits = allVisits.filter { $0.membershipId == membership.id }.sorted { $0.date > $1.date }
            MembershipVisitsSheet(
                membership: membership,
                visits: visits,
                initialMonth: MembershipVisitsSheet.initialMonthForVisits(visits),
                onDismiss: { showVisitsForMembership = nil }
            )
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
    }

    @ViewBuilder
    private var traineeActiveContent: some View {
        if activeList.isEmpty {
            VStack(spacing: AppDesign.blockSpacing) {
                ContentUnavailableView(
                    "Нет активных абонементов",
                    image: "tag",
                    description: Text("Перейдите во вкладку «Завершённые».")
                )
                SettingsCard(title: "Подсказка") {
                    Text("Если тренер уже закрыл абонемент, его история будет во вкладке «Завершённые». Для нового периода попросите создать новый абонемент.")
                        .appTypography(.secondary)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, AppDesign.cardPadding)
            }
            .padding(.vertical, 32)
        } else {
            VStack(spacing: AppDesign.blockSpacing) {
                ForEach(activeList) { m in
                    MembershipCardNewView(
                        membership: m,
                        isActive: true,
                        onAddVisit: nil,
                        onFreeze: nil,
                        onUnfreeze: nil,
                        onClose: nil,
                        onViewVisits: { showVisitsForMembership = m }
                    )
                }
            }
            .padding(.horizontal, AppDesign.cardPadding)
        }
    }

    @ViewBuilder
    private var traineeArchivedContent: some View {
        if finishedList.isEmpty {
            ContentUnavailableView(
                "Нет завершённых абонементов",
                image: "tabler-outline-folder",
                description: Text("Здесь появятся абонементы после использования или отмены.")
            )
            .padding(.vertical, 32)
        } else {
            let columns = [GridItem(.flexible(), spacing: AppDesign.blockSpacing), GridItem(.flexible(), spacing: AppDesign.blockSpacing)]
            LazyVGrid(columns: columns, spacing: AppDesign.blockSpacing) {
                ForEach(finishedList) { m in
                    MembershipFinishedTileView(
                        membership: m,
                        completionDate: m.effectiveEndDate,
                        onViewVisits: { showVisitsForMembership = m }
                    )
                }
            }
            .padding(.horizontal, AppDesign.cardPadding)
        }
    }

    private func load() async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        defer { Task { @MainActor in isLoading = false } }
        do {
            let list = try await membershipService.fetchMembershipsForTrainee(traineeProfileId: traineeProfileId)
            await MainActor.run { memberships = list.sorted { $0.createdAt > $1.createdAt } }
            let coachIds = Array(Set(list.map(\.coachProfileId)))
            var collected: [Visit] = []
            for coachId in coachIds {
                if let v = try? await visitService.fetchVisits(coachProfileId: coachId, traineeProfileId: traineeProfileId) {
                    collected.append(contentsOf: v)
                }
            }
            await MainActor.run { allVisits = collected }
        } catch {
            if let msg = AppErrors.userMessageIfNeeded(for: error) { await MainActor.run { errorMessage = msg } }
        }
    }
}
