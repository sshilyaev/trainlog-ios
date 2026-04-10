import SwiftUI

struct SupportProjectView: View {
    let campaignService: SupportCampaignServiceProtocol
    let rewardedAdService: RewardedAdServiceProtocol

    @State private var response: SupportCampaignResponse?
    @State private var isLoading = true
    @State private var isClaimingReward = false
    @State private var selectedGoalType: SupportCampaignGoalType = .loseWeight

    var body: some View {
        ScrollView {
            VStack(spacing: AppDesign.blockSpacing) {
                heroCard

                if isLoading {
                    LoadingBlockView(message: "Загружаю кампанию…")
                        .padding(.horizontal, AppDesign.cardPadding)
                } else if let response {
                    campaignCard(response.campaign)
                    statsCard(response)
                    historyCard(response.history)
                }
            }
            .padding(.top, AppDesign.blockSpacing)
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .background(AdaptiveScreenBackground())
        .navigationTitle("Поддержать проект")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var heroCard: some View {
        HeroCard(
            icon: "heart-handshake",
            title: "Поддержка TrainLog",
            headline: "Мини-игра с пользой",
            description: "Смотрите рекламу только по желанию и помогайте виртуальным клиентам достигать цели."
        ) {
            Text("Это игровая механика поддержки проекта, а не медицинская рекомендация.")
                .font(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, AppDesign.cardPadding)
    }

    private func campaignCard(_ campaign: SupportCampaignState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Текущий виртуальный клиент")
                .font(.subheadline.weight(.semibold))

            HStack {
                campaignValue(title: "Старт", value: "\(campaign.startWeightKg.formattedOneDecimal) кг")
                campaignValue(title: "Сейчас", value: "\(campaign.currentWeightKg.formattedOneDecimal) кг")
                campaignValue(title: "Цель", value: "\(campaign.targetWeightKg.formattedOneDecimal) кг")
            }

            ProgressView(value: campaign.progressFraction)
                .tint(AppColors.accent)

            Text(campaign.goalType == .loseWeight ? "Цель: снизить вес" : "Цель: набрать вес")
                .font(.caption)
                .foregroundStyle(.secondary)

            if campaign.status == .completed {
                Button("Создать нового клиента") {
                    Task { await createNewCampaign(goalType: selectedGoalType) }
                }
                .buttonStyle(.borderedProminent)
                Picker("Тип цели", selection: $selectedGoalType) {
                    Text("Снизить вес").tag(SupportCampaignGoalType.loseWeight)
                    Text("Набрать вес").tag(SupportCampaignGoalType.gainWeight)
                }
                .pickerStyle(.segmented)
            } else {
                Button {
                    Task { await claimReward() }
                } label: {
                    HStack {
                        AppTablerIcon("gift")
                        Text(isClaimingReward ? "Проверяем награду…" : "Помочь клиенту (посмотреть рекламу)")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isClaimingReward)
            }
        }
        .padding(AppDesign.cardPadding)
        .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
        .padding(.horizontal, AppDesign.cardPadding)
    }

    private func statsCard(_ response: SupportCampaignResponse) -> some View {
        SettingsCard(title: "Ваш вклад") {
            HStack {
                campaignValue(title: "Спасено клиентов", value: "\(response.campaign.savedClientsCount)")
                campaignValue(title: "Наград получено", value: "\(response.meta.rewardEventsTotal)")
                campaignValue(title: "Последнее начисление", value: response.meta.isIdempotent ? "Повтор" : "Новое")
            }
        }
        .padding(.horizontal, AppDesign.cardPadding)
    }

    private func historyCard(_ items: [SupportCampaignHistoryItem]) -> some View {
        SettingsCard(title: "История спасений") {
            if items.isEmpty {
                Text("Пока нет завершённых клиентов.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 8) {
                    ForEach(items.prefix(5)) { item in
                        HStack {
                            Text(item.goalType == .loseWeight ? "Снижение веса" : "Набор веса")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text(item.createdAt.formattedRuDayMonth)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(.horizontal, AppDesign.cardPadding)
    }

    private func campaignValue(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppColors.secondaryLabel)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func load() async {
        do {
            isLoading = true
            let loaded = try await campaignService.fetchCampaign()
            await MainActor.run {
                response = loaded
                selectedGoalType = loaded.campaign.goalType
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
            ToastCenter.shared.error(from: error, fallback: "Не удалось загрузить кампанию")
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
            if updated.campaign.status == .completed {
                ToastCenter.shared.success("Клиент спасён. Можно создать нового!")
            } else {
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
        do {
            let updated = try await campaignService.createNewCampaign(goalType: goalType)
            await MainActor.run { response = updated }
            ToastCenter.shared.success("Новый клиент создан")
        } catch {
            ToastCenter.shared.error(from: error, fallback: "Не удалось создать нового клиента")
        }
    }
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

