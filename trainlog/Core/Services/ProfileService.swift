//
//  ProfileService.swift
//  TrainLog
//

import Foundation

protocol ProfileServiceProtocol {
    func fetchProfiles(userId: String) async throws -> [Profile]
    func fetchProfile(id: String) async throws -> Profile?
    /// Создаёт профиль. name — имя для запроса. Возвращает созданный профиль (с id от бекенда).
    func createProfile(_ profile: Profile, name: String) async throws -> Profile
    func updateProfile(_ profile: Profile) async throws
    /// Обновление по примитивам (избегает чтения полей Profile — для обхода EXC_BAD_ACCESS при повреждённом profile.name).
    func updateProfile(documentId: String, userId: String, type: ProfileType, name: String, gymName: String?, createdAt: Date, gender: ProfileGender?, dateOfBirth: Date?, iconEmoji: String?, phoneNumber: String?, telegramUsername: String?, notes: String?, ownerCoachProfileId: String?, mergedIntoProfileId: String?, height: Double?, weight: Double?) async throws
    func updateProfile(id: String, userId: String, type: ProfileType, name: String, gymName: String?, createdAt: Date, gender: ProfileGender?, dateOfBirth: Date?, iconEmoji: String?, phoneNumber: String?, telegramUsername: String?, notes: String?, ownerCoachProfileId: String?, mergedIntoProfileId: String?, height: Double?, weight: Double?) async throws
    func deleteProfile(_ profile: Profile) async throws
}
