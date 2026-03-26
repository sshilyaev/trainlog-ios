//
//  APIScreenContext.swift
//  TrainLog
//

import Foundation
import SwiftUI

/// Стек имён экранов для логов API (push в `onAppear`, pop в `onDisappear`).
enum APIScreenContext {
    private static let lock = NSLock()
    private static var stack: [String] = []

    static var currentLabel: String {
        lock.lock()
        defer { lock.unlock() }
        return stack.last ?? "—"
    }

    static func push(_ name: String) {
        lock.lock()
        stack.append(name)
        lock.unlock()
    }

    static func pop() {
        lock.lock()
        _ = stack.popLast()
        lock.unlock()
    }
}

/// Одна строка на успешный запрос: экран, метод, путь и query.
enum APIRequestLog {
    enum Source {
        case network
        case cache
        case inFlightJoin
    }

    private static let lock = NSLock()
    private static var countersByEndpoint: [String: (net: Int, cache: Int, join: Int)] = [:]

    static func log(path: String, method: String, query: [String: String]?, source: Source) {
        let screen = APIScreenContext.currentLabel
        let methodU = method.uppercased()
        let screenPart: String
        let tag: String
        switch source {
        case .network:
            screenPart = "\(screen)"
            tag = "NET"
        case .cache:
            screenPart = "\(screen) (кеш)"
            tag = "CACHE"
        case .inFlightJoin:
            screenPart = "\(screen) (ожидание)"
            tag = "JOIN"
        }
        bumpCounter(method: methodU, path: path, source: source)
        _ = query
        print("[TrainLog][\(tag)] \(screenPart) \(methodU): \(path)")
    }

    #if DEBUG
    static func debugSnapshot() -> [String: (net: Int, cache: Int, join: Int)] {
        lock.lock()
        defer { lock.unlock() }
        return countersByEndpoint
    }
    #endif

    private static func bumpCounter(method: String, path: String, source: Source) {
        let key = "\(method) \(path)"
        lock.lock()
        var current = countersByEndpoint[key] ?? (0, 0, 0)
        switch source {
        case .network: current.net += 1
        case .cache: current.cache += 1
        case .inFlightJoin: current.join += 1
        }
        countersByEndpoint[key] = current
        lock.unlock()
    }

}

private struct APIScreenTrackingModifier: ViewModifier {
    let name: String

    func body(content: Content) -> some View {
        content
            .onAppear { APIScreenContext.push(name) }
            .onDisappear { APIScreenContext.pop() }
    }
}

extension View {
    /// Помечает текущий экран для строк лога API (`Экран. METHOD: path | query`).
    func trackAPIScreen(_ name: String) -> some View {
        modifier(APIScreenTrackingModifier(name: name))
    }
}
