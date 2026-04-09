import SwiftUI

struct AppSettingsView: View {
    @AppStorage("appTheme") private var appThemeRaw = AppTheme.system.rawValue
    @AppStorage("appFontSizeStep") private var fontSizeStep = 0

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
                    SegmentedPicker(
                        title: "",
                        selection: $fontSizeStep,
                        options: [
                            (0, "Стандарт"),
                            (1, "Средний"),
                            (2, "Большой"),
                        ]
                    )
                }

                SettingsCard(title: "Правовая информация") {
                    NavigationLink {
                        LegalDocumentsPlaceholderView()
                    } label: {
                        CardRow(icon: "list-details", title: "Документы и соглашения", showsDisclosure: true)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .background(AdaptiveScreenBackground())
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LegalDocumentsPlaceholderView: View {
    var body: some View {
        ScrollView {
            SettingsCard(title: "Документы и соглашения") {
                Text("Раздел документов скоро будет обновлён.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(AdaptiveScreenBackground())
        .navigationTitle("Документы")
        .navigationBarTitleDisplayMode(.inline)
    }
}

