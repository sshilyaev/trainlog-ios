import SwiftUI

struct ProfileManagementSection<DeveloperDestination: View>: View {
    let showsDeveloperSettings: Bool
    let deleteSubtitle: String
    let onDeleteTap: () -> Void
    @ViewBuilder let developerDestination: () -> DeveloperDestination

    var body: some View {
        SimpleContentCard(title: "Управление профилем") {
            NavigationLink {
                AppSettingsView(
                    showsDeveloperSettings: showsDeveloperSettings,
                    developerSettingsDestination: {
                        AnyView(developerDestination())
                    }
                )
            } label: {
                WideActionButtonToOneColumn(
                    icon: "settings",
                    title: "Настройки",
                    subtitle: "Тема, размер текста, документы",
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
