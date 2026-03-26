import SwiftUI
import Observation
import UIKit

enum InfoHintPopupSide {
    case left
    case right
}

struct InfoHintPopupItem: Equatable {
    let title: String?
    let message: String
    let anchorRect: CGRect
    let preferredSide: InfoHintPopupSide
    let width: CGFloat
}

@MainActor
@Observable
final class InfoHintPopupCenter {
    static let shared = InfoHintPopupCenter()
    private(set) var item: InfoHintPopupItem?

    private init() {}

    func show(
        title: String? = nil,
        message: String,
        anchorRect: CGRect,
        preferredSide: InfoHintPopupSide = .right,
        width: CGFloat = 260
    ) {
        item = InfoHintPopupItem(
            title: title,
            message: message,
            anchorRect: anchorRect,
            preferredSide: preferredSide,
            width: width
        )
    }

    func hide() {
        item = nil
    }
}

struct InfoHintPopupHost: View {
    @State private var center = InfoHintPopupCenter.shared

    var body: some View {
        if let item = center.item {
            GeometryReader { geo in
                ZStack {
                    AppColors.black.opacity(0.18)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { InfoHintPopupPresenter.shared.hide() }

                    popupCard(item)
                        .frame(width: item.width, alignment: .leading)
                        .position(
                            x: popupX(for: item, screenWidth: geo.size.width),
                            y: popupY(for: item, screenHeight: geo.size.height)
                        )
                }
            }
            .transition(.opacity)
        }
    }

    private func popupCard(_ item: InfoHintPopupItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = item.title, !title.isEmpty {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColors.label)
            }
            Text(item.message)
                .font(.footnote)
                .foregroundStyle(AppColors.label)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppColors.label.opacity(0.08), lineWidth: 1)
        )
    }

    private func popupX(for item: InfoHintPopupItem, screenWidth: CGFloat) -> CGFloat {
        let gap: CGFloat = 12
        let half = item.width / 2
        let minX = half + 12
        let maxX = screenWidth - half - 12
        let rawX: CGFloat
        switch item.preferredSide {
        case .right:
            rawX = item.anchorRect.maxX + gap + half
        case .left:
            rawX = item.anchorRect.minX - gap - half
        }
        return min(max(rawX, minX), maxX)
    }

    private func popupY(for item: InfoHintPopupItem, screenHeight: CGFloat) -> CGFloat {
        min(max(item.anchorRect.midY, 80), max(80, screenHeight - 80))
    }
}

@MainActor
final class InfoHintPopupPresenter {
    static let shared = InfoHintPopupPresenter()

    private var overlayWindow: UIWindow?

    private init() {}

    func attachIfNeeded() {
        if overlayWindow != nil { return }
        guard let scene = activeWindowScene() else { return }
        let window = UIWindow(windowScene: scene)
        let host = UIHostingController(rootView: InfoHintPopupHost().ignoresSafeArea())
        host.view.backgroundColor = .clear
        window.rootViewController = host
        window.backgroundColor = .clear
        window.frame = scene.screen.bounds
        window.windowLevel = .alert + 90
        window.isHidden = true
        overlayWindow = window
    }

    func show(
        title: String? = nil,
        message: String,
        anchorRect: CGRect,
        preferredSide: InfoHintPopupSide = .right,
        width: CGFloat = 260
    ) {
        attachIfNeeded()
        overlayWindow?.isHidden = false
        InfoHintPopupCenter.shared.show(
            title: title,
            message: message,
            anchorRect: anchorRect,
            preferredSide: preferredSide,
            width: width
        )
    }

    func hide() {
        InfoHintPopupCenter.shared.hide()
        overlayWindow?.isHidden = true
    }

    private func activeWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let keyScene = scenes.first(where: { scene in
            scene.windows.contains(where: { $0.isKeyWindow })
        }) {
            return keyScene
        }
        return scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
    }
}
