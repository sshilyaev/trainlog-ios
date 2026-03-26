//
//  SplashView.swift
//  TrainLog
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Сплеш при запуске. Лого, анимация, случайная мотивирующая фраза внизу.
struct SplashView: View {
    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.70
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 10
    @State private var taglineOpacity: Double = 0
    @State private var phraseOpacity: Double = 0
    @State private var topGlowIntensity: Double = 0
    @State private var usePlaceholder = false
    @State private var splashImageName = "SplashLogo"
    @State private var motivationalPhrase: String = ""

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

    var body: some View {
        ZStack {
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

            // Явное верхнее свечение поверх фона (но под контентом)
            VStack {
                LinearGradient(
                    colors: [
                        .white.opacity(0.80),
                        .white.opacity(0.26),
                        .clear
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

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                Group {
                    if usePlaceholder {
                        AppTablerIcon("user-default")
                            .appIcon(.s44, weight: .medium)
                            .foregroundStyle(.white.opacity(0.95))
                    } else {
                        Image(splashImageName)
                            .resizable()
                            .scaledToFit()
                    }
                }
                .frame(maxWidth: 240, maxHeight: 200)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                Text("TrainLog")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                    .opacity(titleOpacity)
                    .offset(y: titleOffset)
                    .padding(.top, 28)

                Text("Дневник тренировок")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.88))
                    .opacity(taglineOpacity)
                    .padding(.top, 6)

                Spacer(minLength: 0)

                Text(motivationalPhrase)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .opacity(phraseOpacity)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 44)
            }
            .padding(.horizontal, 48)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            motivationalPhrase = Self.motivationalPhrases.randomElement() ?? Self.motivationalPhrases[0]
            #if canImport(UIKit)
            let names = ["SplashLogo", "Logo", "splash_logo"]
            usePlaceholder = names.allSatisfy { UIImage(named: $0) == nil }
            if let found = names.first(where: { UIImage(named: $0) != nil }) {
                splashImageName = found
            }
            #endif
            // Свечение сверху: в течение всего сплеша становится ярче (до 80%).
            withAnimation(.easeInOut(duration: 4.0)) {
                topGlowIntensity = 0.8
            }
            // Логотип: появляется и увеличивается 0.70 → 1.10 за 2s, потом 1.10 → 1.00 за 1s.
            withAnimation(.easeOut(duration: 0.35)) { logoOpacity = 1 }
            withAnimation(.easeInOut(duration: 2.0)) { logoScale = 1.10 }
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run {
                    withAnimation(.easeOut(duration: 1.0)) {
                        logoScale = 1.00
                    }
                }
            }
            // TrainLog и цитата: старт через 0.5s и не быстро.
            withAnimation(.easeOut(duration: 1.2).delay(0.5)) {
                titleOpacity = 1
                titleOffset = 0
            }
            withAnimation(.easeOut(duration: 1.4).delay(0.5)) {
                phraseOpacity = 1
            }
            // Подзаголовок: показ через 1 секунду и медленнее.
            withAnimation(.easeOut(duration: 1.6).delay(1.0)) {
                taglineOpacity = 1
            }
        }
        .trackAPIScreen("Запуск")
    }
}

#Preview {
    SplashView()
}
