//
//  APIConnectionTokenService.swift
//  TrainLog
//

import Foundation

@MainActor
final class APIConnectionTokenService: ConnectionTokenServiceProtocol {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    convenience init(baseURL: URL, getIDToken: @escaping (_ forceRefresh: Bool) async -> String?) {
        self.init(client: APIClient(baseURL: baseURL, getIDToken: getIDToken))
    }

    func createToken(traineeProfileId: String) async throws -> ConnectionToken {
        struct CreateBody: Encodable {
            let traineeProfileId: String
        }
        struct CreateResponse: Decodable {
            let token: String
            let expiresAt: Date
        }
        let res: CreateResponse = try await client.request(
            path: "api/v1/connection-tokens",
            method: "POST",
            body: CreateBody(traineeProfileId: traineeProfileId),
            useDateTimeDecoder: true
        )
        return ConnectionToken(
            id: res.token,
            traineeProfileId: traineeProfileId,
            createdAt: Date(),
            expiresAt: res.expiresAt,
            used: false
        )
    }

    /// По API: проверка кода через GET preview; полный токен не возвращается — возвращаем синтетический для совместимости с UI.
    func getToken(token: String) async throws -> ConnectionToken? {
        struct PreviewResponse: Decodable {
            let traineeProfileId: String
            let traineeName: String
        }
        do {
            let res: PreviewResponse = try await client.request(
                path: "api/v1/connection-tokens/preview",
                query: ["token": token],
                useDateTimeDecoder: false
            )
            return ConnectionToken(
                id: token,
                traineeProfileId: res.traineeProfileId,
                createdAt: Date(),
                expiresAt: Date().addingTimeInterval(15 * 60),
                used: false
            )
        } catch let e as APIResponseError where e.statusCode == 404 {
            return nil
        }
    }

    /// На API привязка делается через POST connection-tokens/use; отдельно помечать токен не нужно.
    func markTokenUsed(token: String) async throws {
        // No-op: use уже помечает токен использованным
    }

    func useToken(token: String, coachProfileId: String) async throws {
        struct UseBody: Encodable {
            let token: String
            let coachProfileId: String
        }
        struct UseResponse: Decodable {
            let id: String
            let coachProfileId: String
            let traineeProfileId: String
            let createdAt: Date
        }
        _ = try await client.request(
            path: "api/v1/connection-tokens/use",
            method: "POST",
            body: UseBody(token: token, coachProfileId: coachProfileId),
            useDateTimeDecoder: true
        ) as UseResponse
    }
}
