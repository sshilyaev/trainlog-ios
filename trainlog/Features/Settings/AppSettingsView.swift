import SwiftUI

struct AppSettingsView: View {
    let showsDeveloperSettings: Bool
    let developerSettingsDestination: (() -> AnyView)?
    let supportCampaignService: SupportCampaignServiceProtocol
    let rewardedAdService: RewardedAdServiceProtocol

    @AppStorage("appTheme") private var appThemeRaw = AppTheme.system.rawValue
    @AppStorage("appFontSizeStep") private var fontSizeStep = 0

    init(
        showsDeveloperSettings: Bool = false,
        developerSettingsDestination: (() -> AnyView)? = nil,
        supportCampaignService: SupportCampaignServiceProtocol = MockSupportCampaignService(),
        rewardedAdService: RewardedAdServiceProtocol = DevMockRewardedAdService()
    ) {
        self.showsDeveloperSettings = showsDeveloperSettings
        self.developerSettingsDestination = developerSettingsDestination
        self.supportCampaignService = supportCampaignService
        self.rewardedAdService = rewardedAdService
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SettingsCard(title: "Тема оформления") {
                    SegmentedPicker(
                        title: "",
                        selection: $appThemeRaw,
                        options: [
                            (AppTheme.light.rawValue, "Светлая"),
                            (AppTheme.dark.rawValue, "Тёмная"),
                            (AppTheme.system.rawValue, "Системная"),
                        ]
                    )
                }

                SettingsCard(title: "Размер текста в приложении") {
                    TextSizeSliderRow(step: $fontSizeStep)
                }

                SettingsCard(title: "Поддержать проект") {
                    NavigationLink {
                        SupportProjectView(
                            campaignService: supportCampaignService,
                            rewardedAdService: rewardedAdService
                        )
                    } label: {
                        CardRow(
                            icon: "currency-rubel",
                            title: "Игровая поддержка",
                            value: "Добровольно",
                            showsDisclosure: true
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                }

                SettingsCard(title: "Правовая информация") {
                    NavigationLink {
                        LegalDocumentsPlaceholderView()
                    } label: {
                        CardRow(icon: "list-details", title: "Документы и соглашения", showsDisclosure: true)
                    }
                    .buttonStyle(PressableButtonStyle())
                }

                if showsDeveloperSettings, let developerSettingsDestination {
                    SettingsCard(title: "Для разработчика") {
                        NavigationLink {
                            developerSettingsDestination()
                        } label: {
                            WideActionButtonToOneColumn(
                                icon: "troubleshoot",
                                title: "Настройки разработчика",
                                subtitle: "Apple Health демо, UI Kit и другие опции",
                                iconColor: AppColors.secondaryLabel,
                                chevronColor: AppColors.tertiaryLabel,
                                accent: AppColors.profileAccent,
                                showsLeadingAccentBar: true,
                                statusTitle: "Dev",
                                statusColor: AppColors.profileAccent
                            )
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
            }
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .background(AdaptiveScreenBackground())
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TextSizeSliderRow: View {
    @Binding var step: Int

    private var sliderBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(AppFontSizeStepStorage.clamp(step)) },
            set: { step = Int($0.rounded()) }
        )
    }

    private var currentTitle: String {
        switch AppFontSizeStepStorage.clamp(step) {
        case 1: return "Увеличенный"
        default: return "Стандарт"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("A")
                    .appTypography(.body)
                    .foregroundStyle(.secondary)
                Slider(value: sliderBinding, in: 0...1, step: 1)
                    .tint(AppColors.accent)
                Text("A")
                    .appTypography(.screenTitle)
                    .foregroundStyle(.primary)
            }

            Text(currentTitle)
                .appTypography(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct LegalDocumentsPlaceholderView: View {
    var body: some View {
        ScrollView {
            SettingsCard(title: "Документы и соглашения") {
                Text("Раздел документов скоро будет обновлён.")
                    .appTypography(.secondary)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(AdaptiveScreenBackground())
        .navigationTitle("Документы")
        .navigationBarTitleDisplayMode(.inline)
    }
}

