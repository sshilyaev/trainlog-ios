//
//  MembershipCardViews.swift
//  TrainLog
//
//  Переиспользуемые компоненты: карточка активного абонемента и плитка завершённого.
//  Используются на экране абонементов тренера (ClientMembershipsNewView) и подопечного (TraineeMembershipsView).
//

import SwiftUI

// MARK: - Короткий прогресс абонемента (для компактных блоков)

struct MembershipProgressInlineView: View {
    let membership: Membership
    var tint: Color = AppColors.profileAccent

    private let calendar = Calendar.current

    private var totalDays: Int? {
        guard membership.kind == .unlimited,
              let start = membership.startDate,
              let end = membership.effectiveEndDate else { return nil }
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let diff = (calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0)
        return max(0, diff) + 1
    }

    private var daysLeft: Int? {
        guard let totalDays, totalDays > 0,
              let end = membership.effectiveEndDate else { return nil }
        let now = calendar.startOfDay(for: Date())
        let endDay = calendar.startOfDay(for: end)
        if now > endDay { return 0 }
        let diff = (calendar.dateComponents([.day], from: now, to: endDay).day ?? 0)
        return max(0, diff) + 1
    }

    private var progressValue: Double? {
        switch membership.kind {
        case .byVisits:
            guard membership.totalSessions > 0 else { return nil }
            return Double(membership.usedSessions)
        case .unlimited:
            guard let totalDays, let left = daysLeft else { return nil }
            return Double(max(0, totalDays - left))
        }
    }

    private var progressTotal: Double? {
        switch membership.kind {
        case .byVisits:
            guard membership.totalSessions > 0 else { return nil }
            return Double(membership.totalSessions)
        case .unlimited:
            guard let totalDays, totalDays > 0 else { return nil }
            return Double(totalDays)
        }
    }

    private var titleLine: String {
        switch membership.kind {
        case .byVisits:
            return "Осталось \(membership.remainingSessions) из \(membership.totalSessions) занятий"
        case .unlimited:
            if let left = daysLeft, let totalDays {
                let endText = membership.effectiveEndDate?.formattedRuShort
                if let endText, !endText.isEmpty {
                    return "Осталось \(left) из \(totalDays) дней · до \(endText)"
                }
                return "Осталось \(left) из \(totalDays) дней"
            }
            if let end = membership.effectiveEndDate {
                return "До \(end.formattedRuShort)"
            }
            return "Активный абонемент"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titleLine)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let v = progressValue, let t = progressTotal {
                ProgressView(value: v, total: t)
                    .tint(tint)
                    .progressViewStyle(.linear)
            }
        }
    }
}

// MARK: - Плитка завершённого абонемента (2 в ряд)

struct MembershipFinishedTileView: View {
    let membership: Membership
    let completionDate: Date?
    var onViewVisits: (() -> Void)? = nil

    private var mainTitle: String {
        if let code = membership.displayCode, !code.isEmpty {
            return "№\(code)"
        }
        return membership.kind == .unlimited ? "Безлимитный" : "По занятиям"
    }

    private var completionDateText: String? {
        guard let d = completionDate else { return nil }
        return d.formattedRuShort
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        if let onViewVisits {
            Button {
                onViewVisits()
            } label: {
                Label("Посмотреть посещения", appIcon: "calendar-default")
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColors.secondaryLabel)
                    .frame(width: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 12)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 6) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mainTitle)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(membership.kind == .unlimited ? "Безлимит" : "\(membership.totalSessions) занятий")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        if onViewVisits != nil {
                            TiniActionButton(
                                color: .secondary,
                                font: .subheadline,
                                minWidth: 44,
                                minHeight: 44,
                                style: .borderless
                            ) {
                                contextMenuContent
                            }
                        }
                    }
                    Text("\(membership.usedSessions) из \(membership.totalSessions)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let dateText = completionDateText {
                        HStack(spacing: 4) {
                            Text("Дата завершения:")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text(dateText)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.leading, 10)
                .padding(.trailing, 12)
                .padding(.vertical, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.cornerRadius)
                .strokeBorder(AppColors.secondaryLabel.opacity(0.2), lineWidth: 1)
        )
        .contextMenu {
            contextMenuContent
        }
    }
}

// MARK: - Карточка одного абонемента (активный или завершённый)

struct MembershipCardNewView: View {
    let membership: Membership
    let isActive: Bool
    var showClosedManuallyLabel: Bool = false
    var loadingMembershipId: String? = nil
    var onAddVisit: (() -> Void)? = nil
    var onFreeze: ((Int) -> Void)? = nil
    var onUnfreeze: (() -> Void)? = nil
    var onClose: (() -> Void)? = nil
    var onViewVisits: (() -> Void)? = nil

    private var isCardLoading: Bool { loadingMembershipId == membership.id }

    @State private var showFreezeSheet = false
    @State private var freezeDaysInput = 7
    @State private var showCloseConfirmation = false

    private var isFrozen: Bool { membership.freezeDays > 0 }

    private var accentColor: Color {
        if !isActive { return .secondary }
        if membership.isEndingSoon { return AppColors.visitsOneTimeDebt }
        return isFrozen ? AppColors.visitsOneTimeDebt : AppColors.profileAccent
    }

    private var statusLabel: String {
        if !isActive {
            return showClosedManuallyLabel ? "Завершён досрочно" : "Завершён"
        }
        if membership.isEndingSoon { return "Скоро закончится" }
        return isFrozen ? "Заморожен" : "Активен"
    }

    private var endingSoonHint: String? {
        guard isActive, membership.isEndingSoon else { return nil }
        switch membership.kind {
        case .byVisits:
            return "Осталось \(membership.remainingSessions) посещения. Рекомендуется заранее продлить."
        case .unlimited:
            let days = membership.daysUntilEnd ?? 0
            return "До окончания \(days) дн. Предложите продление заранее."
        }
    }

    private var mainTitle: String {
        if let code = membership.displayCode, !code.isEmpty {
            return "№\(code)"
        }
        return membership.kind == .unlimited ? "Безлимитный" : "По занятиям"
    }

    private var progressFraction: Double? {
        switch membership.kind {
        case .byVisits:
            guard membership.totalSessions > 0 else { return nil }
            return Double(membership.usedSessions) / Double(membership.totalSessions)
        case .unlimited:
            guard let start = membership.startDate,
                  let end = membership.effectiveEndDate else { return nil }
            let calendar = Calendar.current
            let startDay = calendar.startOfDay(for: start)
            let endDay = calendar.startOfDay(for: end)
            let total = max(0, (calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0)) + 1
            guard total > 0 else { return nil }
            let now = calendar.startOfDay(for: Date())
            let left: Int
            if now > endDay {
                left = 0
            } else {
                left = max(0, (calendar.dateComponents([.day], from: now, to: endDay).day ?? 0)) + 1
            }
            let used = max(0, total - left)
            return Double(used) / Double(total)
        }
    }

    private var priceFormatted: String? {
        guard let rub = membership.priceRub, rub > 0 else { return nil }
        let formatter = NumberFormatter()
        formatter.locale = .ru
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        let str = formatter.string(from: NSNumber(value: rub)) ?? "\(rub)"
        return "\(str) ₽"
    }

    private var hasContextActions: Bool {
        if isActive {
            return onClose != nil || onViewVisits != nil || (membership.kind == .unlimited && (onFreeze != nil || (isFrozen && onUnfreeze != nil)))
        }
        return onViewVisits != nil
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        if isActive, membership.kind == .unlimited {
            if onFreeze != nil {
                Button {
                    freezeDaysInput = 7
                    showFreezeSheet = true
                } label: {
                    Label("Заморозить абонемент", appIcon: "snowflake")
                }
            }
            if isFrozen, onUnfreeze != nil {
                Button {
                    onUnfreeze?()
                } label: {
                    Label("Снять заморозку", appIcon: "snowflake")
                }
            }
        }
        if isActive, onClose != nil {
            Button(role: .destructive) {
                showCloseConfirmation = true
            } label: {
                Label("Закрыть абонемент", appIcon: "multiple-cross-cancel-circle")
            }
        }
        if onViewVisits != nil {
            Button {
                onViewVisits?()
            } label: {
                Label("Посмотреть посещения", appIcon: "calendar-default")
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor)
                    .frame(width: 4)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                    .padding(.leading, 0)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mainTitle)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                        Spacer(minLength: 8)
                        Text(statusLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(accentColor.opacity(0.9)))
                        if hasContextActions {
                            TiniActionButton(
                                color: .secondary,
                                font: .title3,
                                minWidth: 44,
                                minHeight: 44,
                                style: .borderless
                            ) {
                                contextMenuContent
                            }
                        }
                    }

                    if membership.kind == .byVisits {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(membership.usedSessions)")
                                .font(.title.weight(.semibold))
                                .foregroundStyle(accentColor)
                            Text("из \(membership.totalSessions)")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                            Text("занятий")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if let fraction = progressFraction {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(AppColors.tertiarySystemFill)
                                        .frame(height: 6)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(accentColor)
                                        .frame(width: max(0, geo.size.width * fraction), height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                    } else {
                        // Безлимитный — прогресс по дням (как по занятиям): «Осталось X из Y дней · до …» + полоска.
                        let calendar = Calendar.current
                        let totalDays: Int? = {
                            guard let start = membership.startDate, let end = membership.effectiveEndDate else { return nil }
                            let startDay = calendar.startOfDay(for: start)
                            let endDay = calendar.startOfDay(for: end)
                            let diff = (calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0)
                            return max(0, diff) + 1
                        }()
                        let daysLeft: Int? = {
                            guard let totalDays, totalDays > 0, let end = membership.effectiveEndDate else { return nil }
                            let now = calendar.startOfDay(for: Date())
                            let endDay = calendar.startOfDay(for: end)
                            if now > endDay { return 0 }
                            let diff = (calendar.dateComponents([.day], from: now, to: endDay).day ?? 0)
                            return max(0, diff) + 1
                        }()
                        if let left = daysLeft, let total = totalDays {
                            let endText = membership.effectiveEndDate?.formattedRuShort
                            Text("Осталось \(left) из \(total) дней" + ((endText?.isEmpty == false) ? " · до \(endText!)" : ""))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                        } else if let end = membership.effectiveEndDate {
                            HStack(spacing: 6) {
                                AppTablerIcon("calendar-default")
                                    .font(.subheadline)
                                    .foregroundStyle(accentColor)
                                Text("До \(end.formattedRuShort)")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                            }
                        }
                        if membership.usedSessions > 0 {
                            Text("Посещено: \(membership.usedSessions)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        if isFrozen {
                            HStack(spacing: 6) {
                                AppTablerIcon("sparkle-ai-01")
                                    .font(.caption)
                                Text("+\(membership.freezeDays) дн. заморозки")
                                    .font(.caption)
                            }
                            .foregroundStyle(AppColors.visitsOneTimeDebt)
                        }
                        if let fraction = progressFraction {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(AppColors.tertiarySystemFill)
                                        .frame(height: 6)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(accentColor)
                                        .frame(width: max(0, geo.size.width * fraction), height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                    }

                    if let endingSoonHint {
                        Label(endingSoonHint, appIcon: "alert-triangle")
                            .font(.caption)
                            .foregroundStyle(AppColors.visitsOneTimeDebt)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(AppColors.visitsOneTimeDebt.opacity(0.12))
                            )
                    }

                    HStack(spacing: 12) {
                        if let price = priceFormatted {
                            Label(price, appIcon: "wallet-default")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Text("Создан \(membership.createdAt.formattedRuShort)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.leading, 14)
                .padding(.trailing, AppDesign.cardPadding)
                .padding(.vertical, AppDesign.cardPadding)
            }

            if isActive, isFrozen, onUnfreeze != nil {
                Button {
                    onUnfreeze?()
                } label: {
                    WideActionButtonToOneColumn(
                        icon: "sparkle-ai-01",
                        title: "Разморозить",
                        subtitle: "",
                        iconColor: AppColors.secondaryLabel,
                        chevronColor: AppColors.tertiaryLabel
                    )
                    .padding(.leading, 18)
                    .padding(.trailing, AppDesign.cardPadding)
                }
                .buttonStyle(PressableButtonStyle(cornerRadius: 10))
                .padding(.top, 8)
            }

            if isActive, onAddVisit != nil {
                Button {
                    onAddVisit?()
                } label: {
                    WideActionButtonToOneColumn(
                        icon: "calendar-filled",
                        title: "Добавить посещение",
                        subtitle: "",
                        iconColor: AppColors.secondaryLabel,
                        chevronColor: AppColors.tertiaryLabel
                    )
                    .padding(.horizontal, AppDesign.cardPadding)
                    .padding(.vertical, 10)
                }
                .buttonStyle(PressableButtonStyle(cornerRadius: 10))
                .padding(.top, 8)
            }
        }
        .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.cornerRadius)
                .strokeBorder(accentColor.opacity(0.25), lineWidth: 1)
        )
        .overlay {
            if isCardLoading {
                RoundedRectangle(cornerRadius: AppDesign.cornerRadius)
                    .fill(AppColors.overlayDimLight)
                VStack(spacing: AppDesign.loadingSpacing) {
                    ProgressView()
                        .scaleEffect(AppDesign.loadingScale)
                    Text("Загрузка…")
                        .font(AppDesign.loadingMessageFont)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .allowsHitTesting(!isCardLoading)
        .contextMenu {
            contextMenuContent
        }
        .sheet(isPresented: $showFreezeSheet) {
            FreezeMembershipSheet(
                membership: membership,
                days: $freezeDaysInput,
                onApply: {
                    onFreeze?(freezeDaysInput)
                    showFreezeSheet = false
                },
                onCancel: { showFreezeSheet = false }
            )
            .mainSheetPresentation(.detents([.height(340)]))
        }
        .appConfirmationDialog(
            title: "Закрыть абонемент?",
            message: "Абонемент перейдёт в завершённые с пометкой «Завершён досрочно». Действие нельзя отменить",
            isPresented: $showCloseConfirmation,
            confirmTitle: "Закрыть",
            confirmRole: .destructive,
            onConfirm: {
                showCloseConfirmation = false
                onClose?()
            },
            onCancel: {
                showCloseConfirmation = false
            }
        )
    }
}
