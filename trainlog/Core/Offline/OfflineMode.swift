import Foundation
import Combine

@MainActor
final class OfflineMode: ObservableObject {
    static let shared = OfflineMode()

    @Published var isOffline: Bool = false

    private init() {}
}

