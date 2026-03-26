import SwiftUI

struct ProfileManagementSection<DeveloperDestination: View>: View {
    let showsDeveloperSettings: Bool
    let deleteSubtitle: String
    let onDeleteTap: () -> Void
    @ViewBuilder let developerDestination: () -> DeveloperDestination

    var body: some View {
        SimpleContentCard(title: "Управление профилем") {
            if showsDeveloperSettings {
                NavigationLink {
                    developerDestination()
                } label: {
                    WideActionButtonToOneColumn(
                        icon: "troubleshoot",
                        title: "Настройки разработчика",
                        subtitle: "Apple Health демо, UI Kit и другие опции",
                        iconColor: AppColors.secondaryLabel,
                        chevronColor: AppColors.tertiaryLabel
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }

            Button(action: onDeleteTap) {
                WideActionButtonToOneColumn(
                    icon: "delete-dustbin-01",
                    title: "Удалить профиль",
                    subtitle: deleteSubtitle,
                    iconColor: AppColors.secondaryLabel,
                    titleColor: .red,
                    subtitleColor: AppColors.secondaryLabel,
                    chevronColor: AppColors.tertiaryLabel
                )
            }
            .buttonStyle(PressableButtonStyle())
        }
    }
}
