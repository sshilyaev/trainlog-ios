//
//  MockProfileService.swift
//  TrainLog
//

import Foundation

/// Для разработки без Firebase. In-memory хранилище.
final class MockProfileService: ProfileServiceProtocol {
    private var storage: [Profile] = []

    func fetchProfiles(userId: String) async throws -> [Profile] {
        try await Task.sleep(nanoseconds: 300_000_000)
        return storage.filter { $0.userId == userId }
    }

    func fetchProfile(id: String) async throws -> Profile? {
        try await Task.sleep(nanoseconds: 100_000_000)
        return storage.first { $0.id == id }
    }

    func createProfile(_ profile: Profile, name: String) async throws -> Profile {
        let nameTrimmed = name.trimmingCharacters(in: .whitespaces)
        try await Task.sleep(nanoseconds: 200_000_000)
        let id = UUID().uuidString
        let created = Profile(
            id: id,
            userId: profile.userId,
            type: profile.type,
            name: nameTrimmed,
            gymName: profile.gymName,
            createdAt: profile.createdAt,
            gender: profile.gender,
            dateOfBirth: profile.dateOfBirth,
            iconEmoji: profile.iconEmoji,
            phoneNumber: profile.phoneNumber,
            telegramUsername: profile.telegramUsername,
            notes: profile.notes,
            ownerCoachProfileId: profile.ownerCoachProfileId,
            mergedIntoProfileId: profile.mergedIntoProfileId,
                height: profile.height,
                weight: profile.weight
        )
        storage.append(created)
        return created
    }

    func updateProfile(_ profile: Profile) async throws {
        if let i = storage.firstIndex(where: { $0.id == profile.id }) {
            storage[i] = profile
        }
    }

    func updateProfile(documentId: String, userId: String, type: ProfileType, name: String, gymName: String?, createdAt: Date, gender: ProfileGender?, dateOfBirth: Date?, iconEmoji: String?, phoneNumber: String?, telegramUsername: String?, notes: String?, ownerCoachProfileId: String?, mergedIntoProfileId: String?, height: Double?, weight: Double?) async throws {
        if let i = storage.firstIndex(where: { $0.id == documentId }) {
            storage[i] = Profile(
                id: documentId,
                userId: userId,
                type: type,
                name: name,
                gymName: gymName,
                createdAt: createdAt,
                gender: gender,
                dateOfBirth: dateOfBirth,
                iconEmoji: iconEmoji,
                phoneNumber: phoneNumber,
                telegramUsername: telegramUsername,
                notes: notes,
                ownerCoachProfileId: ownerCoachProfileId,
                mergedIntoProfileId: mergedIntoProfileId,
                height: height,
                weight: weight
            )
        }
    }

    func updateProfile(id: String, userId: String, type: ProfileType, name: String, gymName: String?, createdAt: Date, gender: ProfileGender?, dateOfBirth: Date?, iconEmoji: String?, phoneNumber: String?, telegramUsername: String?, notes: String?, ownerCoachProfileId: String?, mergedIntoProfileId: String?, height: Double?, weight: Double?) async throws {
        if let i = storage.firstIndex(where: { $0.id == id }) {
            let existing = storage[i]
            storage[i] = Profile(
                id: id,
                userId: userId,
                type: type,
                name: name,
                gymName: gymName,
                createdAt: createdAt,
                gender: gender,
                dateOfBirth: dateOfBirth,
                iconEmoji: iconEmoji,
                phoneNumber: phoneNumber,
                telegramUsername: telegramUsername,
                notes: notes,
                ownerCoachProfileId: ownerCoachProfileId ?? existing.ownerCoachProfileId,
                mergedIntoProfileId: mergedIntoProfileId ?? existing.mergedIntoProfileId,
                height: height ?? existing.height,
                weight: weight ?? existing.weight
            )
        }
    }

    func deleteProfile(_ profile: Profile) async throws {
        storage.removeAll { $0.id == profile.id }
    }
}
