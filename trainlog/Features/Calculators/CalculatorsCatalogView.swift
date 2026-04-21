import SwiftUI

struct CalculatorsCatalogView: View {
    let calculatorsService: CalculatorsServiceProtocol
    let profileId: String?

    @State private var isLoading = true
    @State private var catalog: [CalculatorCatalogItem] = []
    @State private var loadError: String?

    private static let accentCycle: [Color] = [
        AppColors.accent,
        AppColors.logoTeal,
        AppColors.logoRose,
        AppColors.logoViolet,
        AppColors.logoGreen,
        AppColors.logoSky
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppDesign.sectionSpacing) {
                introBlock

                if isLoading {
                    LoadingBlockView(message: "Загружаю калькуляторы…")
                        .padding(.horizontal, AppDesign.cardPadding)
                } else if let loadError {
                    VStack(spacing: 16) {
                        ContentUnavailableView(
                            "Не удалось загрузить",
                            image: "tabler-outline-cloud-off",
                            description: Text(loadError)
                        )
                        Button("Повторить") {
                            self.loadError = nil
                            Task { await load() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 32)
                    .padding(.horizontal, AppDesign.cardPadding)
                } else if catalog.isEmpty {
                    ContentUnavailableView(
                        "Пока нет доступных калькуляторов",
                        image: "tabler-outline-layout-dashboard",
                        description: Text("Скоро добавим новые расчёты.")
                    )
                    .padding(.top, 32)
                    .padding(.horizontal, AppDesign.cardPadding)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Что посчитать сегодня")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.secondaryLabel)
                            .padding(.horizontal, AppDesign.cardPadding)

                        VStack(spacing: 12) {
                            ForEach(Array(catalog.enumerated()), id: \.element.id) { index, item in
                                let accent = Self.accentCycle[index % Self.accentCycle.count]
                                NavigationLink {
                                    DynamicCalculatorView(
                                        calculatorId: item.id,
                                        calculatorsService: calculatorsService,
                                        profileId: profileId
                                    )
                                } label: {
                                    calculatorCard(item: item, accent: accent)
                                }
                                .buttonStyle(PressableButtonStyle(cornerRadius: AppDesign.cornerRadius))
                            }
                        }
                        .padding(.horizontal, AppDesign.cardPadding)
                    }
                }
            }
            .padding(.top, AppDesign.blockSpacing)
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .background(AdaptiveScreenBackground())
        .navigationTitle("Калькуляторы")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var introBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ориентиры за минуту")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppColors.label)
            Text("Подберите калорийность, нормы БЖУ, воду, рабочие веса и другие ориентиры — без таблиц и ручного счёта.")
                .font(.subheadline)
                .foregroundStyle(AppColors.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
            Text("Это не медицинский диагноз: при сомнениях обсудите результат с врачом или тренером.")
                .font(.caption)
                .foregroundStyle(AppColors.tertiaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppDesign.cardPadding)
        .background(
            LinearGradient(
                colors: [AppColors.accent.opacity(0.18), AppColors.logoTeal.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.cornerRadius)
                .stroke(AppColors.accent.opacity(0.22), lineWidth: 1)
        )
        .padding(.horizontal, AppDesign.cardPadding)
    }

    private func calculatorCard(item: CalculatorCatalogItem, accent: Color) -> some View {
        HStack(alignment: .center, spacing: 0) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(accent.opacity(0.95))
                .frame(width: 4)
                .padding(.vertical, 6)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                        .multilineTextAlignment(.leading)

                    let desc = item.description.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !desc.isEmpty {
                        Text(desc)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.secondaryLabel)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)

                AppTablerIcon("chevron-right")
                    .appIcon(.s20)
                    .foregroundStyle(accent.opacity(0.85))
            }
            .padding(.leading, 12)
            .padding(.trailing, 14)
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.cornerRadius)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    private func load() async {
        do {
            await MainActor.run {
                isLoading = true
                loadError = nil
            }
            let items = try await calculatorsService.fetchCatalog()
            await MainActor.run {
                catalog = items.filter(\.isEnabled).sorted { $0.order < $1.order }
                isLoading = false
                loadError = nil
            }
        } catch {
            await MainActor.run {
                isLoading = false
                catalog = []
                loadError = AppErrors.userMessageIfNeeded(for: error) ?? "Не удалось загрузить калькуляторы"
            }
        }
    }
}

#Preview {
    let client = APIClient(baseURL: ApiConfig.baseURL, getIDToken: { _ in nil })
    CalculatorsCatalogView(
        calculatorsService: APICalculatorsService(client: client),
        profileId: "1"
    )
}
