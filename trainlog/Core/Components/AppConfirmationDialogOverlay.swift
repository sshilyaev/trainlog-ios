//
//  AppConfirmationDialogOverlay.swift
//  Глобальное окно для appConfirmationDialog — поверх sheets и прочих презентаций.
//

import SwiftUI
import UIKit

@MainActor
@Observable
final class AppConfirmationDialogModel {
    static let shared = AppConfirmationDialogModel()

    struct Payload {
        let title: String
        let message: String
        let confirmTitle: String
        let confirmRole: ButtonRole?
        /// true — подтверждение, false — отмена (в т.ч. тап по фону).
        let dismiss: (Bool) -> Void
    }

    private(set) var payload: Payload?

    private init() {}

    func present(_ payload: Payload) {
        self.payload = payload
    }

    func clear() {
        payload = nil
    }
}

struct AppConfirmationDialogOverlayHost: View {
    @Bindable private var model = AppConfirmationDialogModel.shared

    private var confirmColor: Color {
        guard let p = model.payload else { return AppColors.accent }
        return p.confirmRole == .destructive ? AppColors.destructive : AppColors.accent
    }

    var body: some View {
        Group {
            if let p = model.payload {
                ZStack {
                    AppColors.overlayScrim
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { p.dismiss(false) }

                    VStack(alignment: .leading, spacing: 14) {
                        Text(p.title)
                            .font(.headline)
                            .foregroundStyle(AppColors.label)

                        Text(p.message)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.secondaryLabel)

                        HStack(spacing: 10) {
                            Button {
                                p.dismiss(false)
                            } label: {
                                Text("Отмена")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                p.dismiss(true)
                            } label: {
                                Text(p.confirmTitle)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(confirmColor)
                        }
                        .padding(.top, 2)
                    }
                    .padding(16)
                    .frame(maxWidth: 360)
                    .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(AppColors.separator.opacity(0.35), lineWidth: 0.5)
                    )
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: model.payload != nil)
    }
}

@MainActor
final class AppConfirmationDialogPresenter {
    static let shared = AppConfirmationDialogPresenter()

    private var overlayWindow: UIWindow?

    private init() {}

    func attachIfNeeded() {
        if overlayWindow != nil { return }
        guard let scene = activeWindowScene() else { return }
        let window = UIWindow(windowScene: scene)
        let host = UIHostingController(rootView: AppConfirmationDialogOverlayHost().ignoresSafeArea())
        host.view.backgroundColor = .clear
        window.rootViewController = host
        window.backgroundColor = .clear
        window.frame = scene.screen.bounds
        window.windowLevel = UIWindow.Level(UIWindow.Level.alert.rawValue + 250)
        window.isHidden = true
        overlayWindow = window
    }

    func present(
        title: String,
        message: String,
        confirmTitle: String,
        confirmRole: ButtonRole?,
        isPresented: Binding<Bool>,
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)?
    ) {
        attachIfNeeded()
        overlayWindow?.isHidden = false

        let payload = AppConfirmationDialogModel.Payload(
            title: title,
            message: message,
            confirmTitle: confirmTitle,
            confirmRole: confirmRole,
            dismiss: { confirmed in
                AppConfirmationDialogPresenter.shared.finishUserChoice(
                    confirmed: confirmed,
                    isPresented: isPresented,
                    onConfirm: onConfirm,
                    onCancel: onCancel
                )
            }
        )
        AppConfirmationDialogModel.shared.present(payload)
    }

    private func finishUserChoice(
        confirmed: Bool,
        isPresented: Binding<Bool>,
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)?
    ) {
        isPresented.wrappedValue = false
        dismissChromeOnly()
        if confirmed {
            onConfirm()
        } else {
            onCancel?()
        }
    }

    /// Сброс только окна (например, когда binding стал false снаружи).
    func dismiss() {
        dismissChromeOnly()
    }

    private func dismissChromeOnly() {
        AppConfirmationDialogModel.shared.clear()
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
