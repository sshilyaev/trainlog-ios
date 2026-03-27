//
//  AddByTokenSheet.swift
//  TrainLog
//

import SwiftUI
import UIKit

/// Тренер вводит код, сгенерированный подопечным → привязка к текущему coach-профилю. Sheet: хинт сверху, код + «Вставить из буфера», «Подтвердить» в тулбаре.
struct AddByTokenSheet: View {
    let coachProfile: Profile
    let tokenService: ConnectionTokenServiceProtocol
    let linkService: CoachTraineeLinkServiceProtocol
    let profileService: ProfileServiceProtocol
    let onLinkAdded: () -> Void
    let onDismiss: () -> Void

    @State private var codeInput = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var traineeToConfirm: Profile?
    @FocusState private var codeFieldFocused: Bool

    var body: some View {
        MainSheet(
            title: "Добавить по коду",
            onBack: onDismiss,
            trailing: {
                Button("Подтвердить") {
                    Task { await submitCode(codeInput.trimmingCharacters(in: .whitespacesAndNewlines)) }
                }
                .disabled(isLoading || codeInput.trimmingCharacters(in: .whitespacesAndNewlines).count < 4)
            },
            content: {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Подопечный создаёт временный код в разделе «Подключить по коду» в своём профиле.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, AppDesign.cardPadding)
                            .padding(.top, 8)
                            .padding(.bottom, 12)

                        SettingsCard(title: "Код") {
                            VStack(spacing: 0) {
                                FormRow(icon: "key-left", title: "Код") {
                                TextField("Код из приложения подопечного", text: $codeInput)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                                    .focused($codeFieldFocused)
                                    .textFieldStyle(.plain)
                                    .formInputStyle()
                            }
                                Button {
                                    if let paste = UIPasteboard.general.string {
                                        codeInput = paste.trimmingCharacters(in: .whitespacesAndNewlines)
                                    }
                                } label: {
                                    Label("Вставить из буфера", appIcon: "copy-default")
                                        .font(.subheadline)
                                        .foregroundStyle(AppColors.accent)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 8)
                                if let msg = errorMessage, !msg.isEmpty {
                                    Text(msg)
                                        .font(.footnote)
                                        .foregroundStyle(AppColors.destructive)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.top, 6)
                                }
                            }
                        }
                    }
                    .padding(.bottom, AppDesign.sectionSpacing)
                }
                .background(AppColors.systemGroupedBackground)
                .appConfirmationDialog(
                    title: "Привязать подопечного?",
                    message: traineeToConfirm.map { "Добавить \($0.name) в список подопечных?" } ?? "",
                    isPresented: Binding(
                        get: { traineeToConfirm != nil },
                        set: { if !$0 { traineeToConfirm = nil } }
                    ),
                    confirmTitle: "Привязать",
                    onConfirm: {
                        if let p = traineeToConfirm { Task { await confirmLink(trainee: p) } }
                        traineeToConfirm = nil
                    },
                    onCancel: { traineeToConfirm = nil }
                )
            }
        )
    }

    private func submitCode(_ code: String) async {
        guard !code.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            guard let token = try await tokenService.getToken(token: code.uppercased()) else {
                await MainActor.run {
                    errorMessage = "Код не найден или истёк"
                    ToastCenter.shared.warning("Код не найден или истёк")
                }
                return
            }
            guard token.isValid else {
                await MainActor.run {
                    errorMessage = "Код уже использован или истёк"
                    ToastCenter.shared.warning("Код уже использован или истёк")
                }
                return
            }
            guard let trainee = try await profileService.fetchProfile(id: token.traineeProfileId) else {
                await MainActor.run {
                    errorMessage = "Профиль подопечного не найден"
                    ToastCenter.shared.warning("Профиль подопечного не найден")
                }
                return
            }
            await MainActor.run { traineeToConfirm = trainee; pendingToken = code.uppercased() }
        } catch {
            await MainActor.run {
                ToastCenter.shared.error(from: error, fallback: "Не удалось проверить код")
                if let msg = AppErrors.userMessageIfNeeded(for: error) { errorMessage = msg }
            }
        }
    }

    @State private var pendingToken: String?

    private func confirmLink(trainee: Profile) async {
        guard let token = pendingToken else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false; pendingToken = nil }
        do {
            do {
                try await tokenService.useToken(token: token, coachProfileId: coachProfile.id)
            } catch is ConnectionTokenUseNotSupported {
                try await linkService.addLink(coachProfileId: coachProfile.id, traineeProfileId: trainee.id, displayName: nil)
                try await tokenService.markTokenUsed(token: token)
            }
            await MainActor.run {
                ToastCenter.shared.success("Подопечный добавлен")
                onLinkAdded()
            }
        } catch {
            await MainActor.run {
                ToastCenter.shared.error(from: error, fallback: "Не удалось добавить подопечного")
                if let msg = AppErrors.userMessageIfNeeded(for: error) { errorMessage = msg }
            }
        }
    }
}

