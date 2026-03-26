//
//  CoachOverviewService.swift
//  TrainLog
//

import Foundation

struct CoachOverviewTraineeItem {
    let link: CoachTraineeLink
    let profile: Profile
    let membershipSummary: String?
}

struct CoachOverviewWeekSummary {
    let clientsWithDoneVisits: Int
    let oneOffVisits: Int
    let subscriptionVisits: Int
    let rangeCaption: String
}

struct CoachOverviewResponse {
    let trainees: [CoachOverviewTraineeItem]
    let week: CoachOverviewWeekSummary
}

protocol CoachOverviewServiceProtocol {
    func fetchOverview(coachProfileId: String, includeArchived: Bool) async throws -> CoachOverviewResponse
    func invalidateCache(coachProfileId: String)
}

final class APICoachOverviewService: CoachOverviewServiceProtocol {
    private let client: APIClient
    private var cache: [String: (payload: CoachOverviewResponse, expiresAt: Date)] = [:]
    private let ttl: TimeInterval = 30

    init(client: APIClient) {
        self.client = client
    }

    func fetchOverview(coachProfileId: String, includeArchived: Bool = true) async throws -> CoachOverviewResponse {
        let key = "\(coachProfileId):\(includeArchived)"
        if let cached = cache[key], cached.expiresAt > Date() {
            return cached.payload
        }
        let raw: RawResponse = try await client.request(
            path: "api/v1/coach-profiles/\(coachProfileId)/trainees/overview",
            query: [
                "includeArchived": includeArchived ? "true" : "false",
                "page": "1",
                "limit": "200"
            ],
            useDateTimeDecoder: true
        )
        let result = CoachOverviewResponse(
            trainees: raw.trainees.compactMap { item in
                guard let profile = item.profile else { return nil }
                return CoachOverviewTraineeItem(
                    link: CoachTraineeLink(
                        id: item.link.id,
                        coachProfileId: item.link.coachProfileId,
                        traineeProfileId: item.link.traineeProfileId,
                        createdAt: item.link.createdAt,
                        displayName: item.link.displayName,
                        isArchived: item.link.archived
                    ),
                    profile: profile,
                    membershipSummary: item.activeMembershipSummary?.displayText
                )
            },
            week: CoachOverviewWeekSummary(
                clientsWithDoneVisits: raw.week.clientsWithDoneVisits,
                oneOffVisits: raw.week.oneOffVisits,
                subscriptionVisits: raw.week.subscriptionVisits,
                rangeCaption: Self.weekCaption(from: raw.week.range.from, to: raw.week.range.to)
            )
        )
        cache[key] = (result, Date().addingTimeInterval(ttl))
        return result
    }

    func invalidateCache(coachProfileId: String) {
        cache.keys
            .filter { $0.hasPrefix("\(coachProfileId):") }
            .forEach { cache.removeValue(forKey: $0) }
    }

    private static func weekCaption(from: Date, to: Date) -> String {
        "\(from.formattedRuDayMonth) - \(to.formattedRuDayMonth)"
    }
}

private extension APICoachOverviewService {
    struct RawResponse: Decodable {
        let trainees: [RawTrainee]
        let week: RawWeek
    }

    struct RawTrainee: Decodable {
        let link: RawLink
        let profile: Profile?
        let activeMembershipSummary: RawMembershipSummary?
    }

    struct RawLink: Decodable {
        let id: String
        let coachProfileId: String
        let traineeProfileId: String
        let displayName: String?
        let archived: Bool
        let createdAt: Date
    }

    struct RawMembershipSummary: Decodable {
        let kind: String
        let remainingSessions: Int
        let endDate: Date?

        var displayText: String? {
            if kind == "by_visits" {
                return "Осталось \(max(0, remainingSessions)) занятий"
            }
            if kind == "unlimited", let endDate {
                return "Абонемент до \(endDate.formattedRuDayMonth)"
            }
            return nil
        }
    }

    struct RawWeek: Decodable {
        struct Range: Decodable {
            let from: Date
            let to: Date
        }

        let clientsWithDoneVisits: Int
        let oneOffVisits: Int
        let subscriptionVisits: Int
        let range: Range
    }
}
