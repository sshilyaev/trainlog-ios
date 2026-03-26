import Foundation

struct PersonalRecord: Identifiable, Codable, Equatable {
    let id: String
    let profileId: String
    let createdByProfileId: String
    let recordDate: Date
    let sourceType: PersonalRecordSourceType
    var activityName: String
    var activityType: String?
    var notes: String?
    var metrics: [PersonalRecordMetric]
    let createdAt: Date?
    let updatedAt: Date?
}

enum PersonalRecordSourceType: String, Codable, CaseIterable {
    case catalog
    case custom
}

struct PersonalRecordMetric: Identifiable, Codable, Equatable {
    var id: String { rawId ?? "\(metricType.rawValue)-\(displayOrder)-\(value)" }
    let rawId: String?
    var metricType: PersonalRecordMetricType
    var value: Double
    var unit: String
    var displayOrder: Int

    enum CodingKeys: String, CodingKey {
        case rawId = "id"
        case metricType
        case value
        case unit
        case displayOrder
    }
}

enum PersonalRecordMetricType: String, Codable, CaseIterable, Identifiable {
    case weight
    case reps
    case duration
    case speed
    case distance
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weight: return "Вес"
        case .reps: return "Повторения"
        case .duration: return "Время"
        case .speed: return "Скорость"
        case .distance: return "Дистанция"
        case .other: return "Другое"
        }
    }

    var defaultUnit: String? {
        switch self {
        case .weight: return "кг"
        case .reps: return "раз"
        case .duration: return "сек"
        case .speed: return "км/ч"
        case .distance: return "м"
        case .other: return nil
        }
    }
}

struct RecordActivity: Identifiable, Codable, Equatable {
    var id: String { slug }
    let slug: String
    let name: String
    let activityType: String?
    let defaultMetrics: [PersonalRecordMetricType]
    let displayOrder: Int
}
