//
//  DeveloperSettingsView.swift
//  TrainLog
//

import SwiftUI

/// Экран «Настройки разработчика»: переключатели и ссылки для режима разработчика профиля.
/// Отображается только при `profile.isDeveloperModeEnabled`.
struct DeveloperSettingsView: View {
    let profile: Profile

    @AppStorage("healthDemoModeEnabled") private var healthDemoModeEnabled = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if profile.isTrainee {
                    SettingsCard(title: "Apple Health") {
                        Toggle(isOn: $healthDemoModeEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Демо-данные Apple Health")
                                    .appTypography(.secondary)
                                    .foregroundStyle(.primary)
                                Text("На экране «Мои замеры» блок Apple Health покажет выдуманные данные вместо реальных.")
                                    .appTypography(.caption)
                                    .foregroundStyle(AppColors.secondaryLabel)
                            }
                        }
                        .tint(AppColors.accent)
                    }
                    .padding(.horizontal, AppDesign.cardPadding)
                    .padding(.top, AppDesign.blockSpacing)
                }

                SettingsCard(title: "Интерфейс") {
                    NavigationLink {
                        DeveloperComponentsCatalogView()
                    } label: {
                        WideActionButtonToOneColumn(
                            icon: "grid-dashboard-02",
                            title: "UI Kit",
                            subtitle: "Каталог компонентов интерфейса (для разработки)",
                            iconColor: AppColors.secondaryLabel,
                            chevronColor: AppColors.tertiaryLabel
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                }
                .padding(.horizontal, AppDesign.cardPadding)
                .padding(.top, AppDesign.blockSpacing)

                Text("В будущем здесь появятся другие переключатели и функции для разработки.")
                    .appTypography(.caption)
                    .foregroundStyle(AppColors.tertiaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppDesign.cardPadding)
                    .padding(.top, 20)
            }
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .background(AdaptiveScreenBackground())
        .navigationTitle("Настройки разработчика")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        DeveloperSettingsView(profile: Profile(id: "1", userId: "u1", type: .trainee, name: "Дневник"))
    }
}
