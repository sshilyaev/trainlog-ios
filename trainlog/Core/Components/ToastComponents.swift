import SwiftUI
import Observation
import UIKit

enum ToastKind: Equatable {
    case success
    case error
    case warning
    case info

    var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var iconForeground: Color {
        switch self {
        case .success: return AppColors.accent
        case .error: return AppColors.destructive
        case .warning: return Color(.systemOrange)
        case .info: return Color(.systemBlue)
        }
    }

    var iconBackground: Color {
        iconForeground.opacity(0.14)
    }

    var containerBorder: Color {
        iconForeground.opacity(0.35)
    }

    var containerBackground: Color {
        AppColors.secondarySystemGroupedBackground
    }

    var defaultTitle: String {
        switch self {
        case .success: return "Готово"
        case .error: return "Ошибка"
        case .warning: return "Внимание"
        case .info: return "Информация"
        }
    }
}

struct ToastModel: Identifiable, Equatable {
    let id: UUID
    let kind: ToastKind
    let title: String
    let message: String
    let createdAt: Date

    init(kind: ToastKind, title: String? = nil, message: String, createdAt: Date = Date()) {
        self.id = UUID()
        self.kind = kind
        self.title = title ?? kind.defaultTitle
        self.message = message
        self.createdAt = createdAt
    }
}

@MainActor
@Observable
final class ToastCenter {
    static let shared = ToastCenter()

    private(set) var toasts: [ToastModel] = []
    private var dismissTasks: [UUID: Task<Void, Never>] = [:]
    private let maxToasts = 3
    private let defaultDuration: TimeInterval = 2.5

    private init() {}

    func show(kind: ToastKind, title: String? = nil, message: String, duration: TimeInterval? = nil) {
        let toast = ToastModel(kind: kind, title: title, message: message)
        toasts.append(toast)

        if toasts.count > maxToasts {
            let overflowCount = toasts.count - maxToasts
            if overflowCount > 0 {
                let removed = toasts.prefix(overflowCount)
                for t in removed {
                    dismissTasks[t.id]?.cancel()
                    dismissTasks[t.id] = nil
                }
                toasts.removeFirst(overflowCount)
            }
        }

        let task = Task { [weak self, defaultDuration = self.defaultDuration] in
            let sleepMs = UInt64(((duration ?? defaultDuration) * 1000).rounded())
            try? await Task.sleep(nanoseconds: sleepMs * 1_000_000)
            await MainActor.run {
                self?.hide(toastId: toast.id)
            }
        }
        dismissTasks[toast.id] = task
    }

    func hide(toastId: UUID) {
        dismissTasks[toastId]?.cancel()
        dismissTasks[toastId] = nil
        toasts.removeAll { $0.id == toastId }
    }

    func hideAll() {
        for (_, t) in dismissTasks {
            t.cancel()
        }
        dismissTasks = [:]
        toasts.removeAll()
    }

    func success(_ message: String, title: String? = nil) {
        show(kind: .success, title: title, message: message)
    }

    func error(_ message: String, title: String? = nil) {
        show(kind: .error, title: title, message: message)
    }

    func warning(_ message: String, title: String? = nil) {
        show(kind: .warning, title: title, message: message)
    }

    func info(_ message: String, title: String? = nil) {
        show(kind: .info, title: title, message: message)
    }

    func error(from error: Error, fallback: String) {
        let message = AppErrors.userMessageIfNeeded(for: error) ?? fallback
        show(kind: .error, message: message)
    }
}

struct ToastHost: View {
    @State private var toastCenter = ToastCenter.shared

    var body: some View {
        ZStack(alignment: .top) {
            GeometryReader { geo in
                Color.clear
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            VStack(spacing: 8) {
                ForEach(toastCenter.toasts) { toast in
                    ToastView(
                        toast: toast,
                        onClose: { toastCenter.hide(toastId: toast.id) }
                    )
                    .onTapGesture {
                        toastCenter.hide(toastId: toast.id)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(maxWidth: 560)
            .padding(.top, 72)
            .padding(.horizontal, 12)
            .animation(.spring(response: 0.24, dampingFraction: 0.9), value: toastCenter.toasts)
            .allowsHitTesting(true)
        }
        .zIndex(250)
    }
}

@MainActor
final class ToastOverlayPresenter {
    static let shared = ToastOverlayPresenter()

    private var overlayWindow: PassthroughWindow?

    private init() {}

    func attachIfNeeded() {
        if overlayWindow != nil { return }
        guard let scene = Self.activeWindowScene() else { return }

        let window = PassthroughWindow(windowScene: scene)
        let host = UIHostingController(rootView: ToastHost().ignoresSafeArea())
        host.view.backgroundColor = .clear
        window.rootViewController = host
        window.backgroundColor = .clear
        // Always use full-screen coordinates so toast position does not get tied to sheet bounds.
        window.frame = scene.screen.bounds
        window.windowLevel = .alert + 100
        window.isHidden = false
        overlayWindow = window
    }

    private static func activeWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        if let keyWindowScene = scenes.first(where: { scene in
            scene.windows.contains(where: { $0.isKeyWindow })
        }) {
            return keyWindowScene
        }
        return scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
    }
}

final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        if let root = rootViewController?.view, view === root {
            return nil
        }
        return view
    }
}

private struct ToastView: View {
    let toast: ToastModel
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(toast.kind.iconForeground)
                .frame(width: 4)

            HStack(alignment: .top, spacing: 8) {
                AppTablerIcon(toast.kind.iconName)
                    .appIcon(.s14, weight: .bold)
                    .foregroundStyle(toast.kind.iconForeground)
                    .frame(width: 22, height: 22)
                    .background(toast.kind.iconBackground, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(toast.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppColors.label)
                    Text(toast.message)
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Button(action: onClose) {
                    AppTablerIcon("multiple-cross-cancel-square")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppColors.secondaryLabel)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .allowsHitTesting(true)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(toast.kind.containerBackground.opacity(0.88), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(toast.kind.containerBorder, lineWidth: 1)
        )
        .fixedSize(horizontal: false, vertical: true)
    }
}

