//
//  TrainLogApp.swift
//  TrainLog
//

import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct TrainLogApp: App {
    private let appState: AppState
    private let authService: AuthServiceProtocol
    private let profileService: ProfileServiceProtocol
    private let measurementService: MeasurementServiceProtocol
    private let goalService: GoalServiceProtocol
    private let personalRecordService: PersonalRecordServiceProtocol
    private let linkService: CoachTraineeLinkServiceProtocol
    private let connectionTokenService: ConnectionTokenServiceProtocol
    private let membershipService: MembershipServiceProtocol
    private let visitService: VisitServiceProtocol
    /// Сервис для синхронизации офлайн-очереди: всегда API, чтобы при появлении сети отправлять запросы на сервер.
    private let visitServiceForSync: VisitServiceProtocol
    private let eventService: EventServiceProtocol
    private let managedTraineeMergeService: ManagedTraineeMergeServiceProtocol
    private let coachStatisticsService: CoachStatisticsServiceProtocol
    private let healthService: HealthServiceProtocol
    private let calendarSummaryService: CalendarSummaryServiceProtocol
    private let nutritionService: NutritionServiceProtocol
    private let calculatorsService: CalculatorsServiceProtocol
    private let coachOverviewService: CoachOverviewServiceProtocol
    private let supportCampaignService: SupportCampaignServiceProtocol
    private let rewardedAdService: RewardedAdServiceProtocol

    init() {
        FirebaseApp.configure()
        appState = AppState()
        authService = FirebaseAuthService()

        let getIDToken: (_ forceRefresh: Bool) async -> String? = { forceRefresh in
            do {
                return try await Auth.auth().currentUser?.getIDToken(forcingRefresh: forceRefresh)
            } catch {
                return nil
            }
        }

        let client = APIClient(baseURL: ApiConfig.baseURL, getIDToken: getIDToken)
        profileService = APIProfileService(client: client)
        measurementService = APIMeasurementService(client: client)
        goalService = APIGoalService(client: client)
        personalRecordService = APIPersonalRecordService(client: client)
        linkService = APICoachTraineeLinkService(client: client)
        connectionTokenService = APIConnectionTokenService(client: client)
        membershipService = APIMembershipService(client: client)
        let baseVisitService = APIVisitService(client: client)
        visitServiceForSync = baseVisitService
        if AppConfig.enableOfflineMode {
            visitService = OfflineVisitService(wrapped: baseVisitService)
        } else {
            visitService = baseVisitService
        }
        eventService = APIEventService(client: client)
        managedTraineeMergeService = APIManagedTraineeMergeService(client: client)
        coachStatisticsService = APICoachStatisticsService(client: client)
        healthService = HealthKitService()
        calendarSummaryService = APICalendarSummaryService(client: client)
        nutritionService = APINutritionService(client: client)

        calculatorsService = APICalculatorsService(client: client)
        coachOverviewService = APICoachOverviewService(client: client)
        supportCampaignService = APISupportCampaignService(client: client)
        rewardedAdService = HybridRewardedAdService(
            primary: YandexRewardedAdService(),
            fallback: DevMockRewardedAdService()
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                appState: appState,
                authService: authService,
                profileService: profileService,
                measurementService: measurementService,
                goalService: goalService,
                personalRecordService: personalRecordService,
                linkService: linkService,
                connectionTokenService: connectionTokenService,
                membershipService: membershipService,
                visitService: visitService,
                visitServiceForSync: visitServiceForSync,
                eventService: eventService,
                managedTraineeMergeService: managedTraineeMergeService,
                coachStatisticsService: coachStatisticsService,
                healthService: healthService,
                calendarSummaryService: calendarSummaryService,
                nutritionService: nutritionService,
                calculatorsService: calculatorsService,
                coachOverviewService: coachOverviewService,
                supportCampaignService: supportCampaignService,
                rewardedAdService: rewardedAdService
            )
        }
    }
}
