//
//  APICoachTraineeLinkService.swift
//  TrainLog
//

import Foundation

private struct CoachTraineeLinkDTO: Decodable {
    let id: String
    let coachProfileId: String
    let traineeProfileId: String
    let displayName: String?
    let note: String?
    let archived: Bool?
    let createdAt: Date
}

@MainActor
final class APICoachTraineeLinkService: CoachTraineeLinkServiceProtocol {
    private let client: APIClient
    private var linksCache: [String: (links: [CoachTraineeLink], expiresAt: Date, profiles: [Profile]?)] = [:]
    private let linksCacheTTL: TimeInterval = 30

    init(client: APIClient) {
        self.client = client
    }

    convenience init(baseURL: URL, getIDToken: @escaping (_ forceRefresh: Bool) async -> String?) {
        self.init(client: APIClient(baseURL: baseURL, getIDToken: getIDToken))
    }

    func fetchLinks(coachProfileId: String) async throws -> [CoachTraineeLink] {
        try await fetchLinks(profileId: coachProfileId, as: "coach")
    }

    func fetchLinksWithProfiles(profileId: String, as role: String) async throws -> LinksWithProfilesResponse {
        let key = cacheKey(profileId: profileId, role: role)
        if let cached = linksCache[key], cached.expiresAt > Date(), let profiles = cached.profiles {
            return LinksWithProfilesResponse(links: cached.links, profiles: profiles)
        }
        struct ListResponse: Decodable {
            let links: [CoachTraineeLinkDTO]
            let profiles: [Profile]?
        }
        let res: ListResponse = try await client.request(
            path: "api/v1/coach-trainee-links",
            query: ["profileId": profileId, "as": role, "embed": "profiles"],
            useDateTimeDecoder: true
        )
        let links = res.links.map { dto in
            CoachTraineeLink(
                id: dto.id,
                coachProfileId: dto.coachProfileId,
                traineeProfileId: dto.traineeProfileId,
                createdAt: dto.createdAt,
                displayName: dto.displayName,
                isArchived: dto.archived ?? false
            )
        }
        let profiles = res.profiles ?? []
        linksCache[key] = (links, Date().addingTimeInterval(linksCacheTTL), profiles)
        return LinksWithProfilesResponse(links: links, profiles: profiles)
    }

    private func fetchLinks(profileId: String, as role: String) async throws -> [CoachTraineeLink] {
        let key = cacheKey(profileId: profileId, role: role)
        if let cached = linksCache[key], cached.expiresAt > Date() {
            return cached.links
        }
        struct ListResponse: Decodable {
            let links: [CoachTraineeLinkDTO]
        }
        let res: ListResponse = try await client.request(
            path: "api/v1/coach-trainee-links",
            query: ["profileId": profileId, "as": role],
            useDateTimeDecoder: true
        )
        let links = res.links.map { dto in
            CoachTraineeLink(
                id: dto.id,
                coachProfileId: dto.coachProfileId,
                traineeProfileId: dto.traineeProfileId,
                createdAt: dto.createdAt,
                displayName: dto.displayName,
                isArchived: dto.archived ?? false
            )
        }
        linksCache[key] = (links, Date().addingTimeInterval(linksCacheTTL), nil)
        return links
    }

    func fetchLinksForTrainee(traineeProfileId: String) async throws -> [CoachTraineeLink] {
        try await fetchLinks(profileId: traineeProfileId, as: "trainee")
    }

    private func cacheKey(profileId: String, role: String) -> String {
        "\(profileId):\(role)"
    }

    private func invalidateLinksCache() {
        linksCache.removeAll()
    }

    func fetchTraineeProfileIds(coachProfileId: String) async throws -> [String] {
        let links = try await fetchLinks(coachProfileId: coachProfileId)
        return links.map(\.traineeProfileId)
    }

    func addLink(coachProfileId: String, traineeProfileId: String, displayName: String?) async throws {
        struct CreateBody: Encodable {
            let coachProfileId: String
            let traineeProfileId: String
            let displayName: String?
        }
        _ = try await client.request(
            path: "api/v1/coach-trainee-links",
            method: "POST",
            body: CreateBody(
                coachProfileId: coachProfileId,
                traineeProfileId: traineeProfileId,
                displayName: displayName
            ),
            useDateTimeDecoder: true
        ) as CoachTraineeLinkDTO
        invalidateLinksCache()
    }

    func removeLink(coachProfileId: String, traineeProfileId: String) async throws {
        let links = try await fetchLinks(coachProfileId: coachProfileId)
        guard let link = links.first(where: { $0.traineeProfileId == traineeProfileId }) else {
            throw APIResponseError(statusCode: 404, errorMessage: "Связь не найдена", backendMessage: nil, validationMessages: [], backendCode: nil)
        }
        try await client.requestNoContent(path: "api/v1/coach-trainee-links/\(link.id)", method: "DELETE")
        invalidateLinksCache()
    }

    func setArchived(coachProfileId: String, traineeProfileId: String, isArchived: Bool) async throws {
        let links = try await fetchLinks(coachProfileId: coachProfileId)
        guard let link = links.first(where: { $0.traineeProfileId == traineeProfileId }) else {
            throw APIResponseError(statusCode: 404, errorMessage: "Связь не найдена", backendMessage: nil, validationMessages: [], backendCode: nil)
        }
        struct PatchBody: Encodable {
            let archived: Bool
        }
        try await client.requestNoContent(
            path: "api/v1/coach-trainee-links/\(link.id)",
            method: "PATCH",
            body: PatchBody(archived: isArchived)
        )
        invalidateLinksCache()
    }

    func updateLink(coachProfileId: String, traineeProfileId: String, displayName: String?) async throws {
        let links = try await fetchLinks(coachProfileId: coachProfileId)
        guard let link = links.first(where: { $0.traineeProfileId == traineeProfileId }) else {
            throw APIResponseError(statusCode: 404, errorMessage: "Связь не найдена", backendMessage: nil, validationMessages: [], backendCode: nil)
        }
        struct PatchBody: Encodable {
            let displayName: String?
        }
        try await client.requestNoContent(
            path: "api/v1/coach-trainee-links/\(link.id)",
            method: "PATCH",
            body: PatchBody(displayName: displayName)
        )
        invalidateLinksCache()
    }
}
