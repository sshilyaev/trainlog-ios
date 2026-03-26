//
//  CoachTraineeLinkService.swift
//  TrainLog
//

import Foundation

/// Ответ запроса links с embed=profiles: связи и массив профилей (подопечных при as=coach, тренеров при as=trainee).
struct LinksWithProfilesResponse {
    let links: [CoachTraineeLink]
    let profiles: [Profile]
}

protocol CoachTraineeLinkServiceProtocol {
    /// Связи тренера с подопечными (включая displayName и note).
    func fetchLinks(coachProfileId: String) async throws -> [CoachTraineeLink]
    /// Один запрос: связи + профили (при as=coach — профили подопечных, при as=trainee — тренеров). Убирает N+1.
    func fetchLinksWithProfiles(profileId: String, as role: String) async throws -> LinksWithProfilesResponse
    /// Связи подопечного с тренерами (для экрана «Посещения» у клиента).
    func fetchLinksForTrainee(traineeProfileId: String) async throws -> [CoachTraineeLink]
    /// Список id профилей подопечных (для обратной совместимости).
    func fetchTraineeProfileIds(coachProfileId: String) async throws -> [String]
    /// Привязать подопечного к тренеру с опциональным именем для списка.
    func addLink(coachProfileId: String, traineeProfileId: String, displayName: String?) async throws
    /// Отвязать подопечного от тренера.
    func removeLink(coachProfileId: String, traineeProfileId: String) async throws
    /// Архивировать или вернуть из архива. Архивированные отображаются внизу списка.
    func setArchived(coachProfileId: String, traineeProfileId: String, isArchived: Bool) async throws
    /// Обновить имя для списка в связи.
    func updateLink(coachProfileId: String, traineeProfileId: String, displayName: String?) async throws
}
