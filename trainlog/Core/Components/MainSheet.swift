import SwiftUI

enum MainSheetPresentation {
    /// По умолчанию: стартует в `.medium`, можно раскрыть до `.large`.
    case half
    /// Сразу на весь экран снизу (`.large`).
    case full
    /// Календарь/выбор даты.
    case calendar
    /// Небольшой фиксированный щит.
    case small
    /// Полный контроль над detents.
    case detents(Set<PresentationDetent>)

    var detents: Set<PresentationDetent> {
        switch self {
        case .half:
            return AppSheetDetents.mediumOnly
        case .full:
            return [.large]
        case .calendar:
            return AppSheetDetents.calendar
        case .small:
            return AppSheetDetents.small
        case .detents(let set):
            return set
        }
    }
}

extension View {
    /// Единый стиль шита: detents + drag indicator + corner radius + background interaction policy.
    func mainSheetPresentation(_ style: MainSheetPresentation = .half, allowBackgroundInteraction: Bool = false) -> some View {
        self
            .presentationDetents(style.detents)
            .presentationDragIndicator(.visible)
            .sheetPresentationStyle(allowBackgroundInteraction: allowBackgroundInteraction)
    }

    /// То же самое, но с управляемым `selection` для detents.
    func mainSheetPresentation(
        _ style: MainSheetPresentation = .half,
        selection: Binding<PresentationDetent>,
        allowBackgroundInteraction: Bool = false
    ) -> some View {
        self
            .presentationDetents(style.detents, selection: selection)
            .presentationDragIndicator(.visible)
            .sheetPresentationStyle(allowBackgroundInteraction: allowBackgroundInteraction)
    }
}

struct MainSheet<Trailing: View, Content: View>: View {
    let title: String
    let onBack: () -> Void
    @ViewBuilder let trailing: () -> Trailing
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        onBack: @escaping () -> Void,
        @ViewBuilder trailing: @escaping () -> Trailing,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.onBack = onBack
        self.trailing = trailing
        self.content = content
    }

    init(
        title: String,
        onBack: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) where Trailing == EmptyView {
        self.title = title
        self.onBack = onBack
        self.trailing = { EmptyView() }
        self.content = content
    }

    var body: some View {
        NavigationStack {
            content()
                .navigationBarHidden(true)
                .safeAreaInset(edge: .top) {
                    mainSheetTopBar
                }
        }
    }

    private var mainSheetTopBar: some View {
        let sideMinWidth: CGFloat = 78

        return HStack(alignment: .center, spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Label("Назад", appIcon: "chevron-left")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColors.label)
                }
            }
            .frame(minWidth: sideMinWidth, alignment: .leading)

            Text(title)
                .appTypography(.bodyEmphasis)
                .foregroundStyle(AppColors.label)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 8) {
                trailing()
            }
            .frame(minWidth: sideMinWidth, alignment: .trailing)
        }
        .frame(minHeight: 56)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AppColors.systemGroupedBackground)
        .overlay(alignment: .bottom) {
            Divider()
                .opacity(0.5)
        }
    }
}

