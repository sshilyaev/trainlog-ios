import SwiftUI

struct OfflineSticker: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("ОФЛАЙН")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(Color.gray.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .rotationEffect(.degrees(-90))

            Text("Данные\nмогут быть\nустаревшими")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Офлайн режим. Данные могут быть устаревшими.")
    }
}

