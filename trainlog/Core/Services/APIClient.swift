//
//  APIClient.swift
//  TrainLog
//

import Foundation

/// Ошибка ответа API (4xx/5xx). Поля из тела ответа: `error`, `message`, `messages`, `code`.
struct APIResponseError: Error {
    let statusCode: Int
    /// Из JSON: поле "error"
    let errorMessage: String?
    /// Из JSON: поле "message" (одна строка от бэкенда)
    let backendMessage: String?
    /// Из JSON: поле "messages" (массив строк валидации)
    let validationMessages: [String]
    /// Из JSON: поле "code" (например measurement_not_found)
    let backendCode: String?

    /// Сообщение для UI: объединяет error + message + validation от бэкенда.
    var userMessage: String {
        // Подсказка при 404 «замер не найден» (замер мог быть создан в Firestore или на другом сервере).
        if statusCode == 404, backendCode == "measurement_not_found" {
            return "Замер не найден на сервере. Обновите список замеров"
        }
        var parts: [String] = []
        if let s = errorMessage, !s.isEmpty { parts.append(s) }
        if let s = backendMessage, !s.isEmpty, s != errorMessage { parts.append(s) }
        if !validationMessages.isEmpty { parts.append(validationMessages.joined(separator: "\n")) }
        if !parts.isEmpty { return parts.joined(separator: "\n") }
        switch statusCode {
        case 401: return "Сессия истекла. Войдите снова"
        case 404: return "Данные не найдены"
        case 500...599: return "Сервис временно недоступен. Попробуйте позже"
        default: return "Что-то пошло не так. Попробуйте позже"
        }
    }
}

/// Общий HTTP-клиент к REST API: Base URL, Bearer-токен, JSON, разбор ошибок.
/// При 401 повторяет запрос один раз с принудительно обновлённым токеном.
final class APIClient {
    private let baseURL: URL
    private let getIDToken: (_ forceRefresh: Bool) async -> String?
    private let responseCache = ResponseCache()

    init(baseURL: URL, getIDToken: @escaping (_ forceRefresh: Bool) async -> String?) {
        self.baseURL = baseURL
        self.getIDToken = getIDToken
    }

    /// Очищает runtime-кэш ответов API (вызывать при смене аккаунта).
    func clearRuntimeCache() async {
        await responseCache.clearAll()
    }

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            // ISO8601 date-time
            if let date = ISO8601DateFormatter.fullFractional.date(from: raw) { return date }
            if let date = ISO8601DateFormatter().date(from: raw) { return date }
            // date-only YYYY-MM-DD
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            fmt.locale = Locale(identifier: "en_US_POSIX")
            if let date = fmt.date(from: raw) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(raw)")
        }
        return d
    }

    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            fmt.locale = Locale(identifier: "en_US_POSIX")
            try container.encode(fmt.string(from: date))
        }
        return e
    }

    /// Для ответов с date-time в теле (createdAt и т.д.) используем отдельный decoder с ISO8601.
    private var decoderWithDateTime: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = ISO8601DateFormatter.fullFractional.date(from: raw) { return date }
            if let date = ISO8601DateFormatter().date(from: raw) { return date }
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            fmt.locale = Locale(identifier: "en_US_POSIX")
            if let date = fmt.date(from: raw) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(raw)")
        }
        return d
    }

    func request<T: Decodable>(
        path: String,
        method: String = "GET",
        query: [String: String]? = nil,
        useDateTimeDecoder: Bool = true
    ) async throws -> T {
        let (data, _) = try await perform(path: path, method: method, query: query, body: nil as AnyEncodable?)
        let dec = useDateTimeDecoder ? decoderWithDateTime : decoder
        return try dec.decode(T.self, from: data)
    }

    func request<T: Decodable, B: Encodable>(
        path: String,
        method: String = "GET",
        query: [String: String]? = nil,
        body: B,
        useDateTimeDecoder: Bool = true
    ) async throws -> T {
        let (data, _) = try await perform(path: path, method: method, query: query, body: AnyEncodable(body))
        let dec = useDateTimeDecoder ? decoderWithDateTime : decoder
        return try dec.decode(T.self, from: data)
    }

    /// Запрос с телом из словаря (обход EXC_BAD_ACCESS при кодировании Encodable с повреждёнными полями).
    func request<T: Decodable>(
        path: String,
        method: String = "GET",
        query: [String: String]? = nil,
        jsonBody: [String: Any],
        useDateTimeDecoder: Bool = true
    ) async throws -> T {
        let (data, _) = try await perform(path: path, method: method, query: query, body: nil, jsonBody: jsonBody)
        let dec = useDateTimeDecoder ? decoderWithDateTime : decoder
        return try dec.decode(T.self, from: data)
    }

    /// Выполняет запрос и возвращает сырые данные и ответ (для случаев, когда нужно проверить statusCode или пустое тело при 201).
    func requestRaw(
        path: String,
        method: String = "GET",
        query: [String: String]? = nil,
        jsonBody: [String: Any]? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        try await perform(path: path, method: method, query: query, body: nil as AnyEncodable?, jsonBody: jsonBody)
    }

    /// Запрос без тела ответа (204 No Content).
    func requestNoContent(
        path: String,
        method: String = "DELETE",
        query: [String: String]? = nil
    ) async throws {
        _ = try await perform(path: path, method: method, query: query, body: nil as AnyEncodable?)
    }

    /// Запрос без тела ответа, с телом запроса.
    func requestNoContent<B: Encodable>(
        path: String,
        method: String = "DELETE",
        query: [String: String]? = nil,
        body: B
    ) async throws {
        _ = try await perform(path: path, method: method, query: query, body: AnyEncodable(body))
    }

    private func perform(
        path: String,
        method: String,
        query: [String: String]?,
        body: AnyEncodable?,
        jsonBody: [String: Any]? = nil,
        isRetryAfter401: Bool = false
    ) async throws -> (Data, HTTPURLResponse) {
        let forceRefresh = isRetryAfter401
        guard let token = await getIDToken(forceRefresh) else {
            throw APIResponseError(statusCode: 401, errorMessage: "Не авторизован", backendMessage: nil, validationMessages: [], backendCode: nil)
        }

        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)!
        if let q = query, !q.isEmpty {
            components.queryItems = q
                .map { URLQueryItem(name: $0.key, value: $0.value) }
                .sorted { lhs, rhs in
                    if lhs.name != rhs.name { return lhs.name < rhs.name }
                    return (lhs.value ?? "") < (rhs.value ?? "")
                }
        }
        guard let url = components.url else {
            throw APIResponseError(statusCode: 0, errorMessage: "Неверный URL", backendMessage: nil, validationMessages: [], backendCode: nil)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let dict = jsonBody {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: dict)
            } catch {
                throw error
            }
        } else if let b = body {
            do {
                request.httpBody = try encoder.encode(b)
            } catch {
                throw error
            }
        }

        let normalizedMethod = method.uppercased()
        let cacheKey = cacheKeyForRequest(
            method: normalizedMethod,
            url: url,
            hasBody: body != nil || jsonBody != nil,
            isRetryAfter401: isRetryAfter401
        )

        // Дедуп и короткий кэш для одинаковых GET-запросов.
        if let cacheKey {
            if let cached = await responseCache.cachedResponse(for: cacheKey) {
                APIRequestLog.log(path: path, method: normalizedMethod, query: query, source: .cache)
                return cached
            }
            if let existingTask = await responseCache.inFlightTask(for: cacheKey) {
                let joined = try await existingTask.value
                APIRequestLog.log(path: path, method: normalizedMethod, query: query, source: .inFlightJoin)
                return joined
            }
            let task = Task { try await self.performNetwork(
                request: request,
                path: path,
                method: method,
                query: query,
                body: body,
                jsonBody: jsonBody,
                isRetryAfter401: isRetryAfter401,
                url: url
            ) }
            await responseCache.setInFlight(task, for: cacheKey)
            do {
                let result = try await task.value
                await responseCache.removeInFlight(for: cacheKey)
                await responseCache.storeResponse(result, for: cacheKey)
                APIRequestLog.log(path: path, method: normalizedMethod, query: query, source: .network)
                return result
            } catch {
                await responseCache.removeInFlight(for: cacheKey)
                throw error
            }
        }

        let result = try await performNetwork(
            request: request,
            path: path,
            method: method,
            query: query,
            body: body,
            jsonBody: jsonBody,
            isRetryAfter401: isRetryAfter401,
            url: url
        )
        if shouldInvalidateCache(afterMethod: normalizedMethod) {
            await responseCache.clearAll()
        }
        APIRequestLog.log(path: path, method: normalizedMethod, query: query, source: .network)
        return result
    }

    private func performNetwork(
        request: URLRequest,
        path: String,
        method: String,
        query: [String: String]?,
        body: AnyEncodable?,
        jsonBody: [String: Any]?,
        isRetryAfter401: Bool,
        url: URL
    ) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw error
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIResponseError(statusCode: 0, errorMessage: "Некорректный ответ", backendMessage: nil, validationMessages: [], backendCode: nil)
        }

        if (200...299).contains(http.statusCode) {
            return (data, http)
        }

        // При 401 пробуем один раз с обновлённым токеном (если ещё не ретрай)
        if http.statusCode == 401, !isRetryAfter401 {
            return try await perform(path: path, method: method, query: query, body: body, jsonBody: jsonBody, isRetryAfter401: true)
        }

        var errorMessage: String?
        var backendMessage: String?
        var validationMessages: [String] = []
        var backendCode: String?
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            errorMessage = json["error"] as? String
            backendMessage = json["message"] as? String
            backendCode = json["code"] as? String
            if let msgs = json["messages"] as? [String] {
                validationMessages = msgs
            }
        }
        let apiError = APIResponseError(
            statusCode: http.statusCode,
            errorMessage: errorMessage,
            backendMessage: backendMessage,
            validationMessages: validationMessages,
            backendCode: backendCode
        )
        throw apiError
    }

    private func cacheKeyForRequest(
        method: String,
        url: URL,
        hasBody: Bool,
        isRetryAfter401: Bool
    ) -> String? {
        guard method == "GET", !hasBody, !isRetryAfter401 else { return nil }
        return "\(method) \(url.absoluteString)"
    }

    private func shouldInvalidateCache(afterMethod method: String) -> Bool {
        switch method {
        case "POST", "PATCH", "PUT", "DELETE":
            return true
        default:
            return false
        }
    }
}

// MARK: - Helpers

struct AnyEncodable: Encodable {
    let value: any Encodable
    init(_ value: some Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}

extension ISO8601DateFormatter {
    static let fullFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

private actor ResponseCache {
    struct CacheEntry {
        let data: Data
        let response: HTTPURLResponse
        let expiresAt: Date
    }

    private var entries: [String: CacheEntry] = [:]
    private var inFlight: [String: Task<(Data, HTTPURLResponse), Error>] = [:]
    private let ttl: TimeInterval = 30

    func cachedResponse(for key: String) -> (Data, HTTPURLResponse)? {
        guard let entry = entries[key] else { return nil }
        if entry.expiresAt <= Date() {
            entries.removeValue(forKey: key)
            return nil
        }
        return (entry.data, entry.response)
    }

    func storeResponse(_ response: (Data, HTTPURLResponse), for key: String) {
        entries[key] = CacheEntry(data: response.0, response: response.1, expiresAt: Date().addingTimeInterval(ttl))
    }

    func inFlightTask(for key: String) -> Task<(Data, HTTPURLResponse), Error>? {
        inFlight[key]
    }

    func setInFlight(_ task: Task<(Data, HTTPURLResponse), Error>, for key: String) {
        inFlight[key] = task
    }

    func removeInFlight(for key: String) {
        inFlight.removeValue(forKey: key)
    }

    func clearAll() {
        entries.removeAll()
        inFlight.removeAll()
    }
}
