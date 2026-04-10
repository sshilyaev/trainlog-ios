import SwiftUI

struct ProfileManagementSection<DeveloperDestination: View>: View {
    let showsDeveloperSettings: Bool
    let deleteSubtitle: String
    let onDeleteTap: () -> Void
    let supportCampaignService: SupportCampaignServiceProtocol
    let rewardedAdService: RewardedAdServiceProtocol
    @ViewBuilder let developerDestination: () -> DeveloperDestination

    var body: some View {
        SimpleContentCard(title: "Управление профилем") {
            NavigationLink {
                AppSettingsView(
                    showsDeveloperSettings: showsDeveloperSettings,
                    developerSettingsDestination: {
                        AnyView(developerDestination())
                    },
                    supportCampaignService: supportCampaignService,
                    rewardedAdService: rewardedAdService
                )
            } label: {
                WideActionButtonToOneColumn(
                    icon: "settings",
                    title: "Настройки",
                    subtitle: "Тема, размер текста, поддержка проекта, документы",
                    iconColor: AppColors.secondaryLabel,
                    chevronColor: AppColors.tertiaryLabel,
                    accent: AppColors.accent,
                    showsLeadingAccentBar: true
                )
            }
            .buttonStyle(PressableButtonStyle())

            Button(action: onDeleteTap) {
                WideActionButtonToOneColumn(
                    icon: "delete-dustbin-01",
                    title: "Удалить профиль",
                    subtitle: "",
                    iconColor: AppColors.secondaryLabel,
                    titleColor: .red,
                    subtitleColor: AppColors.secondaryLabel,
                    chevronColor: AppColors.tertiaryLabel,
                    accent: .red,
                    showsLeadingAccentBar: true
                )
            }
            .buttonStyle(PressableButtonStyle())
        }
    }
}
