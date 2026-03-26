//
//  ManagedTraineeMergeService.swift
//  TrainLog
//

import Foundation

protocol ManagedTraineeMergeServiceProtocol {
    /// Переносит все данные managed-подопечного в реальный профиль подопечного.
    /// Меняет ссылки в measurements/goals/memberships/visits/coachTraineeLinks и помечает managed-профиль как merged.
    func mergeManagedTrainee(
        coachProfileId: String,
        managedTraineeProfileId: String,
        realTraineeProfileId: String
    ) async throws
}

final class MockManagedTraineeMergeService: ManagedTraineeMergeServiceProtocol {
    func mergeManagedTrainee(coachProfileId: String, managedTraineeProfileId: String, realTraineeProfileId: String) async throws {
        // no-op for previews/tests
    }
}

