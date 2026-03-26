import SwiftUI

struct CalculatorsCatalogView: View {
    let calculatorsService: CalculatorsServiceProtocol
    let profileId: String?

    @State private var isLoading = true
    @State private var catalog: [CalculatorCatalogItem] = []
    private let columns = [GridItem(.flexible(), spacing: AppDesign.blockSpacing), GridItem(.flexible(), spacing: AppDesign.blockSpacing)]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppDesign.sectionSpacing) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 10) {
                        AppTablerIcon("calculator")
                            .appIcon(.s20)
                            .foregroundStyle(AppColors.accent)
                            .padding(.top, 2)
                        Text("Калькуляторы помогают быстро оценить ориентиры по телу, питанию, воде и тренировочным весам.")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppColors.label)
                    }
                    Text("Результаты носят справочный характер и не заменяют медицинскую консультацию.")
                        .font(.footnote)
                        .foregroundStyle(AppColors.secondaryLabel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppDesign.cardPadding)
                .background(
                    LinearGradient(
                        colors: [AppColors.accent.opacity(0.16), AppColors.accent.opacity(0.05)],
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

                if isLoading {
                    LoadingBlockView(message: "Загружаю калькуляторы…")
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
                    LazyVGrid(columns: columns, spacing: AppDesign.blockSpacing) {
                        ForEach(catalog) { item in
                            NavigationLink {
                                DynamicCalculatorView(
                                    calculatorId: item.id,
                                    calculatorsService: calculatorsService,
                                    profileId: profileId
                                )
                            } label: {
                                RectangularBlockContent(
                                    icon: iconForCalculator(item.id),
                                    title: item.title,
                                    value: shortValueForCalculator(item),
                                    iconColor: AppColors.accent
                                )
                                .rectangularBlockStyle()
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
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

    private func load() async {
        do {
            isLoading = true
            let items = try await calculatorsService.fetchCatalog()
            await MainActor.run {
                catalog = items.filter(\.isEnabled).sorted { $0.order < $1.order }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
            ToastCenter.shared.error(from: error, fallback: "Не удалось загрузить калькуляторы")
        }
    }

    private func iconForCalculator(_ id: String) -> String {
        switch id {
        case "body_fat": return "drop.fill"
        case "bench_1rm": return "figure.strengthtraining.traditional"
        case "bju": return "leaf.fill"
        case "bmi": return "scalemass"
        case "protein_norm": return "bolt.fill"
        case "water_balance": return "drop.degrees.fill"
        default: return "function"
        }
    }

    private func shortValueForCalculator(_ item: CalculatorCatalogItem) -> String? {
        // RectangularBlockContent показывает значение в одну строку — поэтому делаем короткий текст.
        let d = item.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return d.isEmpty ? nil : d
    }
}

#Preview {
    let client = APIClient(baseURL: ApiConfig.baseURL, getIDToken: { _ in nil })
    CalculatorsCatalogView(
        calculatorsService: APICalculatorsService(client: client),
        profileId: "1"
    )
}

