//
//  Event.swift
//  TrainLog
//

import Foundation

enum EventType: String, Codable, CaseIterable {
    case general
    case workout
    case measurement
    case nutrition
    case reminder

    var title: String {
        switch self {
        case .general: return "Общее"
        case .workout: return "Тренировка"
        case .measurement: return "Замеры"
        case .nutrition: return "Питание"
        case .reminder: return "Напоминание"
        }
    }
}

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
    /// Тип события для сценариев типизации и дефолтной цветовой семантики.
    var eventType: EventType
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
        eventType: EventType = .general,
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
        self.eventType = eventType
        self.isCancelled = isCancelled
    }

    enum CodingKeys: String, CodingKey {
        case id
        case coachProfileId
        case traineeProfileId
        case createdAt
        case title
        case date
        case eventDescription
        case remind
        case colorHex
        case eventType
        case isCancelled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        coachProfileId = try container.decode(String.self, forKey: .coachProfileId)
        traineeProfileId = try container.decode(String.self, forKey: .traineeProfileId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(Date.self, forKey: .date)
        eventDescription = try container.decodeIfPresent(String.self, forKey: .eventDescription)
        remind = try container.decode(Bool.self, forKey: .remind)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex)
        eventType = try container.decodeIfPresent(EventType.self, forKey: .eventType) ?? .general
        isCancelled = try container.decode(Bool.self, forKey: .isCancelled)
    }
}
