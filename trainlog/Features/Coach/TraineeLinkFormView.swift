//
//  TraineeLinkFormView.swift
//  TrainLog
//

import SwiftUI

/// Форма ввода имени для списка при добавлении подопечного тренером.
struct TraineeLinkFormView: View {
    let trainee: Profile
    let coachProfileId: String
    let linkService: CoachTraineeLinkServiceProtocol
    let tokenService: ConnectionTokenServiceProtocol?
    let pendingToken: String?
    let onLinkAdded: () -> Void
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SettingsCard(title: "Отображение у тренера") {
                    FormRowTextField(icon: "writing-sign", title: "Имя для списка", placeholder: "Как показывать в списке подопечных", text: $displayName, textContentType: .name, autocapitalization: .words)
                }

                if let msg = errorMessage, !msg.isEmpty {
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(AppColors.destructive)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppDesign.cardPadding)
                        .padding(.top, 8)
                }
            }
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .background(AppColors.systemGroupedBackground)
        .navigationTitle("Добавить подопечного")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackToolbarButton(action: { dismiss() })
            }
            ToolbarItem(placement: .topBarTrailing) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.9)
                } else {
                    Button("Добавить") {
                        Task { await save() }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            if displayName.isEmpty {
                displayName = trainee.name
            }
        }
    }

    private func save() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let name = displayName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : displayName.trimmingCharacters(in: .whitespaces)
        do {
            if let token = pendingToken, let svc = tokenService {
                do {
                    try await svc.useToken(token: token, coachProfileId: coachProfileId)
                    if let name = name {
                        try? await linkService.updateLink(coachProfileId: coachProfileId, traineeProfileId: trainee.id, displayName: name)
                    }
                } catch is ConnectionTokenUseNotSupported {
                    try await linkService.addLink(coachProfileId: coachProfileId, traineeProfileId: trainee.id, displayName: name)
                    try await svc.markTokenUsed(token: token)
                }
            } else {
                try await linkService.addLink(coachProfileId: coachProfileId, traineeProfileId: trainee.id, displayName: name)
                if let token = pendingToken, let svc = tokenService {
                    try? await svc.markTokenUsed(token: token)
                }
            }
            await MainActor.run { AppDesign.triggerSuccessHaptic() }
            await MainActor.run { ToastCenter.shared.success("Подопечный добавлен") }
            await MainActor.run { dismiss() }
            onLinkAdded()
        } catch {
            await MainActor.run {
                ToastCenter.shared.error(from: error, fallback: "Не удалось добавить подопечного")
                if let msg = AppErrors.userMessageIfNeeded(for: error) { errorMessage = msg }
            }
        }
    }
}
