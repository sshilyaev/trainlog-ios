//
//  ConnectionTokenService.swift
//  TrainLog
//

import Foundation

/// Выбрасывается, когда привязка по коду делается через addLink (Firestore/Mock), а не через use token (API).
struct ConnectionTokenUseNotSupported: Error {}

protocol ConnectionTokenServiceProtocol {
    /// Создать токен для профиля подопечного. Document ID = token string.
    func createToken(traineeProfileId: String) async throws -> ConnectionToken
    /// Получить токен по строке кода (чтение документа по id).
    func getToken(token: String) async throws -> ConnectionToken?
    /// Отметить токен как использованный.
    func markTokenUsed(token: String) async throws
    /// Использовать код и привязать тренера к подопечному (новый API: POST connection-tokens/use). Если не поддерживается — бросает ConnectionTokenUseNotSupported, тогда UI вызывает addLink + markTokenUsed.
    func useToken(token: String, coachProfileId: String) async throws
}
