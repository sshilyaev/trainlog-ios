import SwiftUI

struct SupportProjectView: View {
    let campaignService: SupportCampaignServiceProtocol
    let rewardedAdService: RewardedAdServiceProtocol

    @State private var response: SupportCampaignResponse?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var isClaimingReward = false
    @State private var isCreatingCampaign = false
    @State private var selectedGoalType: SupportCampaignGoalType = .loseWeight
    @State private var showAboutSectionSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppDesign.blockSpacing) {
                heroCard

                if isLoading && loadError == nil {
                    LoadingBlockView(message: "Загружаю кампанию…")
                        .padding(.horizontal, AppDesign.cardPadding)
                } else if let loadError {
                    loadFailedCard(message: loadError)
                } else if let response {
                    virtualClientPlayCard(response.campaign)
                    if response.campaign.status != .completed {
                        nextMoveButton
                    } else {
                        newQuestControls
                    }
                    contributionStrip(response)
                    historyLinkRow(response.history)
                } else {
                    interruptedLoadHint
                }
            }
            .padding(.top, AppDesign.blockSpacing)
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .background(AdaptiveScreenBackground())
        .navigationTitle("Поддержать проект")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showAboutSectionSheet) {
            RecordsGuideSheet(
                title: "Поддержка TrainLog",
                headline: "Мини-игра с пользой",
                description: "Добровольная игровая кампания: вы ведёте виртуального подопечного к цели в килограммах. Один просмотр короткого ролика по вашему желанию даёт шаг прогресса в игре и помогает монетизировать приложение без навязчивой рекламы в дневнике.",
                examples: [
                    RecordsGuideExample(
                        title: "Следующий ход",
                        subtitle: "Короткий ролик — шаг к цели виртуального клиента; без вашего нажатия реклама не показывается."
                    ),
                    RecordsGuideExample(
                        title: "Новый квест",
                        subtitle: "После завершения цели можно начать кампанию снова и выбрать снижение или набор веса."
                    ),
                    RecordsGuideExample(
                        title: "Счёт и архив",
                        subtitle: "Здесь же — квесты завершены, бусты и история, отдельно от реальных замеров в дневнике."
                    ),
                ],
                tips: [
                    "Это не медицинская рекомендация и не замена замерам и целям тренировок.",
                    "Реклама связана только с этим разделом: она запускается, когда вы сами нажимаете «Следующий ход».",
                    "Показатели «Счёт» относятся только к мини-игре, а не к клиентам в дневнике.",
                ],
                onPrimaryAction: nil,
                primaryActionTitle: "",
                onClose: { showAboutSectionSheet = false }
            )
            .mainSheetPresentation(.full)
        }
    }

    private var heroCard: some View {
        SupportMiniGameHeroIntro {
            Text("Это игровая механика поддержки проекта, а не медицинская рекомендация.")
                .appTypography(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                showAboutSectionSheet = true
            } label: {
                AppTablerIcon("info-circle")
                    .foregroundStyle(AppColors.secondaryLabel)
                    .padding(8)
                    .background(AppColors.secondarySystemGroupedBackground.opacity(0.9), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("О разделе")
            .padding(10)
        }
        .padding(.horizontal, AppDesign.cardPadding)
    }

    private var interruptedLoadHint: some View {
        VStack(spacing: 14) {
            Text("Потяните экран вниз, чтобы обновить данные.")
                .appTypography(.secondary)
                .foregroundStyle(AppColors.secondaryLabel)
                .multilineTextAlignment(.center)
            Button("Повторить загрузку") {
                Task { await load() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, AppDesign.cardPadding)
        .frame(maxWidth: .infinity)
    }

    private func loadFailedCard(message: String) -> some View {
        VStack(spacing: 16) {
            AppTablerIcon("cloud-off")
                .appIcon(.s44)
                .foregroundStyle(AppColors.accent.opacity(0.9))
            Text("Не удалось загрузить кампанию")
                .appTypography(.sectionTitle)
                .multilineTextAlignment(.center)
            Text(message)
                .appTypography(.secondary)
                .foregroundStyle(AppColors.secondaryLabel)
                .multilineTextAlignment(.center)
            Button("Повторить") {
                Task { await load() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(AppDesign.cardPadding)
        .frame(maxWidth: .infinity)
        .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
        .padding(.horizontal, AppDesign.cardPadding)
    }

    private func virtualClientPlayCard(_ campaign: SupportCampaignState) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Ваш виртуальный подопечный")
                    .appTypography(.caption)
                    .foregroundStyle(AppColors.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.accent.opacity(0.14), in: Capsule())
                Spacer()
                Text("#\(shortCampaignId(campaign.id))")
                    .appTypography(.caption)
                    .foregroundStyle(AppColors.tertiaryLabel)
            }

            if campaign.status == .completed {
                questCompletedStrip
            }

            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppColors.accent.opacity(0.35),
                                    AppColors.profileAccent.opacity(0.22),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 76, height: 76)
                        .overlay(
                            Circle()
                                .strokeBorder(AppColors.accent.opacity(0.35), lineWidth: 1)
                        )
                    AppTablerIcon(campaign.status == .completed ? "trophy" : "user")
                        .appIcon(.s32, weight: .medium)
                        .foregroundStyle(AppColors.label)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(questHeadline(campaign))
                        .appTypography(.bodyEmphasis)
                        .foregroundStyle(AppColors.label)
                    if campaign.status != .completed {
                        Text("До финиша: \(remainingToGoalLabel(campaign))")
                            .appTypography(.caption)
                            .foregroundStyle(AppColors.secondaryLabel)
                    } else {
                        Text("Цель выполнена — можно взять новый квест.")
                            .appTypography(.caption)
                            .foregroundStyle(AppColors.secondaryLabel)
                    }
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Прогресс квеста")
                        .appTypography(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                    Spacer()
                    Text("\(Int(round(campaign.progressFraction * 100)))%")
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(AppColors.accent)
                }
                GeometryReader { geo in
                    let w = geo.size.width
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppColors.tertiarySystemFill)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.accent, AppColors.accent.opacity(0.65)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(11, w * campaign.progressFraction), height: 11)
                    }
                }
                .frame(height: 11)
            }

            HStack(spacing: 8) {
                weightChip(title: "Старт", value: campaign.startWeightKg)
                weightChip(title: "Сейчас", value: campaign.currentWeightKg, isHighlight: true)
                weightChip(title: "Цель", value: campaign.targetWeightKg)
            }
        }
        .padding(AppDesign.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.cornerRadius, style: .continuous)
                .fill(AppColors.secondarySystemGroupedBackground)
                .shadow(color: AppColors.accent.opacity(0.08), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [AppColors.accent.opacity(0.45), AppColors.profileAccent.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .padding(.horizontal, AppDesign.cardPadding)
    }

    private var questCompletedStrip: some View {
        HStack(alignment: .top, spacing: 10) {
            AppTablerIcon("circle-check")
                .foregroundStyle(AppColors.accent)
                .appTypography(.numericMetric)
            VStack(alignment: .leading, spacing: 4) {
                Text("Квест пройден")
                    .appTypography(.bodyEmphasis)
                Text("Подопечный дошёл до цели. Ниже выберите тип нового квеста.")
                    .appTypography(.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func weightChip(title: String, value: Double, isHighlight: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .appTypography(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
            Text("\(value.formattedOneDecimal) кг")
                .appTypography(.bodyEmphasis)
                .foregroundStyle(isHighlight ? AppColors.accent : AppColors.label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            (isHighlight ? AppColors.accent.opacity(0.1) : AppColors.tertiarySystemFill.opacity(0.65)),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }

    private var nextMoveButton: some View {
        Button {
            Task { await claimReward() }
        } label: {
            VStack(spacing: 5) {
                HStack(spacing: 10) {
                    AppTablerIcon("sparkles")
                        .appTypography(.numericMetric)
                    Text(isClaimingReward ? "Проверяем…" : "Следующий ход")
                        .appTypography(.sectionTitle)
                }
                Text("Короткий ролик — только по вашему выбору")
                    .appTypography(.caption)
                    .foregroundStyle(Color.white.opacity(0.92))
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [AppColors.accent, AppColors.accent.opacity(0.72)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .shadow(color: AppColors.accent.opacity(0.35), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(isClaimingReward)
        .padding(.horizontal, AppDesign.cardPadding)
    }

    private var newQuestControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Новый квест")
                .appTypography(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
                .padding(.horizontal, AppDesign.cardPadding)

            VStack(spacing: 12) {
                Picker("Тип цели", selection: $selectedGoalType) {
                    Text("Снизить вес").tag(SupportCampaignGoalType.loseWeight)
                    Text("Набрать вес").tag(SupportCampaignGoalType.gainWeight)
                }
                .pickerStyle(.segmented)

                Button {
                    Task { await createNewCampaign(goalType: selectedGoalType) }
                } label: {
                    HStack {
                        if isCreatingCampaign {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.9)
                        }
                        Text(isCreatingCampaign ? "Создаём квест…" : "Начать новый квест")
                            .appTypography(.sectionTitle)
                    }
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColors.profileAccent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle(cornerRadius: 12))
                .disabled(isCreatingCampaign)
            }
            .padding(AppDesign.cardPadding)
            .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
            .padding(.horizontal, AppDesign.cardPadding)
        }
    }

    private func contributionStrip(_ response: SupportCampaignResponse) -> some View {
        SettingsCard(title: "Счёт") {
            HStack(alignment: .top, spacing: 10) {
                statBlock(
                    title: "Квестов завершено",
                    value: "\(response.campaign.savedClientsCount)"
                )
                statBlock(
                    title: "Бустов",
                    value: "\(response.meta.rewardEventsTotal)"
                )
                statBlock(
                    title: "Последний буст",
                    value: response.meta.isIdempotent ? "Повтор" : "Новый"
                )
            }
        }
    }

    private func statBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .appTypography(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .appTypography(.bodyEmphasis)
                .foregroundStyle(AppColors.label)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func historyLinkRow(_ items: [SupportCampaignHistoryItem]) -> some View {
        NavigationLink {
            SupportCampaignHistoryView(items: items)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                AppTablerIcon("archive")
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 28, alignment: .center)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Архив квестов")
                        .appTypography(.bodyEmphasis)
                        .foregroundStyle(AppColors.label)
                    Text(historySubtitle(for: items))
                        .appTypography(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                AppTablerIcon("chevron-right")
                    .appIcon(.s14)
                    .foregroundStyle(AppColors.secondaryLabel)
            }
            .padding(AppDesign.cardPadding)
            .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.horizontal, AppDesign.cardPadding)
    }

    private func historySubtitle(for items: [SupportCampaignHistoryItem]) -> String {
        if items.isEmpty {
            return "Пока пусто — сюда попадают завершённые квесты"
        }
        let n = items.count
        let word = russianPluralClients(n)
        return "Записей: \(n) \(word)"
    }

    private func russianPluralClients(_ n: Int) -> String {
        let n10 = n % 10
        let n100 = n % 100
        if n10 == 1, n100 != 11 { return "клиент" }
        if (2...4).contains(n10), !(12...14).contains(n100) { return "клиента" }
        return "клиентов"
    }

    private func load() async {
        await MainActor.run {
            isLoading = true
            loadError = nil
        }
        do {
            let loaded = try await campaignService.fetchCampaign()
            await MainActor.run {
                response = loaded
                selectedGoalType = loaded.campaign.goalType
                isLoading = false
                loadError = nil
            }
        } catch {
            await MainActor.run {
                isLoading = false
                if let msg = AppErrors.userMessageIfNeeded(for: error) {
                    loadError = msg
                } else {
                    loadError = nil
                }
            }
        }
    }

    private func claimReward() async {
        guard !isClaimingReward else { return }
        await MainActor.run { isClaimingReward = true }
        defer {
            Task { @MainActor in isClaimingReward = false }
        }
        do {
            let adResult = try await rewardedAdService.presentRewardedAd()
            let updated = try await campaignService.claimReward(
                adProvider: adResult.adProvider,
                externalEventId: adResult.externalEventId,
                rewardValueKg: 1.0
            )
            await MainActor.run { response = updated }
            if updated.campaign.status != .completed {
                ToastCenter.shared.success("Прогресс обновлён")
            }
        } catch {
            if let localized = (error as? LocalizedError)?.errorDescription {
                ToastCenter.shared.error(localized)
            } else {
                ToastCenter.shared.error(from: error, fallback: "Награда не начислена")
            }
        }
    }

    private func createNewCampaign(goalType: SupportCampaignGoalType) async {
        guard !isCreatingCampaign else { return }
        await MainActor.run { isCreatingCampaign = true }
        defer {
            Task { @MainActor in isCreatingCampaign = false }
        }
        do {
            let updated = try await campaignService.createNewCampaign(goalType: goalType)
            await MainActor.run { response = updated }
            ToastCenter.shared.success("Новый квест начат")
        } catch {
            ToastCenter.shared.error(from: error, fallback: "Не удалось начать новый квест")
        }
    }
}

// MARK: - Hero (как HeroCard + glow; «О разделе» — оверлей, см. PersonalRecordsView)

private struct SupportMiniGameHeroIntro<Footer: View>: View {
    private let accent = AppColors.accent
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                AppTablerIcon("currency-rubel")
                    .appTypography(.numericMetric)
                    .foregroundStyle(accent)
                Text("Поддержка TrainLog")
                    .appTypography(.bodyEmphasis)
                    .foregroundStyle(.secondary)
            }

            Text("Мини-игра с пользой")
                .appTypography(.screenTitle)
                .foregroundStyle(.primary)

            Text("Смотрите рекламу только по желанию и помогайте виртуальным клиентам достигать цели.")
                .appTypography(.secondary)
                .foregroundStyle(.secondary)

            footer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppDesign.cardPadding)
        .background {
            supportHeroGlowBackground(accent: accent)
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerRadius, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.cornerRadius, style: .continuous)
                .stroke(accent.opacity(0.20), lineWidth: 1)
        )
    }
}

private func supportHeroGlowBackground(accent: Color) -> some View {
    let base = LinearGradient(
        colors: [accent.opacity(0.14), accent.opacity(0.045)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    return ZStack {
        base
        Circle()
            .fill(accent.opacity(0.16))
            .frame(width: 120, height: 120)
            .blur(radius: 18)
            .offset(x: 90, y: -54)
        Circle()
            .fill(AppColors.profileAccent.opacity(0.12))
            .frame(width: 140, height: 140)
            .blur(radius: 22)
            .offset(x: -110, y: 62)
    }
}

// MARK: - Helpers

private func shortCampaignId(_ id: String) -> String {
    let compact = id.replacingOccurrences(of: "-", with: "")
    return String(compact.prefix(4)).uppercased()
}

private func questHeadline(_ campaign: SupportCampaignState) -> String {
    switch campaign.goalType {
    case .loseWeight:
        return "Квест: снизить вес"
    case .gainWeight:
        return "Квест: набрать вес"
    }
}

private func remainingToGoalLabel(_ campaign: SupportCampaignState) -> String {
    let kg: Double
    switch campaign.goalType {
    case .loseWeight:
        kg = max(0, campaign.currentWeightKg - campaign.targetWeightKg)
    case .gainWeight:
        kg = max(0, campaign.targetWeightKg - campaign.currentWeightKg)
    }
    return "\(kg.formattedOneDecimal) кг"
}

private extension Double {
    var formattedOneDecimal: String {
        String(format: "%.1f", self)
    }
}

#Preview {
    NavigationStack {
        SupportProjectView(
            campaignService: MockSupportCampaignService(),
            rewardedAdService: DevMockRewardedAdService()
        )
    }
}
