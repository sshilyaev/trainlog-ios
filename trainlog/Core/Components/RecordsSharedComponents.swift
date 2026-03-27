import SwiftUI

struct RecordsGuideSheet: View {
    let title: String
    let headline: String
    let description: String
    let examples: [RecordsGuideExample]
    let tips: [String]
    let onPrimaryAction: (() -> Void)?
    let primaryActionTitle: String
    let onClose: () -> Void

    var body: some View {
        MainSheet(
            title: "О разделе",
            onBack: onClose,
            trailing: {
                if let onPrimaryAction {
                    Button(primaryActionTitle) { onPrimaryAction() }
                }
            },
            content: {
                ScrollView {
                    VStack(spacing: 12) {
                        HeroCard(
                            icon: "award-medal",
                            title: title,
                            headline: headline,
                            description: description,
                            accent: AppColors.visitsOneTimeDebt
                        )
                        .padding(.horizontal, AppDesign.cardPadding)

                        SettingsCard(title: "Примеры") {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(examples) { ex in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(ex.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(AppColors.label)
                                        Text(ex.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(AppColors.secondaryLabel)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 6)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        SettingsCard(title: "Советы") {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(tips.enumerated()), id: \.offset) { _, tip in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("•")
                                            .foregroundStyle(AppColors.secondaryLabel)
                                        Text(tip)
                                            .font(.subheadline)
                                            .foregroundStyle(AppColors.secondaryLabel)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, AppDesign.blockSpacing)
                    .padding(.bottom, AppDesign.sectionSpacing)
                }
                .background(AdaptiveScreenBackground())
            }
        )
    }
}

struct RecordsSearchSheet: View {
    @Binding var query: String
    let onClose: () -> Void

    var body: some View {
        MainSheet(
            title: "Поиск",
            onBack: onClose,
            content: {
                ScrollView {
                    VStack(spacing: 12) {
                        SettingsCard(title: "Поиск") {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Введите часть названия упражнения, тип или заметку.")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.secondaryLabel)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                TextField("Например: жим, бег, кардио…", text: $query)
                                    .textFieldStyle(.plain)
                                    .formInputStyle()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button(role: .destructive) {
                                query = ""
                            } label: {
                                Text("Очистить поиск")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(AppColors.destructive.opacity(0.12), in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                    .padding(.top, AppDesign.blockSpacing)
                    .padding(.bottom, AppDesign.sectionSpacing)
                }
                .background(AdaptiveScreenBackground())
            }
        )
    }
}

struct RecordsGuideExample: Identifiable {
    var id: String { title + subtitle }
    let title: String
    let subtitle: String
}

struct RecordActivityCatalogPickerSheet: View {
    let title: String
    let activities: [RecordActivity]
    @Binding var selectedSlug: String
    let onClose: () -> Void

    @AppStorage("records.activities.favorites") private var favoritesRaw = ""
    @AppStorage("records.activities.recent") private var recentRaw = ""
    @State private var query = ""
    @State private var selectedTypeFilter: String = "all"

    private var favorites: Set<String> { Set(Self.csv(favoritesRaw)) }
    private var recent: [String] { Self.csv(recentRaw) }

    private var activitiesBySlug: [String: RecordActivity] {
        Dictionary(uniqueKeysWithValues: activities.map { ($0.slug, $0) })
    }

    private var availableTypeFilters: [String] {
        let unique = Set(
            activities
                .compactMap { $0.activityType?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        let sorted = unique.sorted { localizedTypeLabel($0) < localizedTypeLabel($1) }
        return ["all"] + sorted
    }

    private var filteredByType: [RecordActivity] {
        guard selectedTypeFilter != "all" else { return activities }
        return activities.filter {
            ($0.activityType ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == selectedTypeFilter
        }
    }

    private var filteredAll: [RecordActivity] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return filteredByType }
        return filteredByType.filter { a in
            a.name.localizedCaseInsensitiveContains(q)
            || (a.activityType?.localizedCaseInsensitiveContains(q) ?? false)
        }
    }

    private var recentActivities: [RecordActivity] {
        recent.compactMap { activitiesBySlug[$0] }.filter { filteredAll.contains($0) }
    }

    private var favoriteActivities: [RecordActivity] {
        filteredAll.filter { favorites.contains($0.slug) }.sorted { $0.displayOrder < $1.displayOrder }
    }

    var body: some View {
        MainSheet(
            title: title,
            onBack: onClose,
            content: {
                ScrollView {
                    VStack(spacing: 10) {
                        typeFiltersRow

                        if !query.isEmpty, filteredAll.isEmpty {
                            ContentUnavailableView(
                                "Ничего не найдено",
                                image: "tabler-outline-circle-x",
                                description: Text("Попробуйте другой запрос.")
                            )
                        }

                        if query.isEmpty, !recentActivities.isEmpty {
                            sectionCard(title: "Недавние", items: recentActivities)
                        }

                        if !favoriteActivities.isEmpty {
                            sectionCard(title: "Избранные", items: favoriteActivities)
                        }

                        sectionCard(title: query.isEmpty ? "Каталог" : "Результаты", items: filteredAll)
                    }
                    .padding(.top, AppDesign.blockSpacing)
                    .padding(.bottom, AppDesign.sectionSpacing)
                }
                .background(AdaptiveScreenBackground())
                .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Поиск упражнения")
            }
        )
    }

    private var typeFiltersRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableTypeFilters, id: \.self) { filter in
                    let isSelected = selectedTypeFilter == filter
                    Button {
                        selectedTypeFilter = filter
                    } label: {
                        Text(localizedTypeLabel(filter))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isSelected ? AppColors.white : AppColors.label)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                isSelected
                                ? AppColors.accent
                                : AppColors.secondarySystemGroupedBackground,
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        isSelected ? AppColors.accent : AppColors.separator.opacity(0.35),
                                        lineWidth: 0.6
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppDesign.cardPadding)
        }
    }

    private func localizedTypeLabel(_ raw: String) -> String {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "all":
            return "Все"
        case "strength", "силовые":
            return "Силовые"
        case "cardio", "кардио":
            return "Кардио"
        case "endurance", "выносливость":
            return "Выносливость"
        case "mobility", "подвижность":
            return "Подвижность"
        case "gymnastics", "гимнастика":
            return "Гимнастика"
        default:
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return "Без типа" }
            let first = t.prefix(1).uppercased()
            return first + t.dropFirst()
        }
    }

    private func sectionCard(title: String, items: [RecordActivity]) -> some View {
        SettingsCard(title: title) {
            VStack(spacing: 8) {
                ForEach(items) { activity in
                    row(activity)
                }
            }
        }
    }

    private func row(_ activity: RecordActivity) -> some View {
        let isFavorite = favorites.contains(activity.slug)
        return ListActionRow(
            verticalPadding: 10,
            horizontalPadding: 12,
            cornerRadius: AppDesign.cornerRadius,
            isInteractive: true
        ) {
            Button {
                select(activity)
                onClose()
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(activity.name)
                            .foregroundStyle(AppColors.label)
                        if let t = activity.activityType, !t.isEmpty {
                            Text(t)
                                .font(.caption)
                                .foregroundStyle(AppColors.secondaryLabel)
                        }
                    }
                    Spacer()
                    if selectedSlug == activity.slug {
                        Image(systemName: "checkmark")
                            .foregroundStyle(AppColors.accent)
                    }
                }
            }
            .buttonStyle(.plain)
        } trailing: {
            Button {
                toggleFavorite(activity.slug)
            } label: {
                AppTablerIcon(isFavorite ? "star.circle.fill" : "star.circle")
                    .foregroundStyle(isFavorite ? AppColors.accent : AppColors.tertiaryLabel)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavorite ? "Убрать из избранного" : "Добавить в избранное")
        }
    }

    private func select(_ activity: RecordActivity) {
        selectedSlug = activity.slug
        var nextRecent = recent.filter { $0 != activity.slug }
        nextRecent.insert(activity.slug, at: 0)
        nextRecent = Array(nextRecent.prefix(12))
        recentRaw = nextRecent.joined(separator: ",")
    }

    private func toggleFavorite(_ slug: String) {
        var set = favorites
        if set.contains(slug) { set.remove(slug) } else { set.insert(slug) }
        favoritesRaw = Array(set).sorted().joined(separator: ",")
    }

    private static func csv(_ raw: String) -> [String] {
        raw
            .split(separator: ",")
            .map { String($0) }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

