//
//  QuickAddVisitSheet.swift
//  TrainLog
//

import SwiftUI

/// Добавление посещения: разовое (оплачено/долг) или списать с абонемента. При открытии «на сегодня» без даты — переключатель Разово/С абонемента.
struct QuickAddVisitSheet: View {
    let traineeName: String
    let coachProfileId: String
    let traineeProfileId: String
    let visitService: VisitServiceProtocol
    let membershipService: MembershipServiceProtocol
    /// nil = «посещение сегодня» из списка (показать выбор: разово или с абонемента)
    var initialDate: Date? = nil
    var preselectedMembershipId: String? = nil
    let onAdded: () -> Void
    let onCancel: () -> Void

    /// Режим «быстрое добавление на сегодня»: есть выбор «разово» или «с абонемента».
    private var isQuickTodayMode: Bool { initialDate == nil }

    @State private var memberships: [Membership] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var oneOffPaid: Bool = true
    @State private var selectedDate: Date = Date()
    @State private var showDatePicker = false
    /// true = разово, false = списать с абонемента (только в quick today)
    @State private var useOneOff: Bool = true
    @State private var selectedMembershipId: String? = nil

    private var activeMemberships: [Membership] {
        memberships.filter { $0.isActive }.sorted { $0.createdAt > $1.createdAt }
    }

    private var dateString: String {
        let f = DateFormatter()
        f.locale = .ru
        f.dateStyle = .long
        return f.string(from: selectedDate)
    }

    private var navigationTitleText: String {
        Calendar.current.isDateInToday(selectedDate) ? "Посещение сегодня" : "Добавить посещение"
    }

    var body: some View {
        MainSheet(
            title: navigationTitleText,
            onBack: onCancel,
            trailing: {
                Button("Добавить") { submit() }
                    .fontWeight(.semibold)
                    .disabled(isSaving || !canSubmit)
            },
            content: {
                mainContent
                    .background(AppColors.systemGroupedBackground)
            }
        )
        .task { await load() }
        .overlay { savingOverlay }
        .allowsHitTesting(!isSaving)
        .onAppear {
            let d = initialDate ?? Date()
            selectedDate = Calendar.current.startOfDay(for: d)
        }
        .onChange(of: useOneOff) { _, newValue in
            if !newValue, let first = activeMemberships.first {
                selectedMembershipId = first.id
            }
        }
        .onChange(of: memberships.count) { _, _ in
            if isQuickTodayMode, !useOneOff, !activeMemberships.isEmpty, selectedMembershipId == nil {
                selectedMembershipId = activeMemberships.first?.id
            }
        }
        .sheet(isPresented: $showDatePicker) { datePickerSheet }
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
    private var savingOverlay: some View {
        if isSaving {
            LoadingOverlayView(message: "Сохранение…")
        }
    }

    private var datePickerSheet: some View {
        MainSheet(
            title: "Дата посещения",
            onBack: { showDatePicker = false },
            trailing: {
                Button {
                    showDatePicker = false
                } label: {
                    Text("Готово")
                        .fontWeight(.regular)
                }
            },
            content: {
                VStack(spacing: 0) {
                    DatePicker("Дата", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .padding()
                    Spacer()
                }
            }
        )
        .environment(\.locale, .ru)
        .mainSheetPresentation(.calendar)
    }

    @ViewBuilder
    private var mainContent: some View {
        ScrollView {
            scrollContent
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if isLoading {
                LoadingOverlayView(message: "Загружаю")
            }
        }
    }

    @ViewBuilder
    private var scrollContent: some View {
        VStack(spacing: 0) {
            headerBlock
            visitOptionsCard
        }
    }

    private var headerBlock: some View {
        VStack(spacing: 0) {
            ActionBlockRow(
                icon: "user-default",
                title: "Клиент",
                value: traineeName
            )
            Divider()
                .padding(.leading, 52)
            Button {
                showDatePicker = true
            } label: {
                ActionBlockRow(
                    icon: "calendar-default",
                    title: "Дата",
                    value: dateString
                )
            }
            .buttonStyle(PressableButtonStyle())
        }
        .actionBlockStyle()
    }

    private var canSubmit: Bool {
        if isQuickTodayMode, !useOneOff {
            return selectedMembershipId != nil
        }
        return true
    }

    private func submit() {
        if isQuickTodayMode, !useOneOff, let id = selectedMembershipId, let m = activeMemberships.first(where: { $0.id == id }) {
            addWithMembership(m)
        } else {
            addOneOff(paid: oneOffPaid)
        }
    }

    @ViewBuilder
    private var visitOptionsCard: some View {
        if isQuickTodayMode {
            SettingsCard(title: "Откуда списать?") {
                VStack(alignment: .leading, spacing: AppDesign.rowSpacing) {
                    Picker("", selection: $useOneOff) {
                        Text("Разово").tag(true)
                        Text("С абонемента").tag(false)
                    }
                    .pickerStyle(.segmented)
                    if useOneOff {
                        Toggle(oneOffPaid ? "Оплачено" : "В долг", isOn: $oneOffPaid)
                        if !oneOffPaid {
                            Text("Занятие будет помечено как долг. Позже можно списать с абонемента в календаре.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        if activeMemberships.isEmpty {
                            Text("Нет активных абонементов")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(activeMemberships) { m in
                                Button {
                                    selectedMembershipId = m.id
                                } label: {
                                    HStack(spacing: 12) {
                                        AppTablerIcon(selectedMembershipId == m.id ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selectedMembershipId == m.id ? Color.accentColor : .secondary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(m.displayCode.map { "Абонемент №\($0)" } ?? "Абонемент")
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(.primary)
                                            if m.kind == .byVisits {
                                                Text("Осталось \(m.remainingSessions) занятий")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            } else if let end = m.effectiveEndDate {
                                                Text("до \(end.formattedRuDayMonth)")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 4)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PressableButtonStyle())
                            }
                        }
                    }
                }
            }
        } else {
            SettingsCard(title: "Разовое посещение") {
                VStack(alignment: .leading, spacing: AppDesign.rowSpacing) {
                    Toggle(oneOffPaid ? "Оплачено" : "В долг", isOn: $oneOffPaid)
                    if !oneOffPaid {
                        Text("Занятие будет помечено как долг. Позже можно списать с абонемента в календаре.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func load() async {
        if isQuickTodayMode {
            await MainActor.run { isLoading = true }
            do {
                let list = try await membershipService.fetchMemberships(
                    coachProfileId: coachProfileId,
                    traineeProfileId: traineeProfileId
                )
                await MainActor.run { memberships = list.sorted { $0.createdAt > $1.createdAt } }
            } catch {
                if let msg = AppErrors.userMessageIfNeeded(for: error) {
                    await MainActor.run { errorMessage = msg }
                }
            }
            await MainActor.run { isLoading = false }
        } else {
            await MainActor.run { isLoading = false }
        }
    }

    private func addOneOff(paid: Bool) {
        isSaving = true
        errorMessage = nil
        let date = Calendar.current.startOfDay(for: selectedDate)
        Task {
            do {
                _ = try await visitService.createVisit(
                    coachProfileId: coachProfileId,
                    traineeProfileId: traineeProfileId,
                    date: date,
                    paymentStatus: paid ? "paid" : "debt",
                    membershipId: nil,
                    idempotencyKey: UUID().uuidString
                )
                await MainActor.run {
                    AppDesign.triggerSuccessHaptic()
                    ToastCenter.shared.success("Посещение добавлено")
                    isSaving = false
                    onAdded()
                }
            } catch {
                await MainActor.run {
                    ToastCenter.shared.error(from: error, fallback: "Не удалось добавить посещение")
                    if let msg = AppErrors.userMessageIfNeeded(for: error) { errorMessage = msg }
                    isSaving = false
                }
            }
        }
    }

    private func addWithMembership(_ membership: Membership) {
        isSaving = true
        errorMessage = nil
        let date = Calendar.current.startOfDay(for: selectedDate)
        Task {
            do {
                let visit = try await visitService.createVisit(
                    coachProfileId: coachProfileId,
                    traineeProfileId: traineeProfileId,
                    date: date,
                    paymentStatus: nil,
                    membershipId: nil,
                    idempotencyKey: UUID().uuidString
                )
                try await visitService.markVisitDoneWithMembership(visit, membershipId: membership.id)
                await MainActor.run {
                    membershipService.invalidateMembershipsCache(
                        coachProfileId: coachProfileId,
                        traineeProfileId: traineeProfileId
                    )
                    AppDesign.triggerSuccessHaptic()
                    ToastCenter.shared.success("Посещение списано с абонемента")
                    isSaving = false
                    onAdded()
                }
            } catch {
                await MainActor.run {
                    ToastCenter.shared.error(from: error, fallback: "Не удалось списать посещение")
                    if let msg = AppErrors.userMessageIfNeeded(for: error) { errorMessage = msg }
                    isSaving = false
                }
            }
        }
    }
}

