//
//  SplashView.swift
//  TrainLog
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
/// Ресурсы сплеша: выбор делается один раз за процесс, без «переключения» картинок в UI.
private enum SplashScreenAssets {
    /// Кандидаты: `VerticalSplashBackground1_2x` … `VerticalSplashBackground11_2x` (имя imageset),
    /// либо `VerticalSplashBackground1` … `11`, если в каталоге базовое имя, как у @2x-слота.
    static let verticalBackgroundImageName: String? = {
        let order = (1...11).shuffled()
        for i in order {
            let withSuffix = "VerticalSplashBackground\(i)_2x"
            if UIImage(named: withSuffix) != nil { return withSuffix }
            let base = "VerticalSplashBackground\(i)"
            if UIImage(named: base) != nil { return base }
        }
        return nil
    }()
}
#endif

/// Сплеш при запуске. Случайный вертикальный фон (если есть в ассетах) или градиент.
struct SplashView: View {
    @State private var titleOpacity: Double = 0
    @State private var titleScale: CGFloat = 0.5
    @State private var subtitleOpacity: Double = 0
    @State private var subtitleScale: CGFloat = 0.8
    @State private var phraseOpacity: Double = 0
    @State private var phraseScale: CGFloat = 0.5
    @State private var topGlowIntensity: Double = 0

    private static let motivationalPhrases: [String] = [
        "Каждый день — шаг к цели",
        "Сила в постоянстве",
        "Прогресс важнее совершенства",
        "Ты сильнее, чем думаешь",
        "Замерь сегодня — победи завтра",
        "Дисциплина — путь к свободе",
        "Маленькие шаги ведут к большим результатам",
        "Не сдавайся на полпути",
        "Твоё тело — твой проект",
        "Записывай. Анализируй. Расти",
        "Движение — лучшее лекарство",
        "Консистентность побеждает мотивацию",
        "Один шаг в день меняет результат",
        "Сила — в привычке, не в рывках",
        "Сравнивай себя только с собой вчера",
        "Терпение и план важнее скорости",
        "Тело благодарит за каждую тренировку",
        "Цифры не врут — веди дневник",
        "Отдых так же важен, как нагрузка",
        "Начни с малого и не останавливайся",
    ]

    private static let phraseForThisLaunch: String = motivationalPhrases.randomElement() ?? motivationalPhrases[0]

    private var hasVerticalBackground: Bool {
        #if canImport(UIKit)
        SplashScreenAssets.verticalBackgroundImageName != nil
        #else
        false
        #endif
    }

    var body: some View {
        ZStack {
            backgroundLayer

            if !hasVerticalBackground {
                legacyTopGlow
            }

            readabilityOverlay
            textChrome
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            runEntranceAnimations()
        }
        .trackAPIScreen("Запуск")
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        #if canImport(UIKit)
        if let bgName = SplashScreenAssets.verticalBackgroundImageName {
            GeometryReader { proxy in
                ZStack {
                    legacyGradientBackground
                    Image(bgName)
                        .resizable()
                        .scaledToFill()
                        .frame(
                            width: proxy.size.width,
                            height: proxy.size.height,
                            alignment: .center
                        )
                        .clipped()
                        .accessibilityHidden(true)
                }
            }
            .ignoresSafeArea()
        } else {
            legacyGradientBackground
        }
        #else
        legacyGradientBackground
        #endif
    }

    private var legacyGradientBackground: some View {
        AppColors.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack(alignment: .top) {
                    LinearGradient(
                        colors: [AppColors.splashGradientTop, AppColors.splashGradientBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay {
                        Circle()
                            .fill(.white.opacity(0.06))
                            .frame(width: 320, height: 320)
                            .blur(radius: 80)
                            .offset(x: -100, y: -220)
                        Circle()
                            .fill(.black.opacity(0.1))
                            .frame(width: 280, height: 280)
                            .blur(radius: 70)
                            .offset(x: 120, y: 260)
                    }
                }
                .ignoresSafeArea()
            )
    }

    private var legacyTopGlow: some View {
        VStack {
            LinearGradient(
                colors: [
                    .white.opacity(0.80),
                    .white.opacity(0.26),
                    .clear,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 360)
            .blur(radius: 36)
            .blendMode(.screen)
            .opacity(topGlowIntensity)
            Spacer()
        }
        .ignoresSafeArea()
    }

    /// Единый слой читаемости на обеих сплеш-картинках.
    private var readabilityOverlay: some View {
        LinearGradient(
            colors: [
                Color.black.opacity(0.26),
                Color.black.opacity(0.18),
                Color.black.opacity(0.40),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// Название/перевод по центру, цитата отдельно внизу.
    private var textChrome: some View {
        VStack {
            Spacer(minLength: 48)
            VStack(spacing: 8) {
                VStack(spacing: 6) {
                    Text("TrainLog")
                        .fontSystemWithAppExtra(size: 40, weight: .bold, design: .rounded)
                        .foregroundStyle(Color.white)
                        .opacity(titleOpacity)
                        .scaleEffect(titleScale)

                    Text("Дневник тренировок")
                        .fontSystemWithAppExtra(size: 20, weight: .semibold, design: .rounded)
                        .foregroundStyle(Color.white.opacity(0.96))
                        .opacity(subtitleOpacity)
                        .scaleEffect(subtitleScale)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.44))
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .shadow(color: Color.black.opacity(0.45), radius: 6, y: 2)

            Spacer(minLength: 0)

            Text("«\(Self.phraseForThisLaunch)»")
                .appTypography(.caption)
                .foregroundStyle(Color.white.opacity(0.92))
                .opacity(phraseOpacity)
                .scaleEffect(phraseScale)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(15)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(0.44))
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 22)
                .padding(.bottom, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaPadding(.bottom, 6)
    }

    private func runEntranceAnimations() {
        if !hasVerticalBackground {
            withAnimation(.easeInOut(duration: 4.0)) {
                topGlowIntensity = 0.8
            }
        }

        withAnimation(.easeOut(duration: 1.2).delay(0.35)) {
            titleOpacity = 1
            titleScale = 0.8
        }
        withAnimation(.easeOut(duration: 0.28).delay(1.55)) {
            titleScale = 1.0
        }

        withAnimation(.easeOut(duration: 1.2).delay(0.7)) {
            subtitleOpacity = 1
            subtitleScale = 1.0
        }

        withAnimation(.easeOut(duration: 1.2).delay(1.05)) {
            phraseOpacity = 1
            phraseScale = 1.0
        }
    }
}

#Preview {
    SplashView()
}
