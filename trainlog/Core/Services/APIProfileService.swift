//
//  APIProfileService.swift
//  TrainLog
//

import Foundation

@MainActor
final class APIProfileService: ProfileServiceProtocol {
    private let client: APIClient
    private var profileCache: [String: (profile: Profile, expiresAt: Date)] = [:]
    private let profileCacheTTL: TimeInterval = 30

    init(client: APIClient) {
        self.client = client
    }

    convenience init(baseURL: URL, getIDToken: @escaping (_ forceRefresh: Bool) async -> String?) {
        self.init(client: APIClient(baseURL: baseURL, getIDToken: getIDToken))
    }

    func fetchProfiles(userId: String) async throws -> [Profile] {
        struct ListResponse: Decodable {
            let profiles: [Profile]
        }
        let res: ListResponse = try await client.request(path: "api/v1/profiles", useDateTimeDecoder: true)
        return res.profiles.sorted { $0.createdAt < $1.createdAt }
    }

    func fetchProfile(id: String) async throws -> Profile? {
        let idSafe = String(Array(id))
        guard !idSafe.isEmpty else { return nil }
        if let cached = profileCache[idSafe], cached.expiresAt > Date() {
            return cached.profile
        }
        do {
            let profile: Profile = try await client.request(path: "api/v1/profiles/\(idSafe)", useDateTimeDecoder: true)
            profileCache[idSafe] = (profile, Date().addingTimeInterval(profileCacheTTL))
            return profile
        } catch let e as APIResponseError where e.statusCode == 404 {
            return nil
        }
    }

    func createProfile(_ profile: Profile, name: String) async throws -> Profile {
        let nameTrimmed = name.trimmingCharacters(in: .whitespaces)
        if nameTrimmed.isEmpty {
            throw APIResponseError(statusCode: 400, errorMessage: "Имя не может быть пустым", backendMessage: nil, validationMessages: ["name is required"], backendCode: nil)
        }
        var json: [String: Any] = [
            "type": profile.type.rawValue,
            "name": nameTrimmed
        ]
        if let v = profile.gymName { json["gymName"] = v } else { json["gymName"] = NSNull() }
        if let v = profile.gender?.rawValue { json["gender"] = v } else { json["gender"] = NSNull() }
        if let v = profile.iconEmoji { json["iconEmoji"] = v } else { json["iconEmoji"] = NSNull() }
        if let v = profile.weight { json["weight"] = v } else { json["weight"] = NSNull() }
        if let v = profile.ownerCoachProfileId { json["ownerCoachProfileId"] = v }
        let (data, response) = try await client.requestRaw(
            path: "api/v1/profiles",
            method: "POST",
            jsonBody: json
        )
        if response.statusCode == 201 {
            if !data.isEmpty, let created = try? Self.profileResponseDecoder.decode(Profile.self, from: data) {
                profileCache.removeAll()
                return created
            }
            // Сервер вернул 201 без тела или с нечитаемым телом — подставляем последний профиль пользователя
            let list = try await fetchProfiles(userId: profile.userId)
            guard let newest = list.max(by: { $0.createdAt < $1.createdAt }) else {
                throw APIResponseError(statusCode: 502, errorMessage: "Профиль создан, но не удалось загрузить его данные", backendMessage: nil, validationMessages: [], backendCode: nil)
            }
            profileCache.removeAll()
            return newest
        }
        let created = try Self.profileResponseDecoder.decode(Profile.self, from: data)
        profileCache.removeAll()
        return created
    }

    private static var profileResponseDecoder: JSONDecoder {
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

    func updateProfile(_ profile: Profile) async throws {
        let docId = profile.id
        guard !docId.isEmpty else {
            throw APIResponseError(statusCode: 400, errorMessage: "id не может быть пустым", backendMessage: nil, validationMessages: [], backendCode: nil)
        }
        struct PatchBody: Encodable {
            let name: String
            let gymName: String?
            let gender: String?
            let iconEmoji: String?
            let weight: Double?
        }
        let body = PatchBody(
            name: profile.name,
            gymName: profile.gymName,
            gender: profile.gender?.rawValue,
            iconEmoji: profile.iconEmoji,
            weight: profile.weight
        )
        try await client.requestNoContent(path: "api/v1/profiles/\(docId)", method: "PATCH", body: body)
        profileCache.removeValue(forKey: docId)
    }

    func updateProfile(
        documentId: String,
        userId: String,
        type: ProfileType,
        name: String,
        gymName: String?,
        createdAt: Date,
        gender: ProfileGender?,
        dateOfBirth: Date?,
        iconEmoji: String?,
        phoneNumber: String?,
        telegramUsername: String?,
        notes: String?,
        ownerCoachProfileId: String?,
        mergedIntoProfileId: String?,
        height: Double?,
        weight: Double?
    ) async throws {
        guard !documentId.isEmpty else {
            throw APIResponseError(statusCode: 400, errorMessage: "documentId не может быть пустым", backendMessage: nil, validationMessages: [], backendCode: nil)
        }
        struct PatchBody: Encodable {
            let name: String
            let gymName: String?
            let gender: String?
            let iconEmoji: String?
            let dateOfBirth: String?
            let phoneNumber: String?
            let telegramUsername: String?
            let notes: String?
            let height: Double?
            let weight: Double?
        }
        let dateOfBirthStr: String? = dateOfBirth.map { ISO8601DateFormatter.fullFractional.string(from: $0) }
        let body = PatchBody(
            name: name,
            gymName: gymName,
            gender: gender?.rawValue,
            iconEmoji: iconEmoji,
            dateOfBirth: dateOfBirthStr,
            phoneNumber: phoneNumber,
            telegramUsername: telegramUsername,
            notes: notes,
            height: height,
            weight: weight
        )
        try await client.requestNoContent(path: "api/v1/profiles/\(documentId)", method: "PATCH", body: body)
        profileCache.removeValue(forKey: documentId)
    }

    func updateProfile(id: String, userId: String, type: ProfileType, name: String, gymName: String?, createdAt: Date, gender: ProfileGender?, dateOfBirth: Date?, iconEmoji: String?, phoneNumber: String?, telegramUsername: String?, notes: String?, ownerCoachProfileId: String?, mergedIntoProfileId: String?, height: Double?, weight: Double?) async throws {
        try await updateProfile(
            documentId: id,
            userId: userId,
            type: type,
            name: name,
            gymName: gymName,
            createdAt: createdAt,
            gender: gender,
            dateOfBirth: dateOfBirth,
            iconEmoji: iconEmoji,
            phoneNumber: phoneNumber,
            telegramUsername: telegramUsername,
            notes: notes,
            ownerCoachProfileId: ownerCoachProfileId,
            mergedIntoProfileId: mergedIntoProfileId,
            height: height,
            weight: weight
        )
    }

    func deleteProfile(_ profile: Profile) async throws {
        let docId = profile.id
        guard !docId.isEmpty else {
            throw APIResponseError(statusCode: 400, errorMessage: "id не может быть пустым", backendMessage: nil, validationMessages: [], backendCode: nil)
        }
        try await client.requestNoContent(path: "api/v1/profiles/\(docId)", method: "DELETE")
        profileCache.removeValue(forKey: docId)
    }
}
