//
//  Profile.swift
//  TrainLog
//

import Foundation

enum ProfileType: String, Codable, CaseIterable {
    case coach
    case trainee
}

enum ProfileGender: String, Codable, CaseIterable {
    case male
    case female

    var displayName: String {
        switch self {
        case .male: return "Мужской"
        case .female: return "Женский"
        }
    }
}

struct Profile: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let userId: String
    let type: ProfileType
    var name: String
    var gymName: String?
    let createdAt: Date
    var gender: ProfileGender?
    /// Дата рождения для отображения возраста.
    var dateOfBirth: Date?
    var iconEmoji: String?
    /// Номер телефона для быстрого звонка (тренер → клиент).
    var phoneNumber: String?
    /// Telegram (логин без @) для быстрого перехода в чат.
    var telegramUsername: String?
    /// Заметки: противопоказания, важная информация. Редактируются тренером и подопечным.
    var notes: String?
    /// Если задано — это «managed» подопечный, созданный тренером без приложения.
    /// Владелец данных — тренерский профиль с этим id.
    var ownerCoachProfileId: String?
    /// Если managed-профиль объединён с реальным — сюда пишется id реального профиля.
    var mergedIntoProfileId: String?
    /// Рост в сантиметрах.
    var height: Double?
    /// Текущий вес в килограммах (для быстрых расчётов и prefill).
    var weight: Double?
    /// Режим разработчика для профиля (включается через админку).
    var developerMode: Bool?

    init(
        id: String,
        userId: String,
        type: ProfileType,
        name: String,
        gymName: String? = nil,
        createdAt: Date = Date(),
        gender: ProfileGender? = nil,
        dateOfBirth: Date? = nil,
        iconEmoji: String? = nil,
        phoneNumber: String? = nil,
        telegramUsername: String? = nil,
        notes: String? = nil,
        ownerCoachProfileId: String? = nil,
        mergedIntoProfileId: String? = nil,
        height: Double? = nil,
        weight: Double? = nil,
        developerMode: Bool? = nil
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.name = name
        self.gymName = gymName
        self.createdAt = createdAt
        self.gender = gender
        self.dateOfBirth = dateOfBirth
        self.iconEmoji = iconEmoji
        self.phoneNumber = phoneNumber
        self.telegramUsername = telegramUsername
        self.notes = notes
        self.ownerCoachProfileId = ownerCoachProfileId
        self.mergedIntoProfileId = mergedIntoProfileId
        self.height = height
        self.weight = weight
        self.developerMode = developerMode
    }

    /// Возраст в полных годах на сегодня (nil, если дата рождения не задана).
    var ageInYears: Int? {
        guard let dob = dateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dob, to: Date()).year
    }

    /// Строка возраста на русском: «25 лет», «1 год», «2 года».
    var ageFormatted: String? {
        guard let years = ageInYears else { return nil }
        let mod10 = years % 10
        let mod100 = years % 100
        let word: String
        if mod100 >= 11 && mod100 <= 14 { word = "лет" }
        else if mod10 == 1 { word = "год" }
        else if mod10 >= 2 && mod10 <= 4 { word = "года" }
        else { word = "лет" }
        return "\(years) \(word)"
    }

    var isCoach: Bool { type == .coach }
    var isTrainee: Bool { type == .trainee }
    var isManaged: Bool { ownerCoachProfileId != nil }

    var displaySubtitle: String? {
        isCoach ? gymName : nil
    }

    var isDeveloperModeEnabled: Bool { developerMode == true }
}
