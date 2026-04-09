//
//  NutritionPlan.swift
//  TrainLog
//

import Foundation

enum SportsSupplementType: String, Codable, CaseIterable, Identifiable {
    case vitamin
    case mineral
    case sportsNutrition = "sports_nutrition"
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vitamin: return "Витамины"
        case .mineral: return "Минералы"
        case .sportsNutrition: return "Спортпит"
        case .other: return "Другое"
        }
    }
}

enum SupplementDosageUnit: String, Codable, CaseIterable, Identifiable {
    case capsule
    case tablet
    case gram
    case milligram
    case milliliter
    case iu
    case scoop
    case drop
    case serving

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .capsule: return "капсула"
        case .tablet: return "таблетка"
        case .gram: return "г"
        case .milligram: return "мг"
        case .milliliter: return "мл"
        case .iu: return "МЕ"
        case .scoop: return "мерная ложка"
        case .drop: return "капля"
        case .serving: return "порция"
        }
    }
}

struct SportsSupplementCatalogItem: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let type: SportsSupplementType
    let description: String
    let isActive: Bool
    let sortOrder: Int?
    let defaultDosageUnit: SupplementDosageUnit?
}

struct TraineeSportsSupplementAssignment: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let coachProfileId: String
    let traineeProfileId: String
    let supplementId: String
    let supplementName: String
    let supplementType: SportsSupplementType
    let supplementDescription: String
    let dosage: String?
    let dosageValue: String?
    let dosageUnit: SupplementDosageUnit?
    let timing: String?
    let frequency: String?
    let note: String?
    let createdAt: Date
    let updatedAt: Date

    init(
        id: String,
        coachProfileId: String,
        traineeProfileId: String,
        supplementId: String,
        supplementName: String,
        supplementType: SportsSupplementType,
        supplementDescription: String,
        dosage: String?,
        dosageValue: String?,
        dosageUnit: SupplementDosageUnit?,
        timing: String?,
        frequency: String?,
        note: String?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.coachProfileId = coachProfileId
        self.traineeProfileId = traineeProfileId
        self.supplementId = supplementId
        self.supplementName = supplementName
        self.supplementType = supplementType
        self.supplementDescription = supplementDescription
        self.dosage = dosage
        self.dosageValue = dosageValue
        self.dosageUnit = dosageUnit
        self.timing = timing
        self.frequency = frequency
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case coachProfileId
        case traineeProfileId
        case supplementId
        case supplementName
        case supplementType
        case supplementDescription
        case dosage
        case dosageValue
        case dosageUnit
        case timing
        case frequency
        case note
        case createdAt
        case updatedAt
        case supplement
    }

    enum SupplementTypeCodingKeys: String, CodingKey {
        case name
        case type
        case description
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        coachProfileId = try container.decode(String.self, forKey: .coachProfileId)
        traineeProfileId = try container.decode(String.self, forKey: .traineeProfileId)
        supplementId = try container.decode(String.self, forKey: .supplementId)

        // Backward/contract compatibility:
        // 1) flat keys: supplementName/supplementType/supplementDescription
        // 2) nested object: supplement.{name,type,description}
        // 3) fallback defaults to avoid decoding crashes
        var decodedName: String?
        var decodedType: SportsSupplementType?
        var decodedDescription: String?

        if let nested = try? container.nestedContainer(keyedBy: SupplementTypeCodingKeys.self, forKey: .supplement) {
            decodedName = try? nested.decodeIfPresent(String.self, forKey: .name)
            decodedType = try? nested.decodeIfPresent(SportsSupplementType.self, forKey: .type)
            decodedDescription = try? nested.decodeIfPresent(String.self, forKey: .description)
        }

        supplementName = (try container.decodeIfPresent(String.self, forKey: .supplementName)) ?? decodedName ?? "Добавка"
        supplementType = (try container.decodeIfPresent(SportsSupplementType.self, forKey: .supplementType)) ?? decodedType ?? .other
        supplementDescription = (try container.decodeIfPresent(String.self, forKey: .supplementDescription)) ?? decodedDescription ?? ""

        dosage = try container.decodeIfPresent(String.self, forKey: .dosage)
        dosageValue = try container.decodeIfPresent(String.self, forKey: .dosageValue)
        if let rawUnit = try container.decodeIfPresent(String.self, forKey: .dosageUnit) {
            dosageUnit = SupplementDosageUnit(rawValue: rawUnit)
        } else {
            dosageUnit = nil
        }
        timing = try container.decodeIfPresent(String.self, forKey: .timing)
        frequency = try container.decodeIfPresent(String.self, forKey: .frequency)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(coachProfileId, forKey: .coachProfileId)
        try container.encode(traineeProfileId, forKey: .traineeProfileId)
        try container.encode(supplementId, forKey: .supplementId)
        try container.encode(supplementName, forKey: .supplementName)
        try container.encode(supplementType, forKey: .supplementType)
        try container.encode(supplementDescription, forKey: .supplementDescription)
        try container.encodeIfPresent(dosage, forKey: .dosage)
        try container.encodeIfPresent(dosageValue, forKey: .dosageValue)
        try container.encodeIfPresent(dosageUnit, forKey: .dosageUnit)
        try container.encodeIfPresent(timing, forKey: .timing)
        try container.encodeIfPresent(frequency, forKey: .frequency)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

extension SportsSupplementCatalogItem {
    /// Значение по умолчанию на назначении, если бэкенд пока не вернул свою рекомендацию.
    var defaultDosageText: String? {
        switch defaultDosageUnit ?? fallbackUnitByKnownSupplement {
        case .capsule: return "1 капсула"
        case .tablet: return "1 таблетка"
        case .gram: return "5 г"
        case .milligram: return "400 мг"
        case .milliliter: return "10 мл"
        case .scoop: return "1 мерная ложка"
        case .drop: return "2 капли"
        case .serving: return "1 порция"
        case nil: return nil
        }
    }

    var defaultDosageValue: String? {
        switch defaultDosageUnit ?? fallbackUnitByKnownSupplement {
        case .capsule, .tablet, .scoop, .serving: return "1"
        case .drop: return "2"
        case .gram: return "5"
        case .milligram: return "500"
        case .milliliter: return "10"
        case .iu: return "500"
        case nil: return nil
        }
    }

    var resolvedDosageUnit: SupplementDosageUnit? {
        defaultDosageUnit ?? fallbackUnitByKnownSupplement
    }

    private var fallbackUnitByKnownSupplement: SupplementDosageUnit? {
        let key = id.lowercased()
        if key.contains("d3") || key.contains("omega") { return .capsule }
        if key.contains("magnesium") { return .milligram }
        if key.contains("creatine") { return .gram }
        switch type {
        case .vitamin: return .capsule
        case .mineral: return .milligram
        case .sportsNutrition: return .gram
        case .other: return .serving
        }
    }
}

struct NutritionPlan: Identifiable, Codable, Equatable {
    let id: String
    let coachProfileId: String
    let traineeProfileId: String
    let weightKgUsed: Double
    let proteinPerKg: Double
    let fatPerKg: Double
    let carbsPerKg: Double
    let proteinGrams: Double
    let fatGrams: Double
    let carbsGrams: Double
    let calories: Int
    let comment: String?
    let createdAt: Date
    let updatedAt: Date
}

struct NutritionPlanDraft: Equatable {
    var coachProfileId: String
    var traineeProfileId: String
    var weightKg: Double?
    var proteinPerKg: Double
    var fatPerKg: Double
    var carbsPerKg: Double
    var comment: String
}

struct TraineeNutritionPlansFeed: Equatable {
    let plans: [NutritionPlan]
    let coachProfiles: [Profile]
}

extension NutritionPlan {
    var perKgSummary: String {
        "Белки \(proteinPerKg.measurementFormatted) г/кг · Жиры \(fatPerKg.measurementFormatted) г/кг · Углеводы \(carbsPerKg.measurementFormatted) г/кг"
    }

    var totalsSummary: String {
        "Б \(proteinGrams.measurementFormatted) / Ж \(fatGrams.measurementFormatted) / У \(carbsGrams.measurementFormatted) г"
    }

    var caloriesSummary: String {
        "\(calories) ккал"
    }

    var shortSummary: String {
        "\(calories) ккал · \(totalsSummary)"
    }

    var proteinPercent: Int {
        let total = max(1.0, proteinCalories + fatCalories + carbsCalories)
        return Int((proteinCalories / total * 100).rounded())
    }

    var fatPercent: Int {
        let total = max(1.0, proteinCalories + fatCalories + carbsCalories)
        return Int((fatCalories / total * 100).rounded())
    }

    var carbsPercent: Int {
        max(0, 100 - proteinPercent - fatPercent)
    }

    private var proteinCalories: Double { proteinGrams * 4 }
    private var fatCalories: Double { fatGrams * 9 }
    private var carbsCalories: Double { carbsGrams * 4 }
}
