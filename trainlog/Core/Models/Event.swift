//
//  Event.swift
//  TrainLog
//

import Foundation

/// Событие в календаре: анализы, взвешивание, планы и т.д. Привязано к паре тренер–подопечный.
struct Event: Identifiable, Codable, Equatable {
    let id: String
    let coachProfileId: String
    let traineeProfileId: String
    let createdAt: Date
    var title: String
    var date: Date
    var eventDescription: String?
    /// Напомнить (пока не используется — зарезервировано для пушей).
    var remind: Bool
    /// Цвет события в календаре (hex без #, например "34C759"). nil — цвет по умолчанию.
    var colorHex: String?
    /// Событие отменено (скрыто из календаря, в списке показывается как отменённое). Удалять нельзя.
    var isCancelled: Bool

    init(
        id: String,
        coachProfileId: String,
        traineeProfileId: String,
        createdAt: Date = Date(),
        title: String,
        date: Date,
        eventDescription: String? = nil,
        remind: Bool = false,
        colorHex: String? = nil,
        isCancelled: Bool = false
    ) {
        self.id = id
        self.coachProfileId = coachProfileId
        self.traineeProfileId = traineeProfileId
        self.createdAt = createdAt
        self.title = title
        self.date = date
        self.eventDescription = eventDescription
        self.remind = remind
        self.colorHex = colorHex
        self.isCancelled = isCancelled
    }
}
