//
//  CoachTraineeLink.swift
//  TrainLog
//

import Foundation

struct CoachTraineeLink: Identifiable, Equatable, Codable {
    let id: String
    let coachProfileId: String
    let traineeProfileId: String
    let createdAt: Date
    /// Имя для отображения в списке у тренера (если задано — подставляется вместо имени из профиля).
    var displayName: String?
    /// В архиве — отображаются внизу списка подопечных.
    var isArchived: Bool
    /// Избранный подопечный — отображается выше остальных.
    var isFavorite: Bool

    init(
        id: String,
        coachProfileId: String,
        traineeProfileId: String,
        createdAt: Date = Date(),
        displayName: String? = nil,
        isArchived: Bool = false,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.coachProfileId = coachProfileId
        self.traineeProfileId = traineeProfileId
        self.createdAt = createdAt
        self.displayName = displayName
        self.isArchived = isArchived
        self.isFavorite = isFavorite
    }
}
