//
//  MembershipService.swift
//  TrainLog
//

import Foundation

protocol MembershipServiceProtocol {
    /// Активный абонемент (если есть).
    func fetchActiveMembership(coachProfileId: String, traineeProfileId: String) async throws -> Membership?
    /// Все абонементы клиента у конкретного тренера (включая завершённые).
    func fetchMemberships(coachProfileId: String, traineeProfileId: String) async throws -> [Membership]
    /// Все абонементы подопечного (для просмотра в дневнике; только чтение).
    func fetchMembershipsForTrainee(traineeProfileId: String) async throws -> [Membership]
    /// Создать абонемент. Для .byVisits передать totalSessions; для .unlimited — startDate и endDate.
    func createMembership(coachProfileId: String, traineeProfileId: String, kind: MembershipKind, totalSessions: Int?, startDate: Date?, endDate: Date?, priceRub: Int?) async throws -> Membership
    func updateMembership(_ membership: Membership) async throws
    /// Сбросить локальный кэш абонементов после операций с посещениями.
    func invalidateMembershipsCache(coachProfileId: String, traineeProfileId: String)
}

