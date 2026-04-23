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
    case vacation
    case sick

    var title: String {
        switch self {
        case .general: return "Общее"
        case .workout: return "Тренировка"
        case .measurement: return "Замеры"
        case .nutrition: return "Питание"
        case .reminder: return "Напоминание"
        case .vacation: return "Отпуск"
        case .sick: return "Болезнь"
        }
    }
}

enum EventMode: String, Codable, CaseIterable {
    case date
    case period
}

enum EventPeriodType: String, Codable, CaseIterable {
    case vacation
    case sick

    var title: String {
        switch self {
        case .vacation: return "Отпуск"
        case .sick: return "Болезнь"
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
    var mode: EventMode
    var periodStart: Date
    var periodEnd: Date
    var periodType: EventPeriodType?
    var freezeMembership: Bool
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
        mode: EventMode = .date,
        periodStart: Date? = nil,
        periodEnd: Date? = nil,
        periodType: EventPeriodType? = nil,
        freezeMembership: Bool = false,
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
        self.mode = mode
        self.periodStart = periodStart ?? date
        self.periodEnd = periodEnd ?? date
        self.periodType = periodType
        self.freezeMembership = freezeMembership
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
        case mode
        case periodStart
        case periodEnd
        case periodType
        case freezeMembership
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
        mode = try container.decodeIfPresent(EventMode.self, forKey: .mode) ?? .date
        let fallbackDate = date
        periodStart = try container.decodeIfPresent(Date.self, forKey: .periodStart) ?? fallbackDate
        periodEnd = try container.decodeIfPresent(Date.self, forKey: .periodEnd) ?? fallbackDate
        periodType = try container.decodeIfPresent(EventPeriodType.self, forKey: .periodType)
        freezeMembership = try container.decodeIfPresent(Bool.self, forKey: .freezeMembership) ?? false
        isCancelled = try container.decode(Bool.self, forKey: .isCancelled)
    }
}
