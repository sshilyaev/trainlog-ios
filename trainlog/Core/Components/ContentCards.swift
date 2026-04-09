import SwiftUI

// MARK: - Styles for content blocks (not tappable)

/// Обёртка для блока профиля: скруглённый фон + отступы.
struct ActionBlockStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                AppColors.secondarySystemGroupedBackground,
                in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius, style: .continuous)
            )
            .padding(.horizontal, AppDesign.cardPadding)
            .padding(.top, AppDesign.blockSpacing)
    }
}

private struct RectangularBlockStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(minHeight: AppDesign.rectangularBlockMinHeight)
            .background(
                AppColors.secondarySystemGroupedBackground,
                in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius, style: .continuous)
            )
    }
}

extension View {
    func actionBlockStyle() -> some View {
        modifier(ActionBlockStyle())
    }

    /// Прямоугольный блок (плитка): скруглённый фон, минимальная высота.
    func rectangularBlockStyle() -> some View {
        modifier(RectangularBlockStyle())
    }
}

// MARK: - Hero card (colored intro block)

struct HeroCard<FooterContent: View>: View {
    enum Decoration {
        case none
        /// Лёгкие мягкие пятна/блики как в «Прогресс».
        case glow
    }

    let icon: String
    let title: String
    let headline: String
    let description: String
    var accent: Color = AppColors.accent
    var decoration: Decoration = .none
    @ViewBuilder var footerContent: () -> FooterContent

    init(
        icon: String,
        title: String,
        headline: String,
        description: String,
        accent: Color = AppColors.accent,
        decoration: Decoration = .none,
        @ViewBuilder footerContent: @escaping () -> FooterContent = { EmptyView() }
    ) {
        self.icon = icon
        self.title = title
        self.headline = headline
        self.description = description
        self.accent = accent
        self.decoration = decoration
        self.footerContent = footerContent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                AppTablerIcon(icon)
                    .font(.title3)
                    .foregroundStyle(accent)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(headline)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)

            if !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            footerContent()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppDesign.cardPadding)
        .background {
            background
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerRadius, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.cornerRadius, style: .continuous)
                .stroke(accent.opacity(0.20), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var background: some View {
        let base = LinearGradient(
            colors: [accent.opacity(0.14), accent.opacity(0.045)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        if decoration == .glow {
            ZStack {
                base
                Circle()
                    .fill(accent.opacity(0.16))
                    .frame(width: 120, height: 120)
                    .blur(radius: 18)
                    .offset(x: 90, y: -54)
                Circle()
                    .fill(AppColors.profileAccent.opacity(0.12))
                    .frame(width: 140, height: 140)
                    .blur(radius: 22)
                    .offset(x: -110, y: 62)
            }
        } else {
            base
        }
    }
}

/// Карточка с хедером (заголовок + описание) и произвольным контентом.
/// Хедер отделяется лёгким разделителем. Справа может быть декоративная иконка или кнопка действия.
struct ContentCard<Content: View>: View {
    enum Trailing {
        case icon(String)
        case action(icon: String, action: () -> Void)
    }

    let title: String
    let description: String
    var trailing: Trailing? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        // Не используем `SettingsCard`, чтобы акцентный бордер был именно на белой области карточки.
        VStack(alignment: .leading, spacing: AppDesign.rowSpacing) {
            VStack(alignment: .leading, spacing: 8) {
                header

                Rectangle()
                    .fill(AppColors.tertiarySystemFill.opacity(0.55))
                    .frame(height: 0.8)

                VStack(spacing: 0) {
                    content()
                }
            }
            .padding(AppDesign.cardPadding)
            .background(
                AppColors.secondarySystemGroupedBackground,
                in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius, style: .continuous)
            )
            .overlay(accentCornerBorder)
        }
        .padding(.horizontal, AppDesign.cardPadding)
        .padding(.top, AppDesign.blockSpacing)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColors.label)

                if !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.secondaryLabel)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let trailing {
                trailingView(trailing)
            }
        }
        .padding(.bottom, 2)
    }

    @Environment(\.colorScheme) private var colorScheme

    private var accentCornerBorder: some View {
        let strokeOpacity: CGFloat = (colorScheme == .light ? 0.55 : 0.30)
        let stroke = RoundedRectangle(cornerRadius: AppDesign.cornerRadius, style: .continuous)
            .strokeBorder(AppColors.accent.opacity(strokeOpacity), lineWidth: 1)

        return ZStack {
            stroke.mask(
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(
                            RadialGradient(
                                stops: [
                                    .init(color: AppColors.white.opacity(0.70), location: 0.0),
                                    .init(color: AppColors.white.opacity(0.35), location: 0.40),
                                    .init(color: AppColors.clear, location: 1.0),
                                ],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 140
                            )
                        )
                        .frame(height: 76)
                    Spacer(minLength: 0)
                }
            )
        }
    }

    @ViewBuilder
    private func trailingView(_ trailing: Trailing) -> some View {
        switch trailing {
        case .icon(let name):
            AppTablerIcon(name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.secondaryLabel.opacity(0.85))
                .frame(width: 28, height: 28)
        case .action(icon: let icon, action: let action):
            Button(action: action) {
                AppTablerIcon(icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryLabel)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

/// Упрощённая карточка: в хедере только заголовок, контент — любой (любое количество элементов).
struct SimpleContentCard<Content: View>: View {
    enum Trailing {
        case icon(String)
        case action(icon: String, action: () -> Void)
    }

    let title: String
    var trailing: Trailing? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.rowSpacing) {
            VStack(alignment: .leading, spacing: 8) {
                header

                Rectangle()
                    .fill(AppColors.tertiarySystemFill.opacity(0.55))
                    .frame(height: 0.8)

                VStack(spacing: 0) {
                    content()
                }
            }
            .padding(AppDesign.cardPadding)
            .background(
                AppColors.secondarySystemGroupedBackground,
                in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius, style: .continuous)
            )
            .overlay(accentCornerBorder)
        }
        .padding(.horizontal, AppDesign.cardPadding)
        .padding(.top, AppDesign.blockSpacing)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.label)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let trailing {
                trailingView(trailing)
            }
        }
        .padding(.bottom, 2)
    }

    @Environment(\.colorScheme) private var colorScheme

    private var accentCornerBorder: some View {
        let strokeOpacity: CGFloat = (colorScheme == .light ? 0.55 : 0.30)
        let stroke = RoundedRectangle(cornerRadius: AppDesign.cornerRadius, style: .continuous)
            .strokeBorder(AppColors.accent.opacity(strokeOpacity), lineWidth: 1)

        return ZStack {
            stroke.mask(
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(
                            RadialGradient(
                                stops: [
                                    .init(color: .white.opacity(0.70), location: 0.0),
                                    .init(color: .white.opacity(0.35), location: 0.40),
                                    .init(color: .clear, location: 1.0),
                                ],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 140
                            )
                        )
                        .frame(height: 76)
                    Spacer(minLength: 0)
                }
            )
        }
    }

    @ViewBuilder
    private func trailingView(_ trailing: Trailing) -> some View {
        switch trailing {
        case .icon(let name):
            AppTablerIcon(name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.secondaryLabel.opacity(0.85))
                .frame(width: 28, height: 28)
        case .action(icon: let icon, action: let action):
            Button(action: action) {
                AppTablerIcon(icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryLabel)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

/// Вариант карточки для ровно одного элемента контента.
/// Сверху — только заголовок, затем один элемент контента, затем футер-описание.
struct SingleContentCard<Content: View>: View {
    let title: String
    let description: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        SimpleContentCard(title: title, trailing: nil) {
            content()

            if !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            }
        }
    }
}

