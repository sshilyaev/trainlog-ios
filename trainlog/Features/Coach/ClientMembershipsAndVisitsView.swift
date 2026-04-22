//
//  ClientMembershipsAndVisitsView.swift
//  TrainLog
//

import SwiftUI

// MARK: - Общий календарь посещаемости (тренер и подопечный). Логика взаимодействия — снаружи (Binding месяца и массив визитов).

struct VisitsCalendarView: View {
    enum ContainerStyle {
        /// Обычная карточка экрана (как было): с внешними отступами вокруг.
        case screenCard
        /// Встроенная карточка (например внутри раскрытия строки): без внешних padding'ов.
        case inlineCard
        /// Встроенный контент без собственной карточки (когда контейнер уже есть снаружи).
        case embedded
    }

    @Binding var selectedMonth: Date
    let visits: [Visit]
    /// События для отображения на календаре (точки на днях). Объединяются с посещениями.
    var events: [Event] = []
    /// Если задан — по тапу на день вызывается с датой этого дня (start of day). Только для тренера.
    var onDayTapped: ((Date) -> Void)? = nil
    /// Для тренера: всплывающее меню «Добавить посещение» (как у долга). Передать абонементы и колбэки.
    var addVisitMemberships: [Membership]? = nil
    var onAddOneOffVisit: ((Date) -> Void)? = nil
    var onAddVisitWithMembership: ((Date, Membership) -> Void)? = nil
    /// Добавить событие (кнопка «Событие») на выбранную дату (тренер).
    var onAddEvent: ((Date) -> Void)? = nil
    /// Редактировать / отменить событие (тренер).
    var onEditEvent: ((Event) -> Void)? = nil
    var onCancelEvent: ((Event) -> Void)? = nil
    /// Для тренера: при тапе на день с посещением — те же действия, что в списке «Посещения за месяц» (отменить, отметить оплаченным, списать с абонемента).
    var dayVisitActions: (payableMemberships: [Membership], onMarkAsPaid: (Visit) -> Void, onPayWithMembership: (Visit, Membership) -> Void, onCancelVisit: (Visit) -> Void)? = nil
    /// Показать шит «За день» со списком посещений и событий за выбранную дату.
    var onShowDayDetail: ((Date) -> Void)? = nil
    /// Опциональный футер внутри карточки (например кнопка «Показать подробнее» в карточке подопечного).
    var footerContent: AnyView? = nil
    /// Заголовок карточки календаря. По умолчанию «Посещаемость».
    var cardTitle: String = "Посещаемость"
    /// Визуальный контейнер календаря (screen / inline).
    var containerStyle: ContainerStyle = .screenCard

    private var showAddVisitMenu: Bool {
        onAddOneOffVisit != nil
    }

    private let calendar = Calendar.current
    private var monthTitle: String { selectedMonth.formattedRuMonthYear }

    // Кешируем агрегации по дням, чтобы не пересчитывать их на каждый scroll-driven re-render.
    @State private var cachedActiveVisitsByDay: [Date: [Visit]] = [:]
    @State private var cachedActiveEventsByDay: [Date: [Event]] = [:]

    private var visitsKey: Int { visits.reduce(0) { $0 ^ $1.id.hashValue } }
    private var eventsKey: Int { events.reduce(0) { $0 ^ $1.id.hashValue } }

    private func rebuildCaches() {
        cachedActiveVisitsByDay = Dictionary(
            grouping: visits.filter { $0.status != .cancelled },
            by: { calendar.startOfDay(for: $0.date) }
        )
        var map: [Date: [Event]] = [:]
        for event in events where !event.isCancelled {
            let start = calendar.startOfDay(for: event.periodStart)
            let end = calendar.startOfDay(for: event.periodEnd)
            var cursor = start
            while cursor <= end {
                map[cursor, default: []].append(event)
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }
        }
        cachedActiveEventsByDay = map
    }

    private struct DayItem {
        let day: Int?
        let hasVisit: Bool
        let absent: Bool
        let debt: Bool
        let count: Int
        let eventColor: Color?
        let hasOnlyEvents: Bool
    }

    private var daysInMonth: [DayItem] {
        guard let _ = calendar.dateInterval(of: .month, for: selectedMonth),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)) else {
            return []
        }
        let range = calendar.range(of: .day, in: .month, for: selectedMonth)!
        let numberOfDays = range.count
        let firstWeekday = calendar.component(.weekday, from: first)
        let leadingBlanks = (firstWeekday - 2 + 7) % 7
        var result: [DayItem] = []
        for _ in 0..<leadingBlanks {
            result.append(DayItem(day: nil, hasVisit: false, absent: false, debt: false, count: 0, eventColor: nil, hasOnlyEvents: false))
        }
        for day in 1...numberOfDays {
            guard let date = calendar.date(bySetting: .day, value: day, of: first) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            let activeVisits = cachedActiveVisitsByDay[startOfDay] ?? []
            let activeEventsOnDay = cachedActiveEventsByDay[startOfDay] ?? []
            let count = activeVisits.count + activeEventsOnDay.count
            let hasVisit = count > 0
            let absent = activeVisits.contains { $0.status == .noShow }
            let debt = activeVisits.contains { $0.paymentStatus == .debt }
            let hasOnlyEvents = activeVisits.isEmpty && !activeEventsOnDay.isEmpty
            let eventColor: Color? = activeEventsOnDay.first.map { EventColor.color(eventType: $0.eventType, overrideHex: $0.colorHex) }
            result.append(DayItem(day: day, hasVisit: hasVisit, absent: absent, debt: debt, count: count, eventColor: eventColor, hasOnlyEvents: hasOnlyEvents))
        }
        let totalCells = 42
        while result.count < totalCells {
            result.append(DayItem(day: nil, hasVisit: false, absent: false, debt: false, count: 0, eventColor: nil, hasOnlyEvents: false))
        }
        return Array(result.prefix(totalCells))
    }

    var body: some View {
        calendarContainer {
            VStack(spacing: AppDesign.rowSpacing) {
                HStack {
                    Button {
                        if let prev = calendar.date(byAdding: .month, value: -1, to: selectedMonth) {
                            selectedMonth = prev
                        }
                    } label: {
                        AppTablerIcon("chevron-left")
                            .appTypography(.bodyEmphasis)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(monthTitle)
                        .appTypography(.sectionTitle)
                    Spacer()
                    Button {
                        if let next = calendar.date(byAdding: .month, value: 1, to: selectedMonth) {
                            selectedMonth = next
                        }
                    } label: {
                        AppTablerIcon("chevron-right")
                            .appTypography(.bodyEmphasis)
                            .foregroundStyle(.secondary)
                    }
                }
                let weekdays = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
                let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                    ForEach(weekdays, id: \.self) { w in
                        Text(w)
                            .appTypography(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, item in
                        let dayDate: Date? = item.day.flatMap { d in
                            guard let first = firstOfMonth,
                                  let date = calendar.date(bySetting: .day, value: d, of: first) else { return nil }
                            return calendar.startOfDay(for: date)
                        }
                        let visitsOnDay: [Visit]? = dayDate.map { start in cachedActiveVisitsByDay[start] ?? [] }
                        let eventsOnDay: [Event]? = dayDate.map { start in cachedActiveEventsByDay[start] ?? [] }
                        VisitsCalendarDayCell(
                            day: item.day,
                            hasVisit: item.hasVisit,
                            absent: item.absent,
                            debt: item.debt,
                            visitsCount: item.count,
                            eventColor: item.eventColor,
                            hasOnlyEvents: item.hasOnlyEvents,
                            dateForTap: dayDate,
                            visitsOnDay: item.hasVisit ? visitsOnDay : nil,
                            eventsOnDay: eventsOnDay,
                            dayVisitActions: dayVisitActions,
                            onDayTapped: onDayTapped,
                            addVisitMemberships: showAddVisitMenu ? addVisitMemberships : nil,
                            onAddOneOffVisit: showAddVisitMenu ? onAddOneOffVisit : nil,
                            onAddVisitWithMembership: showAddVisitMenu ? onAddVisitWithMembership : nil,
                            onAddEvent: onAddEvent,
                            onEditEvent: onEditEvent,
                            onCancelEvent: onCancelEvent,
                            onShowDayDetail: onShowDayDetail
                        )
                    }
                }
                if let footer = footerContent {
                    Divider()
                        .padding(.leading, containerStyle == .embedded ? 0 : AppDesign.cardPadding)
                    footer
                }
            }
        }
        .padding(.top, containerStyle == .screenCard ? AppDesign.blockSpacing : 0)
        .onAppear { rebuildCaches() }
        .onChange(of: visitsKey) { _, _ in rebuildCaches() }
        .onChange(of: eventsKey) { _, _ in rebuildCaches() }
    }

    @ViewBuilder
    private func calendarContainer<Content: View>(@ViewBuilder _ content: @escaping () -> Content) -> some View {
        switch containerStyle {
        case .screenCard:
            SettingsCard(title: cardTitle) { content() }
        case .inlineCard:
            VStack(alignment: .leading, spacing: AppDesign.rowSpacing) {
                if !cardTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(cardTitle)
                        .appTypography(.sectionTitle)
                }
                content()
            }
            .padding(AppDesign.cardPadding)
            .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
        case .embedded:
            VStack(alignment: .leading, spacing: AppDesign.rowSpacing) {
                if !cardTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(cardTitle)
                        .appTypography(.sectionTitle)
                }
                content()
            }
        }
    }
}

private struct VisitsCalendarDayCell: View {
    let day: Int?
    let hasVisit: Bool
    let absent: Bool
    let debt: Bool
    let visitsCount: Int
    var eventColor: Color? = nil
    var hasOnlyEvents: Bool = false
    var dateForTap: Date? = nil
    var visitsOnDay: [Visit]? = nil
    var eventsOnDay: [Event]? = nil
    var dayVisitActions: (payableMemberships: [Membership], onMarkAsPaid: (Visit) -> Void, onPayWithMembership: (Visit, Membership) -> Void, onCancelVisit: (Visit) -> Void)? = nil
    var onDayTapped: ((Date) -> Void)? = nil
    var addVisitMemberships: [Membership]? = nil
    var onAddOneOffVisit: ((Date) -> Void)? = nil
    var onAddVisitWithMembership: ((Date, Membership) -> Void)? = nil
    var onAddEvent: ((Date) -> Void)? = nil
    var onEditEvent: ((Event) -> Void)? = nil
    var onCancelEvent: ((Event) -> Void)? = nil

    var onShowDayDetail: ((Date) -> Void)? = nil

    private var showUnifiedMenu: Bool {
        dateForTap != nil && (onAddOneOffVisit != nil || onAddEvent != nil || onShowDayDetail != nil || !(visitsOnDay?.isEmpty ?? true) || !(eventsOnDay?.isEmpty ?? true))
    }

    var body: some View {
        ZStack {
            if let d = day {
                if absent {
                    Circle()
                        .fill(AppColors.visitsCancelled)
                        .frame(width: 28, height: 28)
                } else if debt {
                    Circle()
                        .fill(AppColors.visitsOneTimeDebt)
                        .frame(width: 28, height: 28)
                } else if hasVisit {
                    Circle()
                        .fill(hasOnlyEvents ? (eventColor ?? EventColor.defaultColor) : AppColors.visitsBySubscription)
                        .frame(width: 28, height: 28)
                }
                dayContent(d: d)

                if visitsCount > 1 {
                    Text("\(min(visitsCount, 9))")
                        .appTypography(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(AppColors.secondarySystemGroupedBackground, in: Capsule())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .offset(x: 6, y: 6)
                        .accessibilityLabel("Посещений: \(visitsCount)")
                }
            }
        }
        .frame(height: 32)
    }

    @ViewBuilder
    private func dayContent(d: Int) -> some View {
        if showUnifiedMenu, let date = dateForTap {
            if let onShowDayDetail {
                Button {
                    onShowDayDetail(date)
                } label: {
                    Text("\(d)")
                        .appTypography(.caption)
                        .foregroundStyle(AppColors.label)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
            } else {
                Menu {
                    Menu {
                        if let onAddOneOff = onAddOneOffVisit {
                            Button { onAddOneOff(date) } label: {
                                Label("Разовое посещение", appIcon: "calendar-filled")
                            }
                            .appTypography(.caption)
                        }
                        if let memberships = addVisitMemberships, !memberships.isEmpty {
                            ForEach(memberships) { m in
                                Button { onAddVisitWithMembership?(date, m) } label: {
                                    Label(m.displayCode.map { "Списать с аб. №\($0)" } ?? "Списать с аб", appIcon: "tag")
                                }
                                .appTypography(.caption)
                            }
                        } else if addVisitMemberships != nil {
                            Text("Нет активных абонементов").appTypography(.caption).foregroundStyle(.secondary)
                        }
                        if onAddEvent != nil {
                            Button { onAddEvent?(date) } label: {
                                Label("Событие", appIcon: "award-medal")
                            }
                            .appTypography(.caption)
                        }
                        if let evts = eventsOnDay, !evts.isEmpty, let onEditEvent, let onCancelEvent {
                            ForEach(evts) { e in
                                Menu {
                                    if let desc = e.eventDescription?.trimmingCharacters(in: .whitespacesAndNewlines), !desc.isEmpty {
                                        Text(desc).appTypography(.caption)
                                    }
                                    Button { onEditEvent(e) } label: {
                                        Label("Редактировать", appIcon: "pencil-edit")
                                    }
                                    .appTypography(.caption)
                                    Button(role: .destructive) { onCancelEvent(e) } label: {
                                        Label("Удалить", appIcon: "delete-dustbin-01")
                                    }
                                    .appTypography(.caption)
                                } label: {
                                    Label(e.title, appIcon: "award-medal")
                                }
                                .appTypography(.caption)
                            }
                        }
                    } label: { Label("Добавить", appIcon: "plus-circle") }
                    if let firstVisit = visitsOnDay?.first, let actions = dayVisitActions {
                        if firstVisit.paymentStatus == .debt {
                            Button { actions.onMarkAsPaid(firstVisit) } label: {
                                Label("Пометить как оплачено", appIcon: "check-tick-circle")
                            }
                            .appTypography(.caption)
                        }
                        Button(role: .destructive) { actions.onCancelVisit(firstVisit) } label: {
                            Label("Отменить посещение", appIcon: "multiple-cross-cancel-circle")
                        }
                        .appTypography(.caption)
                    }
                } label: {
                    Text("\(d)")
                        .appTypography(.caption)
                        .foregroundStyle(AppColors.label)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .contentShape(Rectangle())
                }
            }
        } else if visitsCount > 0, let date = dateForTap, let onTap = onDayTapped, visitsOnDay?.isEmpty == false {
            Menu {
                Button(role: .destructive) { onTap(date) } label: {
                    Label("Отменить посещение", appIcon: "multiple-cross-cancel-circle")
                }
                .appTypography(.caption)
            } label: {
                Text("\(d)")
                    .appTypography(.caption)
                    .foregroundStyle(AppColors.label)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .contentShape(Rectangle())
            }
        } else if let date = dateForTap, let onTap = onDayTapped {
            Button {
                onTap(date)
            } label: {
                Text("\(d)")
                    .appTypography(.caption)
                    .foregroundStyle(AppColors.label)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
        } else {
            Text("\(d)")
                .appTypography(.caption)
                .foregroundStyle(AppColors.label)
        }
    }

}

// MARK: - Шит «За день»: Добавить (разовое / с абонемента / событие) + список посещений и событий за дату

struct DayDetailSheet: View {
    let date: Date
    let visits: [Visit]
    let events: [Event]
    let payableMemberships: [Membership]
    let onPayWithMembership: ((Visit, Membership) -> Void)?
    let onMarkAsPaid: ((Visit) -> Void)?
    /// Вызывается после подтверждения в диалоге (диалог показывается внутри щита, поверх контента).
    let onCancelVisit: ((Visit) -> Void)?
    let onEventTap: (Event) -> Void
    let onCancelEvent: (Event) -> Void
    let onDismiss: () -> Void
    /// Блок «Добавить» в шапке шита (при нажатии на день календаря).
    var onAddOneOffVisit: ((Date) -> Void)? = nil
    var addVisitMemberships: [Membership]? = nil
    var onAddVisitWithMembership: ((Date, Membership) -> Void)? = nil
    var onAddEvent: ((Date) -> Void)? = nil

    @State private var visitPendingCancel: Visit?
    @State private var showCancelVisitConfirmation = false

    private var dateTitle: String { date.formattedRuLong }

    private var dayItems: [CalendarListItem] {
        (visits.map { CalendarListItem.visit($0) } + events.map { CalendarListItem.event($0) })
            .sorted { $0.date < $1.date }
    }

    private var showAddSection: Bool {
        onAddOneOffVisit != nil || onAddEvent != nil || (addVisitMemberships != nil && !(addVisitMemberships?.isEmpty ?? true))
    }

    var body: some View {
        NavigationStack {
            List {
                if showAddSection {
                    Section {
                        if let onAddOneOff = onAddOneOffVisit {
                            Button {
                                onAddOneOff(date)
                            } label: {
                                Label("Разовое посещение", appIcon: "calendar-filled")
                                    .foregroundStyle(AppColors.label)
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                            .listRowBackground(AppColors.secondarySystemGroupedBackground)
                            .listRowInsets(EdgeInsets(top: 12, leading: AppDesign.cardPadding, bottom: 12, trailing: AppDesign.cardPadding))
                        }
                        if let memberships = addVisitMemberships, !memberships.isEmpty, let onAdd = onAddVisitWithMembership {
                            ForEach(memberships) { m in
                                Button {
                                    onAdd(date, m)
                                } label: {
                                    Label(m.displayCode.map { "Списать с аб. №\($0)" } ?? "Списать с аб", appIcon: "tag")
                                        .foregroundStyle(AppColors.label)
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                                .listRowBackground(AppColors.secondarySystemGroupedBackground)
                                .listRowInsets(EdgeInsets(top: 12, leading: AppDesign.cardPadding, bottom: 12, trailing: AppDesign.cardPadding))
                            }
                        }
                        if let onAddEvent {
                            Button {
                                onAddEvent(date)
                            } label: {
                                Label("Событие", appIcon: "award-medal")
                                    .foregroundStyle(AppColors.label)
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                            .listRowBackground(AppColors.secondarySystemGroupedBackground)
                            .listRowInsets(EdgeInsets(top: 12, leading: AppDesign.cardPadding, bottom: 12, trailing: AppDesign.cardPadding))
                        }
                    } header: {
                        Text("Добавить")
                            .appTypography(.bodyEmphasis)
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    if dayItems.isEmpty {
                        Text("В этот день нет посещений и событий")
                            .appTypography(.secondary)
                            .foregroundStyle(.secondary)
                            .listRowBackground(AppColors.secondarySystemGroupedBackground)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 12, leading: AppDesign.cardPadding, bottom: 12, trailing: AppDesign.cardPadding))
                    } else {
                        ForEach(dayItems) { item in
                            switch item {
                            case .visit(let v):
                                CoachVisitRow(
                                    visit: v,
                                    payableMemberships: payableMemberships,
                                    onPayWithMembership: onPayWithMembership.map { f in { m in f(v, m) } },
                                    onMarkAsPaid: onMarkAsPaid.map { f in { f(v) } },
                                    onCancel: onCancelVisit == nil ? nil : {
                                        visitPendingCancel = v
                                        showCancelVisitConfirmation = true
                                    },
                                    onShowDayDetail: nil
                                )
                                .listRowBackground(AppColors.secondarySystemGroupedBackground)
                                .listRowInsets(EdgeInsets(top: 12, leading: AppDesign.cardPadding, bottom: 12, trailing: AppDesign.cardPadding))
                            case .event(let e):
                                EventRowView(
                                    event: e,
                                    onEdit: { onEventTap(e) },
                                    onCancel: { onCancelEvent(e) }
                                )
                                .listRowBackground(AppColors.secondarySystemGroupedBackground)
                                .listRowInsets(EdgeInsets(top: 12, leading: AppDesign.cardPadding, bottom: 12, trailing: AppDesign.cardPadding))
                            }
                        }
                    }
                } header: {
                    Text("За день")
                        .appTypography(.bodyEmphasis)
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.visible)
            .background(AppColors.systemGroupedBackground)
            .navigationTitle(dateTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Готово") { onDismiss() }
                        .foregroundStyle(.primary)
                }
            }
        }
        .appConfirmationDialog(
            title: "Отменить посещение?",
            message: "Посещение будет помечено как отменённое. Оплата и списание с абонемента будут сняты.",
            isPresented: $showCancelVisitConfirmation,
            confirmTitle: "Отменить",
            confirmRole: .destructive,
            onConfirm: {
                showCancelVisitConfirmation = false
                guard let v = visitPendingCancel else { return }
                visitPendingCancel = nil
                onCancelVisit?(v)
            },
            onCancel: {
                showCancelVisitConfirmation = false
                visitPendingCancel = nil
            }
        )
    }
}

// MARK: - Единый список календаря (посещения + события) за месяц

struct CalendarUnifiedListBlockView: View {
    let items: [CalendarListItem]
    let visits: [Visit]
    let payableMemberships: [Membership]
    let visitService: VisitServiceProtocol
    /// nil — только просмотр посещений (подопечный), без меню действий.
    let onPayWithMembership: ((Visit, Membership) -> Void)?
    let onMarkAsPaid: ((Visit) -> Void)?
    let onCancelVisit: ((Visit) -> Void)?
    let onEventTap: (Event) -> Void
    let onCancelEvent: (Event) -> Void
    /// Показать шит «За день» для даты визита.
    var onShowDayDetail: ((Date) -> Void)? = nil

    var body: some View {
        Group {
            if items.isEmpty {
                Text("В выбранном месяце нет посещений и событий")
                    .appTypography(.secondary)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, AppDesign.cardPadding)
                    .padding(.vertical, AppDesign.sectionSpacing)
            } else {
                SettingsCard(title: "За месяц") {
                    VStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            if index != 0 {
                                Divider()
                                    .padding(.leading, AppDesign.listDividerLeading)
                            }
                            switch item {
                            case .visit(let v):
                                CoachVisitRow(
                                    visit: v,
                                    payableMemberships: payableMemberships,
                                    onPayWithMembership: onPayWithMembership.map { f in { m in f(v, m) } },
                                    onMarkAsPaid: onMarkAsPaid.map { f in { f(v) } },
                                    onCancel: onCancelVisit.map { f in { f(v) } },
                                    onShowDayDetail: onShowDayDetail.map { cb in { cb(v.date) } }
                                )
                            case .event(let e):
                                EventRowView(
                                    event: e,
                                    onEdit: { onEventTap(e) },
                                    onCancel: { onCancelEvent(e) }
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding(.top, AppDesign.blockSpacing)
    }
}

private struct EventRowView: View {
    let event: Event
    var onEdit: (() -> Void)? = nil
    var onCancel: (() -> Void)? = nil
    @State private var isExpanded = false

    private var dateText: String {
        if event.mode == .period {
            return "\(event.periodStart.formattedRuList) - \(event.periodEnd.formattedRuList)"
        }
        return event.date.formattedRuList
    }
    private var hasDescription: Bool {
        guard let d = event.eventDescription else { return false }
        return !d.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var canAct: Bool { !event.isCancelled && (onEdit != nil || onCancel != nil) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListActionRow(
                verticalPadding: 8,
                horizontalPadding: AppDesign.cardPadding,
                cornerRadius: 0,
                isInteractive: false
            ) {
                HStack(spacing: 12) {
                    AppTablerIcon("award-medal")
                        .foregroundStyle(event.isCancelled ? .secondary : EventColor.color(eventType: event.eventType, overrideHex: event.colorHex))
                        .frame(width: 28, alignment: .center)
                    HStack(spacing: 4) {
                        Text(dateText)
                            .appTypography(.secondary)
                            .foregroundStyle(.primary)
                        if !isExpanded && !event.isCancelled {
                            Text("·")
                                .appTypography(.secondary)
                                .foregroundStyle(.secondary)
                            Text(event.title)
                                .appTypography(.secondary)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        if event.isCancelled {
                            Text("Событие отменено")
                                .appTypography(.caption)
                                .foregroundStyle(AppColors.destructive)
                        }
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                        } label: {
                            AppTablerIcon(isExpanded ? "chevron.up" : "chevron.down")
                                .appTypography(.caption)
                                .foregroundStyle(AppColors.accent)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            } trailing: {
                if canAct {
                    TiniActionButton(
                        color: EventColor.color(eventType: event.eventType, overrideHex: event.colorHex),
                        font: .title3,
                        minWidth: 40,
                        minHeight: 40,
                        style: .pressable
                    ) {
                        if let onEdit {
                            EditMenuAction(action: onEdit)
                        }
                        if let onCancel {
                            CancelMenuAction(action: onCancel)
                        }
                    }
                } else if !event.isCancelled {
                    AppTablerIcon("chevron-right")
                        .appTypography(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .appTypography(.secondary)
                        .foregroundStyle(.primary)
                    if let desc = event.eventDescription?.trimmingCharacters(in: .whitespacesAndNewlines), !desc.isEmpty {
                        Text(desc)
                            .appTypography(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if event.mode == .period {
                        Text("Тип: \(event.eventType.title)\(event.freezeMembership ? " • Заморозка абонемента" : "")")
                            .appTypography(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, AppDesign.listDividerLeading)
                .padding(.top, 2)
                .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct CoachMembershipRow: View {
    let membership: Membership
    let highlight: Bool
    var onFreeze: ((Membership, Int) -> Void)? = nil
    var onUnfreeze: ((Membership) -> Void)? = nil

    @State private var showFreezeSheet = false
    @State private var freezeDaysInput = 7

    private var createdDateText: String {
        membership.createdAt.formattedRuShort
    }

    private var endDateText: String? {
        membership.effectiveEndDate.map { $0.formattedRuShort }
    }

    private var statusText: String {
        switch membership.status {
        case .active: return "Активен"
        case .finished: return "Завершён"
        case .cancelled: return "Отменён"
        }
    }

    private var statusColor: Color {
        switch membership.status {
        case .active: return .green
        case .finished: return .secondary
        case .cancelled: return AppColors.visitsOneTimeDebt
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            AppTablerIcon("tag")
                .foregroundStyle(highlight ? .green : .secondary)
                .frame(width: 28, alignment: .center)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if let code = membership.displayCode, !code.isEmpty {
                        Text("№\(code)")
                            .appTypography(.bodyEmphasis)
                            .foregroundStyle(.primary)
                    }
                    if membership.kind == .byVisits {
                        Text("\(membership.usedSessions) из \(membership.totalSessions)")
                            .appTypography(highlight ? .bodyEmphasis : .secondary)
                            .foregroundStyle(.primary)
                    } else if let end = endDateText {
                        Text("До \(end)")
                            .appTypography(highlight ? .bodyEmphasis : .secondary)
                            .foregroundStyle(.primary)
                    }
                }
                HStack(spacing: 6) {
                    if membership.kind == .unlimited {
                        Text("Посещено \(membership.usedSessions)")
                            .appTypography(.caption)
                            .foregroundStyle(.secondary)
                        if membership.freezeDays > 0 {
                            Text("· заморозка \(membership.freezeDays) дн.")
                                .appTypography(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Text("Создан: \(createdDateText)")
                    .appTypography(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text(statusText)
                .appTypography(.caption)
                .foregroundStyle(statusColor)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .contextMenu {
            if highlight, membership.kind == .unlimited {
                if onFreeze != nil {
                    Button {
                        freezeDaysInput = 7
                        showFreezeSheet = true
                    } label: {
                        Label("Заморозить абонемент", appIcon: "snowflake")
                    }
                }
                if membership.freezeDays > 0, let onUnfreeze = onUnfreeze {
                    Button {
                        onUnfreeze(membership)
                    } label: {
                        Label("Снять заморозку", appIcon: "snowflake")
                    }
                }
            }
        }
        .sheet(isPresented: $showFreezeSheet) {
            FreezeMembershipSheet(
                membership: membership,
                days: $freezeDaysInput,
                onApply: {
                    onFreeze?(membership, freezeDaysInput)
                    showFreezeSheet = false
                },
                onCancel: { showFreezeSheet = false }
            )
            .mainSheetPresentation(.detents([.height(340)]))
        }
    }
}

// MARK: - Элемент календаря: посещение или событие (для единого списка)

enum CalendarListItem: Identifiable {
    case visit(Visit)
    case event(Event)
    var id: String {
        switch self {
        case .visit(let v): return "v_\(v.id)"
        case .event(let e): return "e_\(e.id)"
        }
    }
    var date: Date {
        switch self {
        case .visit(let v): return v.date
        case .event(let e): return e.periodStart
        }
    }
}

// MARK: - Экран календаря для тренера (посещения + события, один календарь и общий список)

struct ClientVisitsManageView: View {
    let trainee: Profile
    let coachProfileId: String
    let visitService: VisitServiceProtocol
    let eventService: EventServiceProtocol
    let membershipService: MembershipServiceProtocol
    var initialVisits: [Visit]? = nil
    var initialMemberships: [Membership]? = nil

    @State private var visits: [Visit] = []
    @State private var events: [Event] = []
    @State private var memberships: [Membership] = []
    @State private var selectedMonth = Date()
    @State private var isLoading = true
    @State private var pendingOneOffDate: Date?
    @State private var pendingEventDate: Date?
    @State private var eventToEdit: Event?
    @State private var visitToCancel: Visit?
    @State private var showCancelConfirmation = false
    @State private var isCancelling = false
    @State private var errorMessage: String?
    @State private var dayDetailItem: DayDetailItem?

    private let calendar = Calendar.current

    private var activeMemberships: [Membership] {
        memberships.filter { $0.isActive }
    }

    private var visitsInSelectedMonth: [Visit] {
        guard let interval = calendar.dateInterval(of: .month, for: selectedMonth) else { return [] }
        return visits.filter { $0.date >= interval.start && $0.date < interval.end }
            .sorted { $0.date > $1.date }
    }

    private var eventsInSelectedMonth: [Event] {
        guard let interval = calendar.dateInterval(of: .month, for: selectedMonth) else { return [] }
        return events.filter { event in
            let start = calendar.startOfDay(for: event.periodStart)
            let end = calendar.startOfDay(for: event.periodEnd)
            return start < interval.end && end >= interval.start
        }
        .sorted { $0.periodStart > $1.periodStart }
    }

    /// Объединённый список посещений и событий за выбранный месяц, по убыванию даты.
    private var calendarItemsInSelectedMonth: [CalendarListItem] {
        (visitsInSelectedMonth.map { CalendarListItem.visit($0) } + eventsInSelectedMonth.map { CalendarListItem.event($0) })
            .sorted { $0.date > $1.date }
    }

    private var onCancelDayTap: ((Date) -> Void) {
        { date in
            // Если на день уже есть активное посещение — предложить отменить.
            let sameDay = visits
                .filter { calendar.isDate($0.date, inSameDayAs: date) }
                .filter { $0.status != .cancelled }
                .sorted { $0.date > $1.date }
            if let v = sameDay.first {
                visitToCancel = v
                showCancelConfirmation = true
            }
        }
    }

    private func cancelVisitAfterConfirmation(_ v: Visit) {
        Task {
            await MainActor.run { isCancelling = true }
            do {
                try await visitService.cancelVisit(v)
                await load()
            } catch {
                if let msg = AppErrors.userMessageIfNeeded(for: error) { await MainActor.run { errorMessage = msg } }
            }
            await MainActor.run { isCancelling = false }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        VisitsCalendarView(
                selectedMonth: $selectedMonth,
                visits: visits,
                events: events,
                onDayTapped: onCancelDayTap,
                addVisitMemberships: activeMemberships,
                onAddOneOffVisit: { date in pendingOneOffDate = date },
                onAddVisitWithMembership: { date, m in
                    Task {
                        do {
                            let startOfDay = Calendar.current.startOfDay(for: date)
                            let visit = try await visitService.createVisit(coachProfileId: coachProfileId, traineeProfileId: trainee.id, date: startOfDay, paymentStatus: nil, membershipId: nil, idempotencyKey: UUID().uuidString)
                            try await visitService.markVisitPaidWithMembership(visit, membershipId: m.id)
                            await load()
                            await MainActor.run { AppDesign.triggerSuccessHaptic() }
                        } catch {
                            if let msg = AppErrors.userMessageIfNeeded(for: error) { await MainActor.run { errorMessage = msg } }
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
                        await load()
                    }
                },
                dayVisitActions: (
                    payableMemberships: activeMemberships,
                    onMarkAsPaid: { visit in
                        Task {
                            do {
                                try await visitService.markVisitPaid(visit)
                                await load()
                            } catch {
                                if let msg = AppErrors.userMessageIfNeeded(for: error) { await MainActor.run { errorMessage = msg } }
                            }
                        }
                    },
                    onPayWithMembership: { visit, membership in
                        Task {
                            do {
                                try await visitService.markVisitPaidWithMembership(visit, membershipId: membership.id)
                                await load()
                            } catch {
                                if let msg = AppErrors.userMessageIfNeeded(for: error) { await MainActor.run { errorMessage = msg } }
                            }
                        }
                    },
                    onCancelVisit: { v in
                        visitToCancel = v
                        showCancelConfirmation = true
                    }
                ),
                onShowDayDetail: { dayDetailItem = DayDetailItem(date: $0) },
                cardTitle: "Календарь"
            )
            CalendarUnifiedListBlockView(
                items: calendarItemsInSelectedMonth,
                visits: visitsInSelectedMonth,
                payableMemberships: memberships.filter { $0.isActive },
                visitService: visitService,
                onPayWithMembership: { visit, membership in
                    Task {
                        do {
                            try await visitService.markVisitPaidWithMembership(visit, membershipId: membership.id)
                            await load()
                        } catch {
                            if let msg = AppErrors.userMessageIfNeeded(for: error) { await MainActor.run { errorMessage = msg } }
                        }
                    }
                },
                onMarkAsPaid: { visit in
                    Task {
                        do {
                            try await visitService.markVisitPaid(visit)
                            await load()
                        } catch {
                            if let msg = AppErrors.userMessageIfNeeded(for: error) { await MainActor.run { errorMessage = msg } }
                        }
                    }
                },
                onCancelVisit: { v in
                    visitToCancel = v
                    showCancelConfirmation = true
                },
                onEventTap: { eventToEdit = $0 },
                onCancelEvent: { ev in
                    Task {
                        var updated = ev
                        updated.isCancelled = true
                        try? await eventService.updateEvent(updated)
                        await load()
                    }
                },
                onShowDayDetail: nil
            )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                mainContent
            }
            .padding(.top, AppDesign.blockSpacing)
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .background(AppColors.systemGroupedBackground)
        .overlay {
            if isLoading {
                LoadingOverlayView(message: "Загружаю")
            }
        }
        .navigationTitle("Календарь")
        .navigationBarTitleDisplayMode(.inline)
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
                payableMemberships: memberships.filter { $0.isActive },
                onPayWithMembership: { visit, membership in
                    Task {
                        do {
                            try await visitService.markVisitPaidWithMembership(visit, membershipId: membership.id)
                            await load()
                        } catch {
                            if let msg = AppErrors.userMessageIfNeeded(for: error) { await MainActor.run { errorMessage = msg } }
                        }
                    }
                },
                onMarkAsPaid: { visit in
                    Task {
                        do {
                            try await visitService.markVisitPaid(visit)
                            await load()
                        } catch {
                            if let msg = AppErrors.userMessageIfNeeded(for: error) { await MainActor.run { errorMessage = msg } }
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
                        await load()
                    }
                },
                onDismiss: { dayDetailItem = nil },
                onAddOneOffVisit: { date in
                    dayDetailItem = nil
                    pendingOneOffDate = date
                },
                addVisitMemberships: memberships.filter { $0.isActive },
                onAddVisitWithMembership: { date, m in
                    dayDetailItem = nil
                    Task {
                        do {
                            let startOfDay = Calendar.current.startOfDay(for: date)
                            let visit = try await visitService.createVisit(coachProfileId: coachProfileId, traineeProfileId: trainee.id, date: startOfDay, paymentStatus: nil, membershipId: nil, idempotencyKey: UUID().uuidString)
                            try await visitService.markVisitPaidWithMembership(visit, membershipId: m.id)
                            await load()
                            await MainActor.run { AppDesign.triggerSuccessHaptic() }
                        } catch {
                            if let msg = AppErrors.userMessageIfNeeded(for: error) { await MainActor.run { errorMessage = msg } }
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
                    onAdded: { Task { await load(); await MainActor.run { pendingOneOffDate = nil } } },
                    onCancel: { pendingOneOffDate = nil }
                )
                .mainSheetPresentation(.half)
            }
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
            if isCancelling {
                LoadingOverlayView(message: "Обновляю…")
            }
        }
        .allowsHitTesting(!isCancelling)
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
                coachProfileId: coachProfileId,
                traineeProfileId: trainee.id,
                eventService: eventService,
                onSaved: { Task { await load(); await MainActor.run { eventToEdit = nil } } },
                onError: { msg in Task { await MainActor.run { errorMessage = msg } } },
                onCancel: { eventToEdit = nil }
            )
            .mainSheetPresentation(.half)
        }
        .task {
            await load()
        }
        .refreshable { await load() }
    }

    private func load() async {
        await MainActor.run { isLoading = true }
        do {
            async let listTask = visitService.fetchVisits(
                coachProfileId: coachProfileId,
                traineeProfileId: trainee.id
            )
            async let membershipsTask = membershipService.fetchMemberships(
                coachProfileId: coachProfileId,
                traineeProfileId: trainee.id
            )
            async let eventsTask = eventService.fetchEvents(
                coachProfileId: coachProfileId,
                traineeProfileId: trainee.id
            )
            let (list, allMemberships, allEvents) = try await (listTask, membershipsTask, eventsTask)
            await MainActor.run {
                visits = list.sorted { $0.date > $1.date }
                memberships = allMemberships
                events = allEvents
            }
        } catch {
            await MainActor.run {
                if let msg = AppErrors.userMessageIfNeeded(for: error) {
                    visits = []
                    memberships = []
                    events = []
                    errorMessage = msg
                }
            }
        }
        await MainActor.run { isLoading = false }
    }
}

// MARK: - Экран абонементов (новый вариант: переключатель Активные/Завершённые, карточки)

struct ClientMembershipsNewView: View {
    let trainee: Profile
    let coachProfileId: String
    let membershipService: MembershipServiceProtocol
    let visitService: VisitServiceProtocol
    let eventService: EventServiceProtocol
    var initialMemberships: [Membership]? = nil

    @State private var memberships: [Membership] = []
    @State private var isLoading = true
    @State private var showArchived = false
    @State private var isAddingVisitForMembershipId: String? = nil
    @State private var addVisitDateSheetMembership: Membership? = nil
    @State private var errorMessage: String?
    @State private var isCreatingMembership = false
    @State private var loadingMembershipId: String? = nil
    @State private var allVisits: [Visit] = []
    @State private var showVisitsForMembership: Membership? = nil
    @State private var createKind: MembershipKind = .byVisits
    @State private var createTotalSessionsCount: Int = 10
    @State private var createStartDate: Date = Date()
    @State private var createDurationDays: Int = 30
    @State private var createPriceText: String = ""
    @State private var showCreateStartDatePicker = false

    private var activeList: [Membership] {
        memberships.filter { $0.isActive }
    }
    private var endingSoonList: [Membership] {
        activeList.filter { $0.isEndingSoon }
    }
    private var regularActiveList: [Membership] {
        activeList.filter { !$0.isEndingSoon }
    }
    private var finishedList: [Membership] {
        memberships.filter { !$0.isActive }
    }
    private var createPriceRub: Int? {
        let t = createPriceText.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : Int(t)
    }
    private var createEndDate: Date {
        Calendar.current.date(byAdding: .day, value: createDurationDays, to: Calendar.current.startOfDay(for: createStartDate)) ?? createStartDate
    }
    private let minSessions = 1
    private let maxSessions = 999
    private let minDays = 1
    private let maxDays = 365

    var body: some View {
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
                    archivedContent
                } else {
                    activeContent
                }
            }
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .background(AppColors.systemGroupedBackground)
        .overlay {
            if isLoading {
                LoadingOverlayView(message: "Загружаю")
            } else if isAddingVisitForMembershipId != nil {
                LoadingOverlayView(message: "Добавляю посещение…")
            }
        }
        .allowsHitTesting(isAddingVisitForMembershipId == nil)
        .navigationTitle("Абонементы")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $showVisitsForMembership) { membership in
            let visits = allVisits.filter { $0.membershipId == membership.id }.sorted { $0.date > $1.date }
            MembershipVisitsSheet(
                membership: membership,
                visits: visits,
                initialMonth: MembershipVisitsSheet.initialMonthForVisits(visits),
                onDismiss: { showVisitsForMembership = nil }
            )
        }
        .sheet(isPresented: $showCreateStartDatePicker) {
            MainSheet(
                title: "Дата начала",
                onBack: { showCreateStartDatePicker = false },
                trailing: {
                    Button("Готово") { showCreateStartDatePicker = false }
                        .fontWeight(.regular)
                },
                content: {
                    DatePicker("", selection: $createStartDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .environment(\.locale, .ru)
                        .padding()
                }
            )
            .mainSheetPresentation(.calendar)
        }
        .sheet(item: $addVisitDateSheetMembership) { membership in
            AddVisitDateSheet(
                membership: membership,
                onSelect: { date in
                    addVisitWithMembership(on: date, membership: membership)
                },
                onCancel: { addVisitDateSheetMembership = nil }
            )
            .mainSheetPresentation(.detents([.height(420)]))
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
        .task {
            if let initial = initialMemberships, !initial.isEmpty {
                await MainActor.run {
                    memberships = initial.sorted { $0.createdAt > $1.createdAt }
                    isLoading = false
                }
            }
            await load()
        }
        .refreshable { await load() }
    }

    @ViewBuilder
    private var activeContent: some View {
        if activeList.isEmpty {
            VStack(spacing: AppDesign.blockSpacing) {
                ContentUnavailableView(
                    "Нет активных абонементов",
                    image: "tag",
                    description: Text("Создайте первый абонемент, чтобы вести посещения и заранее видеть, когда нужно продление.")
                )
                .padding(.top, 20)

                createMembershipSection
            }
        } else {
            VStack(spacing: AppDesign.blockSpacing) {
                if !endingSoonList.isEmpty {
                    SettingsCard(title: "Скоро заканчиваются") {
                        VStack(spacing: 10) {
                            ForEach(endingSoonList) { m in
                                membershipCard(m)
                            }
                        }
                    }
                }

                if !regularActiveList.isEmpty {
                    SettingsCard(title: "Активные") {
                        VStack(spacing: 10) {
                            ForEach(regularActiveList) { m in
                                membershipCard(m)
                            }
                        }
                    }
                }
                createMembershipSection
            }
        }
    }

    @ViewBuilder
    private func membershipCard(_ m: Membership) -> some View {
        MembershipCardNewView(
            membership: m,
            isActive: true,
            loadingMembershipId: loadingMembershipId,
            onAddVisit: { addVisitDateSheetMembership = m },
            onFreeze: { days in
                Task {
                    await MainActor.run { loadingMembershipId = m.id }
                    do {
                        var updated = m
                        updated.freezeDays += days
                        try await membershipService.updateMembership(updated)
                        await load()
                        let actualFreezeDays = await MainActor.run {
                            memberships.first(where: { $0.id == m.id })?.freezeDays ?? m.freezeDays
                        }
                        if actualFreezeDays <= m.freezeDays {
                            await MainActor.run {
                                errorMessage = "Заморозка пока не применена на сервере. Проверьте backend PATCH memberships"
                                ToastCenter.shared.warning("Заморозка пока не применена на сервере")
                            }
                        }
                        await MainActor.run {
                            AppDesign.triggerSuccessHaptic()
                            ToastCenter.shared.success("Абонемент заморожен")
                        }
                    } catch {
                        let msg = AppErrors.userMessageIfNeeded(for: error) ?? "Не удалось применить заморозку"
                        await MainActor.run {
                            errorMessage = msg
                            ToastCenter.shared.error(msg)
                        }
                    }
                    await MainActor.run { loadingMembershipId = nil }
                }
            },
            onUnfreeze: {
                Task {
                    await MainActor.run { loadingMembershipId = m.id }
                    do {
                        var updated = m
                        updated.freezeDays = 0
                        try await membershipService.updateMembership(updated)
                        await load()
                        let actualFreezeDays = await MainActor.run {
                            memberships.first(where: { $0.id == m.id })?.freezeDays ?? m.freezeDays
                        }
                        if actualFreezeDays != 0 {
                            await MainActor.run {
                                errorMessage = "Снятие заморозки пока не применено на сервере. Проверьте backend PATCH memberships"
                                ToastCenter.shared.warning("Снятие заморозки пока не применено на сервере")
                            }
                        }
                        await MainActor.run {
                            AppDesign.triggerSuccessHaptic()
                            ToastCenter.shared.success("Заморозка снята")
                        }
                    } catch {
                        let msg = AppErrors.userMessageIfNeeded(for: error) ?? "Не удалось снять заморозку"
                        await MainActor.run {
                            errorMessage = msg
                            ToastCenter.shared.error(msg)
                        }
                    }
                    await MainActor.run { loadingMembershipId = nil }
                }
            },
            onClose: {
                Task {
                    await MainActor.run { loadingMembershipId = m.id }
                    do {
                        var updated = m
                        updated.status = .finished
                        updated.closedManually = true
                        try await membershipService.updateMembership(updated)
                        await load()
                        await MainActor.run {
                            AppDesign.triggerSuccessHaptic()
                            ToastCenter.shared.success("Абонемент завершен")
                        }
                    } catch {
                        await MainActor.run {
                            ToastCenter.shared.error(from: error, fallback: "Не удалось завершить абонемент")
                            if let msg = AppErrors.userMessageIfNeeded(for: error) { errorMessage = msg }
                        }
                    }
                    await MainActor.run { loadingMembershipId = nil }
                }
            },
            onViewVisits: { showVisitsForMembership = m }
        )
    }

    private var createMembershipSection: some View {
        SettingsCard(title: "Создать абонемент") {
            VStack(spacing: 0) {
                HStack(spacing: AppDesign.rectangularBlockSpacing) {
                    createKindTile(kind: .byVisits, icon: "tag", title: "По посещению", description: "Фиксированное число занятий")
                    createKindTile(kind: .unlimited, icon: "calendar-default", title: "Безлимитный", description: "На период по датам")
                }

                if createKind == .byVisits {
                    FormSectionDivider()
                    FormRow(icon: "tag", title: "Количество") {
                        HStack(spacing: 20) {
                            Button { if createTotalSessionsCount > minSessions { createTotalSessionsCount -= 1 } } label: {
                                AppTablerIcon("minus-circle")
                                    .appTypography(.screenTitle)
                                    .foregroundStyle(createTotalSessionsCount <= minSessions ? AppColors.secondaryLabel : AppColors.accent)
                            }
                            .disabled(createTotalSessionsCount <= minSessions)
                            Text("\(createTotalSessionsCount)")
                                .appTypography(.screenTitle)
                                .monospacedDigit()
                                .frame(minWidth: 56, alignment: .center)
                            Button { if createTotalSessionsCount < maxSessions { createTotalSessionsCount += 1 } } label: {
                                AppTablerIcon("plus-circle")
                                    .appTypography(.screenTitle)
                                    .foregroundStyle(createTotalSessionsCount >= maxSessions ? AppColors.secondaryLabel : AppColors.accent)
                            }
                            .disabled(createTotalSessionsCount >= maxSessions)
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    FormSectionDivider()
                    FormRowDateSelection(
                        title: "Дата начала",
                        selection: Binding<Date?>(
                            get: { createStartDate },
                            set: { if let value = $0 { createStartDate = value } }
                        ),
                        allowsClear: false,
                        onTap: { showCreateStartDatePicker = true }
                    )
                    FormSectionDivider()
                    FormRow(icon: "tag", title: "Срок (дней)") {
                        HStack(spacing: 20) {
                            Button { if createDurationDays > minDays { createDurationDays -= 1 } } label: {
                                AppTablerIcon("minus-circle")
                                    .appTypography(.screenTitle)
                                    .foregroundStyle(createDurationDays <= minDays ? AppColors.secondaryLabel : AppColors.accent)
                            }
                            .disabled(createDurationDays <= minDays)
                            Text("\(createDurationDays)")
                                .appTypography(.screenTitle)
                                .monospacedDigit()
                                .frame(minWidth: 56, alignment: .center)
                            Button { if createDurationDays < maxDays { createDurationDays += 1 } } label: {
                                AppTablerIcon("plus-circle")
                                    .appTypography(.screenTitle)
                                    .foregroundStyle(createDurationDays >= maxDays ? AppColors.secondaryLabel : AppColors.accent)
                            }
                            .disabled(createDurationDays >= maxDays)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    Text("Абонемент действует до \(createEndDate.formattedRuMedium)")
                        .appTypography(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                }

                FormSectionDivider()
                FormRow(icon: "wallet-default", title: "Стоимость (₽)") {
                    TextField("5000", text: $createPriceText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .formInputStyle()
                }

                MainActionButton(
                    title: "Создать абонемент",
                    isLoading: isCreatingMembership,
                    isDisabled: false,
                    action: { Task { await createMembershipInline() } }
                )
                .padding(.top, 12)
            }
        }
    }

    @ViewBuilder
    private var archivedContent: some View {
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
                    let visitsForMembership = allVisits.filter { $0.membershipId == m.id }
                    let lastVisitDate = visitsForMembership.map(\.date).max()
                    MembershipFinishedTileView(
                        membership: m,
                        completionDate: lastVisitDate ?? m.effectiveEndDate,
                        onViewVisits: { showVisitsForMembership = m }
                    )
                }
            }
            .padding(.horizontal, AppDesign.cardPadding)
        }
    }

    private func createKindTile(
        kind: MembershipKind,
        icon: String,
        title: String,
        description: String
    ) -> some View {
        let isSelected = createKind == kind
        let tint = kind == .byVisits ? AppColors.logoTeal : AppColors.logoViolet
        return Button {
            createKind = kind
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                AppTablerIcon(icon)
                    .appTypography(.screenTitle)
                    .foregroundStyle(isSelected ? tint : AppColors.accent)
                Text(title)
                    .appTypography(.bodyEmphasis)
                    .foregroundStyle(.primary)
                Text(description)
                    .appTypography(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AppDesign.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.secondarySystemGroupedBackground)
            .overlay(
                RoundedRectangle(cornerRadius: AppDesign.cornerRadius)
                    .stroke(
                        isSelected ? tint.opacity(0.95) : AppColors.separator.opacity(0.35),
                        lineWidth: isSelected ? 1.2 : 0.8
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func createMembershipInline() async {
        await MainActor.run { isCreatingMembership = true }
        defer { Task { @MainActor in isCreatingMembership = false } }
        do {
            if createKind == .byVisits {
                _ = try await membershipService.createMembership(
                    coachProfileId: coachProfileId,
                    traineeProfileId: trainee.id,
                    kind: .byVisits,
                    totalSessions: createTotalSessionsCount,
                    startDate: nil,
                    endDate: nil,
                    priceRub: createPriceRub
                )
            } else {
                let start = Calendar.current.startOfDay(for: createStartDate)
                _ = try await membershipService.createMembership(
                    coachProfileId: coachProfileId,
                    traineeProfileId: trainee.id,
                    kind: .unlimited,
                    totalSessions: nil,
                    startDate: start,
                    endDate: createEndDate,
                    priceRub: createPriceRub
                )
            }
            await load()
            await MainActor.run {
                AppDesign.triggerSuccessHaptic()
                ToastCenter.shared.success("Абонемент создан")
            }
        } catch {
            await MainActor.run {
                ToastCenter.shared.error(from: error, fallback: "Не удалось создать абонемент")
                if let msg = AppErrors.userMessageIfNeeded(for: error) { errorMessage = msg }
            }
        }
    }

    private func addVisitWithMembership(on date: Date, membership: Membership) {
        guard isAddingVisitForMembershipId == nil else { return }
        let startOfDay = Calendar.current.startOfDay(for: date)
        isAddingVisitForMembershipId = membership.id
        Task {
            do {
                let visit = try await visitService.createVisit(
                    coachProfileId: coachProfileId,
                    traineeProfileId: trainee.id,
                    date: startOfDay,
                    paymentStatus: nil,
                    membershipId: nil,
                    idempotencyKey: UUID().uuidString
                )
                try await visitService.markVisitDoneWithMembership(visit, membershipId: membership.id)
                await load()
                await MainActor.run {
                    AppDesign.triggerSuccessHaptic()
                    isAddingVisitForMembershipId = nil
                    addVisitDateSheetMembership = nil
                }
            } catch {
                await MainActor.run {
                    if let msg = AppErrors.userMessageIfNeeded(for: error) { errorMessage = msg }
                    isAddingVisitForMembershipId = nil
                }
            }
        }
    }

    private func load() async {
        await MainActor.run { isLoading = true }
        do {
            async let membershipsTask = membershipService.fetchMemberships(
                coachProfileId: coachProfileId,
                traineeProfileId: trainee.id
            )
            async let visitsTask = visitService.fetchVisits(
                coachProfileId: coachProfileId,
                traineeProfileId: trainee.id
            )
            let (list, visits) = try await (membershipsTask, visitsTask)
            await MainActor.run {
                memberships = list.sorted { $0.createdAt > $1.createdAt }
                allVisits = visits
            }
        } catch {
            if let msg = AppErrors.userMessageIfNeeded(for: error) { await MainActor.run { errorMessage = msg } }
        }
        await MainActor.run { isLoading = false }
    }
}

// MARK: - Шит выбора даты для добавления посещения по абонементу

private struct AddVisitDateSheet: View {
    let membership: Membership
    let onSelect: (Date) -> Void
    let onCancel: () -> Void
    @State private var selectedDate = Date()
    @State private var showDatePicker = false

    var body: some View {
        MainSheet(
            title: "Добавить посещение",
            onBack: onCancel,
            trailing: {
                Button("Добавить") {
                    onSelect(selectedDate)
                }
                .appTypography(.body)
                .fontWeight(.regular)
                .foregroundStyle(.primary)
            },
            content: {
                VStack(spacing: 0) {
                    SettingsCard(title: "Дата") {
                        FormRowDateSelection(
                            title: "Дата посещения",
                            selection: Binding<Date?>(
                                get: { selectedDate },
                                set: { if let value = $0 { selectedDate = value } }
                            ),
                            allowsClear: false,
                            onTap: { showDatePicker = true }
                        )
                    }
                    Spacer(minLength: 0)
                }
                .background(AppColors.systemGroupedBackground)
            }
        )
        .sheet(isPresented: $showDatePicker) {
            MainSheet(
                title: "Дата посещения",
                onBack: { showDatePicker = false },
                trailing: {
                    Button("Готово") { showDatePicker = false }
                        .fontWeight(.regular)
                },
                content: {
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .environment(\.locale, .ru)
                        .padding()
                }
            )
            .mainSheetPresentation(.calendar)
        }
    }
}

// MARK: - Sheet: календарь и список посещений по абонементу

struct MembershipVisitsSheet: View {
    let membership: Membership
    let visits: [Visit]
    /// Месяц при открытии: месяц первого посещения или текущий.
    let initialMonth: Date
    let onDismiss: () -> Void

    @State private var selectedMonth: Date

    private let calendar = Calendar.current

    init(membership: Membership, visits: [Visit], initialMonth: Date, onDismiss: @escaping () -> Void) {
        self.membership = membership
        self.visits = visits
        self.initialMonth = initialMonth
        self.onDismiss = onDismiss
        self._selectedMonth = State(initialValue: initialMonth)
    }

    /// Месяц первого посещения (начало месяца) или текущая дата.
    static func initialMonthForVisits(_ visits: [Visit]) -> Date {
        let cal = Calendar.current
        let first = visits.filter { $0.status != .cancelled }.min(by: { $0.date < $1.date })?.date
        guard let date = first else { return Date() }
        return cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
    }

    private var title: String {
        if let code = membership.displayCode, !code.isEmpty {
            return "Посещения по Аб. №\(code)"
        }
        return "Посещения по Аб"
    }

    private var visitsInSelectedMonth: [Visit] {
        guard let interval = calendar.dateInterval(of: .month, for: selectedMonth) else { return [] }
        return visits.filter { visit in
            visit.status != .cancelled && interval.contains(visit.date)
        }.sorted { $0.date > $1.date }
    }

    private var monthTitle: String { selectedMonth.formattedRuMonthYear }

    var body: some View {
        NavigationStack {
            Group {
                if visits.isEmpty {
                    ContentUnavailableView(
                        "Нет посещений",
                        image: "tabler-outline-calendar-event",
                        description: Text("По этому абонементу не было посещений.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            VisitsCalendarView(
                                selectedMonth: $selectedMonth,
                                visits: visits,
                                cardTitle: "Посещаемость"
                            )
                            .padding(.horizontal, AppDesign.cardPadding)
                            .padding(.top, AppDesign.blockSpacing)

                            VStack(alignment: .leading, spacing: AppDesign.blockSpacing) {
                                Text("Посещения за \(monthTitle)")
                                    .appTypography(.bodyEmphasis)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 4)
                                    .padding(.top, AppDesign.sectionSpacing)

                                if visitsInSelectedMonth.isEmpty {
                                    Text("В этом месяце нет посещений")
                                        .appTypography(.secondary)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 16)
                                } else {
                                    VStack(spacing: 0) {
                                        ForEach(visitsInSelectedMonth) { visit in
                                            CoachVisitRow(visit: visit)
                                            if visit.id != visitsInSelectedMonth.last?.id {
                                                Divider()
                                                    .padding(.leading, AppDesign.listDividerLeading)
                                            }
                                        }
                                    }
                                    .padding(AppDesign.cardPadding)
                                    .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
                                }
                            }
                            .padding(.horizontal, AppDesign.cardPadding)
                            .padding(.bottom, AppDesign.sectionSpacing)
                        }
                    }
                }
            }
            .background(AppColors.systemGroupedBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Вспомогательные элементы для экранов

private struct IdentifiableMembership: Identifiable {
    let membership: Membership
    var id: String { membership.id }
}

private struct AddVisitWithMembershipWrapper: Identifiable {
    let date: Date
    let membership: Membership
    var id: String { "\(membership.id)_\(date.timeIntervalSince1970)" }
}

private struct DayDetailItem: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}

private struct CoachVisitRow: View {
    let visit: Visit
    var payableMemberships: [Membership] = []
    var onPayWithMembership: ((Membership) -> Void)?
    var onMarkAsPaid: (() -> Void)?
    var onCancel: (() -> Void)?
    var onShowDayDetail: (() -> Void)? = nil

    private var dateText: String { visit.date.formattedRuList }

    private var statusText: String {
        switch visit.status {
        case .planned: return "Запланировано"
        case .done: return ""
        case .cancelled: return ""
        case .noShow: return "Не пришёл"
        }
    }

    private var paymentText: String? {
        if visit.status == .cancelled { return "Посещение отменено" }
        switch visit.paymentStatus {
        case .unpaid: return "Не оплачено"
        case .paid:
            if let code = visit.membershipDisplayCode, !code.isEmpty {
                return "по Аб. №\(code)"
            }
            return "Оплачено"
        case .debt: return "Долг"
        }
    }

    private var paymentColor: Color {
        if visit.status == .cancelled {
            return .red
        }
        switch visit.paymentStatus {
        case .paid: return .green
        case .debt: return AppColors.visitsOneTimeDebt
        case .unpaid: return .secondary
        }
    }

    private var isDebt: Bool { visit.paymentStatus == .debt }
    private var canShowDebtActions: Bool {
        isDebt && (onMarkAsPaid != nil || (onPayWithMembership != nil && !payableMemberships.isEmpty))
    }
    private var canCancel: Bool { onCancel != nil && visit.status != .cancelled }
    private var hasActions: Bool {
        visit.status != .cancelled && (canShowDebtActions || canCancel || onShowDayDetail != nil)
    }

    var body: some View {
        ListActionRow(
            verticalPadding: 8,
            horizontalPadding: AppDesign.cardPadding,
            cornerRadius: 0,
            isInteractive: false
        ) {
            HStack(spacing: 12) {
                AppTablerIcon("calendar-default")
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .center)
                VStack(alignment: .leading, spacing: 2) {
                    Text(dateText)
                        .appTypography(.secondary)
                        .foregroundStyle(.primary)
                    if !statusText.isEmpty {
                        Text(statusText)
                            .appTypography(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 32)
            }
        } trailing: {
            HStack(spacing: 6) {
                if let paymentText, !paymentText.isEmpty {
                    Text(paymentText)
                        .appTypography(.caption)
                        .foregroundStyle(paymentColor)
                }
                if hasActions {
                    TiniActionButton(
                        color: paymentColor,
                        font: .title3,
                        minWidth: 40,
                        minHeight: 40,
                        style: .pressable
                    ) {
                        if canCancel, let onCancel {
                            CancelMenuAction(action: onCancel, title: "Отменить посещение")
                        }
                        if isDebt, let onMarkAsPaid {
                            Button { onMarkAsPaid() } label: {
                                Label("Пометить как оплачено", appIcon: "check-tick-circle")
                            }
                        }
                        if isDebt, let onPay = onPayWithMembership, !payableMemberships.isEmpty {
                            ForEach(payableMemberships) { m in
                                Button {
                                    onPay(m)
                                } label: {
                                    Label(
                                        m.displayCode.map { "Списать с аб. №\($0)" } ?? (m.kind == .byVisits ? "Списать с аб. (\(m.remainingSessions) занятий)" : "Списать с аб. (до \(m.effectiveEndDate?.formattedRuShort ?? ""))"),
                                        appIcon: "tag"
                                    )
                                }
                            }
                        }
                        if let onShowDayDetail {
                            Button { onShowDayDetail() } label: {
                                Label("За день", appIcon: "sidebar-menu")
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Добавить / редактировать событие

struct AddEditEventSheet: View {
    enum Mode {
        case create(initialDate: Date)
        case edit(Event)
    }
    let mode: Mode
    let coachProfileId: String
    let traineeProfileId: String
    let eventService: EventServiceProtocol
    let onSaved: () -> Void
    let onError: (String) -> Void
    let onCancel: () -> Void

    @State private var title: String = ""
    @State private var date: Date = Date()
    @State private var modeSelection: EventMode = .date
    @State private var periodStart: Date = Date()
    @State private var periodEnd: Date = Date()
    @State private var periodType: EventType = .vacation
    @State private var freezeMembership = false
    @State private var eventDescription: String = ""
    @State private var remind: Bool = false
    @State private var selectedEventType: EventType = .general
    @State private var selectedColorHex: String?
    @State private var isSaving = false
    @State private var showDatePicker = false

    private var isEdit: Bool { if case .edit = mode { return true }; return false }
    private var navigationTitle: String { isEdit ? "Редактировать событие" : "Новое событие" }

    init(
        mode: Mode,
        coachProfileId: String,
        traineeProfileId: String,
        eventService: EventServiceProtocol,
        onSaved: @escaping () -> Void,
        onError: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.mode = mode
        self.coachProfileId = coachProfileId
        self.traineeProfileId = traineeProfileId
        self.eventService = eventService
        self.onSaved = onSaved
        self.onError = onError
        self.onCancel = onCancel
        switch mode {
        case .create(let initialDate):
            _date = State(initialValue: initialDate)
            _periodStart = State(initialValue: initialDate)
            _periodEnd = State(initialValue: initialDate)
            _selectedColorHex = State(initialValue: EventColor.defaultHex(for: .general))
        case .edit(let event):
            _title = State(initialValue: event.title)
            _date = State(initialValue: event.date)
            _modeSelection = State(initialValue: event.mode)
            _periodStart = State(initialValue: event.periodStart)
            _periodEnd = State(initialValue: event.periodEnd)
            _periodType = State(initialValue: (event.eventType == .vacation || event.eventType == .sick) ? event.eventType : .vacation)
            _freezeMembership = State(initialValue: event.freezeMembership)
            _eventDescription = State(initialValue: event.eventDescription ?? "")
            _remind = State(initialValue: event.remind)
            _selectedEventType = State(initialValue: (event.eventType == .vacation || event.eventType == .sick) ? .general : event.eventType)
            _selectedColorHex = State(initialValue: event.colorHex ?? EventColor.defaultHex(for: event.eventType))
        }
    }

    var body: some View {
        MainSheet(
            title: navigationTitle,
            onBack: onCancel,
            trailing: {
                Button(isSaving ? "Сохранение…" : (isEdit ? "Сохранить" : "Добавить")) { save() }
                    .disabled(isSaving || !isValidTitle)
                    .foregroundStyle(.primary)
            },
            content: {
                ScrollView {
                    VStack(spacing: 0) {
                        SettingsCard(title: "Основное") {
                            VStack(spacing: 0) {
                                Picker("Режим", selection: $modeSelection) {
                                    Text("Дата").tag(EventMode.date)
                                    Text("Период").tag(EventMode.period)
                                }
                                .pickerStyle(.segmented)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                FormSectionDivider()
                                FormRowTextField(icon: "pencil-edit", title: "Название", placeholder: "Сдать анализы, взвешивание", text: $title, textContentType: .none, autocapitalization: .sentences)
                                FormSectionDivider()
                                if modeSelection == .date {
                                    FormRowDateSelection(
                                        title: "Дата события",
                                        selection: Binding<Date?>(
                                            get: { date },
                                            set: { if let value = $0 { date = value } }
                                        ),
                                        allowsClear: false,
                                        onTap: { showDatePicker = true }
                                    )
                                } else {
                                    FormRowDateSelection(
                                        title: "Начало периода",
                                        selection: Binding<Date?>(
                                            get: { periodStart },
                                            set: { if let value = $0 { periodStart = value } }
                                        ),
                                        allowsClear: false,
                                        onTap: { showDatePicker = true }
                                    )
                                    FormSectionDivider()
                                    FormRowDateSelection(
                                        title: "Конец периода",
                                        selection: Binding<Date?>(
                                            get: { periodEnd },
                                            set: { if let value = $0 { periodEnd = value } }
                                        ),
                                        allowsClear: false,
                                        onTap: { showDatePicker = true }
                                    )
                                }
                            }
                        }

                        SettingsCard(title: "Описание") {
                            FormRow(icon: "file-default", title: "Описание") {
                                TextField("Необязательно", text: $eventDescription, axis: .vertical)
                                    .textFieldStyle(.plain)
                                    .lineLimit(2...5)
                                    .textInputAutocapitalization(.sentences)
                                    .multilineTextAlignment(.trailing)
                                    .formInputStyle()
                            }
                        }

                        SettingsCard(title: "Тип события") {
                            if modeSelection == .period {
                                Picker("Тип периода", selection: $periodType) {
                                    Text(EventType.vacation.title).tag(EventType.vacation)
                                    Text(EventType.sick.title).tag(EventType.sick)
                                }
                                .pickerStyle(.segmented)
                            } else {
                                Picker("Тип события", selection: $selectedEventType) {
                                    ForEach(EventType.allCases.filter { $0 != .vacation && $0 != .sick }, id: \.rawValue) { type in
                                        Text(type.title).tag(type)
                                    }
                                }
                                .pickerStyle(.menu)
                                .onChange(of: selectedEventType) { _, newValue in
                                    selectedColorHex = EventColor.defaultHex(for: newValue)
                                }
                            }
                        }

                        if modeSelection == .period {
                            SettingsCard(title: "Параметры периода") {
                                Toggle("Заморозка абонемента (если есть)", isOn: $freezeMembership)
                            }
                        } else {
                            SettingsCard(title: "Цвет в календаре") {
                                HStack(spacing: 8) {
                                    ForEach(EventColor.palette, id: \.hex) { pair in
                                        let isSelected = selectedColorHex == pair.hex
                                        Button {
                                            selectedColorHex = isSelected ? nil : pair.hex
                                        } label: {
                                            Circle()
                                                .fill(pair.color)
                                                .frame(width: 22, height: 22)
                                                .overlay {
                                                    if isSelected {
                                                        Circle()
                                                            .strokeBorder(Color.primary, lineWidth: 2)
                                                    }
                                                }
                                        }
                                        .buttonStyle(PressableButtonStyle())
                                    }
                                }
                                Text("Цвет по умолчанию зависит от типа события.")
                                    .appTypography(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 4)
                            }
                        }
                        SettingsCard(title: "Напомнить") {
                            Toggle("Напомнить о событии", isOn: $remind)
                                .disabled(true)
                            Text("Напоминания будут доступны в следующей версии.")
                                .appTypography(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, AppDesign.sectionSpacing)
                }
                .scrollDismissesKeyboard(.interactively)
                .background(AppColors.systemGroupedBackground)
                .sheet(isPresented: $showDatePicker) {
                    MainSheet(
                        title: modeSelection == .date ? "Дата события" : "Период события",
                        onBack: { showDatePicker = false },
                        trailing: {
                            Button("Готово") { showDatePicker = false }
                                .foregroundStyle(.primary)
                        },
                        content: {
                            VStack(spacing: 12) {
                                if modeSelection == .date {
                                    DatePicker("Дата", selection: $date, displayedComponents: .date)
                                        .datePickerStyle(.wheel)
                                        .labelsHidden()
                                } else {
                                    DatePicker("Начало", selection: $periodStart, displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                    DatePicker("Конец", selection: $periodEnd, in: periodStart..., displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                }
                            }
                            .padding()
                            .environment(\.locale, .ru)
                        }
                    )
                    .mainSheetPresentation(.detents([.height(320)]))
                }
            }
        )
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidTitle else { return }
        isSaving = true
        let desc = eventDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                let selectedType = modeSelection == .period ? periodType : selectedEventType
                let resolvedTitle = modeSelection == .period && trimmedTitle.isEmpty ? periodType.title : trimmedTitle
                let resolvedDate = modeSelection == .period ? periodStart : date
                switch mode {
                case .create:
                    _ = try await eventService.createEvent(
                        coachProfileId: coachProfileId,
                        traineeProfileId: traineeProfileId,
                        title: resolvedTitle,
                        date: resolvedDate,
                        mode: modeSelection,
                        periodStart: modeSelection == .period ? periodStart : nil,
                        periodEnd: modeSelection == .period ? periodEnd : nil,
                        eventDescription: desc.isEmpty ? nil : desc,
                        remind: remind,
                        colorHex: modeSelection == .period ? EventColor.defaultHex(for: selectedType) : selectedColorHex,
                        eventType: selectedType,
                        freezeMembership: modeSelection == .period ? freezeMembership : false,
                        idempotencyKey: UUID().uuidString
                    )
                case .edit(let event):
                    var updated = event
                    updated.title = resolvedTitle
                    updated.date = resolvedDate
                    updated.mode = modeSelection
                    updated.periodStart = modeSelection == .period ? periodStart : resolvedDate
                    updated.periodEnd = modeSelection == .period ? periodEnd : resolvedDate
                    updated.eventDescription = desc.isEmpty ? nil : desc
                    updated.remind = remind
                    updated.colorHex = modeSelection == .period ? EventColor.defaultHex(for: selectedType) : selectedColorHex
                    updated.eventType = selectedType
                    updated.freezeMembership = modeSelection == .period ? freezeMembership : false
                    try await eventService.updateEvent(updated)
                }
                await MainActor.run {
                    isSaving = false
                    AppDesign.triggerSuccessHaptic()
                    onSaved()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    if let msg = AppErrors.userMessageIfNeeded(for: error) { onError(msg) }
                }
            }
        }
    }

    private var isValidTitle: Bool {
        if modeSelection == .period { return true }
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Используется в MembershipCardNewView (Core/Components/MembershipCardViews.swift) и в старом списке абонементов.
struct FreezeMembershipSheet: View {
    let membership: Membership
    @Binding var days: Int
    let onApply: () -> Void
    let onCancel: () -> Void

    private let minDays = 1
    private let maxDays = 90

    var body: some View {
        MainSheet(
            title: "Заморозка",
            onBack: onCancel,
            trailing: {
                Button("Применить") { onApply() }
                    .fontWeight(.regular)
            },
            content: {
                SettingsCard(title: "Заморозить абонемент") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Окончание абонемента сдвинется на выбранное количество дней.")
                            .appTypography(.secondary)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 16) {
                            Button {
                                if days > minDays { days -= 1 }
                            } label: {
                                AppTablerIcon("minus-circle")
                                    .appTypography(.screenTitle)
                                    .foregroundStyle(days <= minDays ? AppColors.secondaryLabel : AppColors.accent)
                            }
                            .disabled(days <= minDays)
                            Text("\(days) \(days == 1 ? "день" : days < 5 ? "дня" : "дней")")
                                .font(.title2.monospacedDigit())
                                .frame(minWidth: 80, alignment: .center)
                            Button {
                                if days < maxDays { days += 1 }
                            } label: {
                                AppTablerIcon("plus-circle")
                                    .appTypography(.screenTitle)
                                    .foregroundStyle(days >= maxDays ? AppColors.secondaryLabel : AppColors.accent)
                            }
                            .disabled(days >= maxDays)
                        }
                    }
                }
                .padding(.horizontal, AppDesign.cardPadding)
            }
        )
    }
}

struct AddMembershipSheet: View {
    @Binding var isCreating: Bool
    let onCreate: (MembershipKind, Int?, Date?, Date?, Int?) -> Void
    let onCancel: () -> Void

    @State private var selectedKind: MembershipKind = .byVisits
    @State private var totalSessionsCount: Int = 10
    @State private var startDate: Date = Date()
    @State private var durationDays: Int = 30
    @State private var priceText: String = ""
    @State private var showStartDatePicker = false

    private var priceRub: Int? {
        let t = priceText.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : Int(t)
    }

    private var endDate: Date {
        Calendar.current.date(byAdding: .day, value: durationDays, to: Calendar.current.startOfDay(for: startDate)) ?? startDate
    }

    private let minSessions = 1
    private let maxSessions = 999
    private let minDays = 1
    private let maxDays = 365

    var body: some View {
        MainSheet(
            title: "Абонемент",
            onBack: onCancel,
            trailing: {
                Button("Создать") {
                    if selectedKind == .byVisits {
                        onCreate(.byVisits, totalSessionsCount, nil, nil, priceRub)
                    } else {
                        let start = Calendar.current.startOfDay(for: startDate)
                        onCreate(.unlimited, nil, start, endDate, priceRub)
                    }
                }
                .disabled(isCreating)
            },
            content: {
                Group {
                    if isCreating {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Создаю абонемент…")
                                .appTypography(.secondary)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.bottom, AppDesign.sectionSpacing)
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                SettingsCard(title: "Основное") {
                                    VStack(spacing: 12) {
                                        HStack(spacing: AppDesign.rectangularBlockSpacing) {
                                            membershipKindTile(
                                                kind: .byVisits,
                                                icon: "tag",
                                                title: "По посещению",
                                                description: "Фиксированное число занятий"
                                            )
                                            membershipKindTile(
                                                kind: .unlimited,
                                                icon: "calendar-default",
                                                title: "Безлимитный",
                                                description: "На период по датам"
                                            )
                                        }
                                    }
                                }

                                if selectedKind == .byVisits {
                                    SettingsCard(title: "Занятий в абонементе") {
                                        FormRow(icon: "tag", title: "Количество") {
                                            HStack(spacing: 20) {
                                                Button {
                                                    if totalSessionsCount > minSessions { totalSessionsCount -= 1 }
                                                } label: {
                                                    AppTablerIcon("minus-circle")
                                                        .appTypography(.screenTitle)
                                                        .foregroundStyle(totalSessionsCount <= minSessions ? AppColors.secondaryLabel : AppColors.accent)
                                                }
                                                .disabled(totalSessionsCount <= minSessions)
                                                Text("\(totalSessionsCount)")
                                                    .appTypography(.screenTitle)
                                                    .monospacedDigit()
                                                    .frame(minWidth: 56, alignment: .center)
                                                Button {
                                                    if totalSessionsCount < maxSessions { totalSessionsCount += 1 }
                                                } label: {
                                                    AppTablerIcon("plus-circle")
                                                        .appTypography(.screenTitle)
                                                        .foregroundStyle(totalSessionsCount >= maxSessions ? AppColors.secondaryLabel : AppColors.accent)
                                                }
                                                .disabled(totalSessionsCount >= maxSessions)
                                            }
                                            .frame(maxWidth: .infinity)
                                        }
                                    }
                                } else {
                                    SettingsCard(title: "Период действия") {
                                        VStack(spacing: 0) {
                                            FormRowDateSelection(
                                                title: "Дата начала",
                                                selection: Binding<Date?>(
                                                    get: { startDate },
                                                    set: { if let value = $0 { startDate = value } }
                                                ),
                                                allowsClear: false,
                                                onTap: { showStartDatePicker = true }
                                            )
                                            FormSectionDivider()
                                            FormRow(icon: "tag", title: "Срок (дней)") {
                                                HStack(spacing: 20) {
                                                    Button {
                                                        if durationDays > minDays { durationDays -= 1 }
                                                    } label: {
                                                        AppTablerIcon("minus-circle")
                                                            .appTypography(.screenTitle)
                                                            .foregroundStyle(durationDays <= minDays ? AppColors.secondaryLabel : AppColors.accent)
                                                    }
                                                    .disabled(durationDays <= minDays)
                                                    Text("\(durationDays)")
                                                        .appTypography(.screenTitle)
                                                        .monospacedDigit()
                                                        .frame(minWidth: 56, alignment: .center)
                                                    Button {
                                                        if durationDays < maxDays { durationDays += 1 }
                                                    } label: {
                                                        AppTablerIcon("plus-circle")
                                                            .appTypography(.screenTitle)
                                                            .foregroundStyle(durationDays >= maxDays ? AppColors.secondaryLabel : AppColors.accent)
                                                    }
                                                    .disabled(durationDays >= maxDays)
                                                }
                                                .frame(maxWidth: .infinity)
                                            }
                                            Text("Абонемент действует до \(endDate.formattedRuMedium)")
                                                .appTypography(.caption)
                                                .foregroundStyle(.secondary)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.top, 6)
                                        }
                                    }
                                }

                                SettingsCard(title: "Стоимость (₽, необязательно)") {
                                    FormRow(icon: "wallet-default", title: "Сумма") {
                                        TextField("5000", text: $priceText)
                                            .keyboardType(.numberPad)
                                            .textFieldStyle(.plain)
                                            .multilineTextAlignment(.trailing)
                                            .formInputStyle()
                                    }
                                }
                            }
                            .padding(.top, 8)
                            .padding(.bottom, AppDesign.sectionSpacing)
                        }
                    }
                }
                .background(AppColors.systemGroupedBackground)
            }
        )
        .sheet(isPresented: $showStartDatePicker) {
            MainSheet(
                title: "Дата начала",
                onBack: { showStartDatePicker = false },
                trailing: {
                    Button("Готово") { showStartDatePicker = false }
                        .fontWeight(.regular)
                },
                content: {
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .environment(\.locale, .ru)
                        .padding()
                }
            )
            .mainSheetPresentation(.calendar)
        }
    }

    private func membershipKindTile(
        kind: MembershipKind,
        icon: String,
        title: String,
        description: String
    ) -> some View {
        let isSelected = selectedKind == kind
        let tint = kind == .byVisits ? AppColors.logoTeal : AppColors.logoViolet
        return Button {
            selectedKind = kind
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                AppTablerIcon(icon)
                    .appTypography(.screenTitle)
                    .foregroundStyle(isSelected ? tint : AppColors.accent)
                Text(title)
                    .appTypography(.bodyEmphasis)
                    .foregroundStyle(.primary)
                Text(description)
                    .appTypography(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AppDesign.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.secondarySystemGroupedBackground)
            .overlay(
                RoundedRectangle(cornerRadius: AppDesign.cornerRadius)
                    .stroke(
                        isSelected ? tint.opacity(0.95) : AppColors.separator.opacity(0.35),
                        lineWidth: isSelected ? 1.2 : 0.8
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

