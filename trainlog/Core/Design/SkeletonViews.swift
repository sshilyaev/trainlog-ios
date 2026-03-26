//
//  SkeletonViews.swift
//  TrainLog
//

import SwiftUI

// MARK: - Shimmer

/// Модификатор шиммера: «бегущий свет» по view. Надевать на плейсхолдеры скелетона.
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    let width = geo.size.width * 0.6
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.4),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: width)
                    .offset(x: -width + phase * (geo.size.width + width))
                }
                .mask(content)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func skeletonShimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

/// Мягкое мерцание скелетона: от 100% до 50% раз в секунду.
struct SkeletonBreathModifier: ViewModifier {
    @State private var isDimmed = false

    func body(content: Content) -> some View {
        content
            .opacity(isDimmed ? 0.5 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isDimmed = true
                }
            }
    }
}

extension View {
    func skeletonBreath() -> some View {
        modifier(SkeletonBreathModifier())
    }
}

// MARK: - Базовые блоки скелетона

/// Одна линия (строка текста) скелетона.
struct SkeletonLine: View {
    var width: CGFloat = 120
    var height: CGFloat = 12

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(AppColors.tertiarySystemFill)
            .frame(width: width, height: height)
            .skeletonBreath()
    }
}

/// Прямоугольный блок (карточка, календарь).
struct SkeletonBlock: View {
    var width: CGFloat? = nil
    var height: CGFloat
    var cornerRadius: CGFloat = AppDesign.cornerRadius

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(AppColors.tertiarySystemFill)
            .frame(maxWidth: width ?? .infinity)
            .frame(height: height)
            .skeletonBreath()
    }
}

// MARK: - Скелетон карточки подопечного (ClientCardView)

/// Скелетон экрана карточки подопечного: три секции (действия тренера, о клиенте, просмотр).
struct ClientCardSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                clientCardSectionSkeleton(calendarHeight: 200)
                clientCardSectionSkeleton(calendarHeight: nil)
                clientCardSectionSkeleton(calendarHeight: nil, singleRow: true)
            }
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .background(AdaptiveScreenBackground())
    }

    @ViewBuilder
    private func clientCardSectionSkeleton(calendarHeight: CGFloat?, singleRow: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SkeletonLine(width: 160, height: 16)
            SkeletonLine(width: 260, height: 12)
            if let h = calendarHeight {
                SkeletonBlock(height: h, cornerRadius: 14)
                SkeletonBlock(height: 52, cornerRadius: AppDesign.cornerRadius)
                SkeletonBlock(height: 52, cornerRadius: AppDesign.cornerRadius)
            } else if singleRow {
                SkeletonBlock(height: 72, cornerRadius: AppDesign.cornerRadius)
            } else {
                SkeletonBlock(height: 48, cornerRadius: AppDesign.cornerRadius)
                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { index in
                        HStack(spacing: 12) {
                            SkeletonBlock(width: 28, height: 28, cornerRadius: 14)
                            SkeletonLine(width: 90, height: 12)
                            Spacer()
                            SkeletonLine(width: 60, height: 12)
                        }
                        .padding(.horizontal, AppDesign.cardPadding)
                        .padding(.vertical, 12)
                        if index < 2 {
                            Divider()
                                .padding(.leading, AppDesign.cardPadding + 40)
                        }
                    }
                }
                .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
            }
        }
        .padding(AppDesign.cardPadding)
        .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
        .padding(.horizontal, AppDesign.cardPadding)
        .padding(.top, AppDesign.blockSpacing)
    }
}

// MARK: - Скелетон списка подопечных (CoachMainView)

/// Скелетон списка карточек подопечных: 3–4 карточки с аватаром и строками.
struct TraineeListSkeletonView: View {
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                HStack(spacing: 14) {
                    SkeletonBlock(width: 48, height: 48, cornerRadius: 24)
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonLine(width: 140, height: 14)
                        SkeletonLine(width: 90, height: 10)
                    }
                    Spacer()
                    SkeletonBlock(width: 24, height: 24, cornerRadius: 6)
                }
                .padding(AppDesign.cardPadding)
                .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }
}

/// Скелетон вкладки «Статистика» тренера.
struct CoachStatisticsSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: AppDesign.blockSpacing) {
                SkeletonBlock(height: 110)
                SkeletonBlock(height: 280)
                HStack(spacing: AppDesign.blockSpacing) {
                    SkeletonBlock(height: 88)
                    SkeletonBlock(height: 88)
                }
                HStack(spacing: AppDesign.blockSpacing) {
                    SkeletonBlock(height: 88)
                    SkeletonBlock(height: 88)
                }
                SkeletonBlock(height: 120)
            }
            .padding(.horizontal, AppDesign.cardPadding)
            .padding(.top, AppDesign.blockSpacing)
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .background(AdaptiveScreenBackground())
    }
}

// MARK: - Скелетон календаря и списка (TraineeWorkoutsView)

/// Скелетон экрана «Мой календарь»: блок календаря + строки списка.
struct CalendarAndListSkeletonView: View {
    var body: some View {
        VStack(spacing: 0) {
            SkeletonBlock(height: 180, cornerRadius: 14)
                .padding(.horizontal, AppDesign.cardPadding)
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 12) {
                SkeletonLine(width: 100, height: 14)
                    .padding(.horizontal, AppDesign.cardPadding)
                    .padding(.top, 20)
                ForEach(0..<6, id: \.self) { _ in
                    HStack(spacing: 12) {
                        SkeletonBlock(width: 36, height: 36, cornerRadius: 8)
                        VStack(alignment: .leading, spacing: 4) {
                            SkeletonLine(width: 160, height: 12)
                            SkeletonLine(width: 80, height: 10)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, AppDesign.cardPadding)
                    .padding(.vertical, 10)
                    .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal, AppDesign.cardPadding)
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .frame(maxWidth: .infinity)
        .background(AdaptiveScreenBackground())
    }
}
