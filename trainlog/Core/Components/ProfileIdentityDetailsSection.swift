import SwiftUI

/// Единый блок личных данных профиля: пол, дата рождения, зал, рост и вес.
struct ProfileIdentityDetailsSection: View {
    let profile: Profile

    var body: some View {
        VStack(spacing: 0) {
            ActionBlockRow(icon: "user-default", title: "Пол", value: profile.gender?.displayName ?? "Не указан")

            if let dob = profile.dateOfBirth {
                Divider().padding(.leading, 52)
                ActionBlockRow(icon: "calendar-default", title: "Дата рождения", value: dob.formattedRuShort)
            }

            if profile.isCoach, let gym = profile.gymName?.trimmingCharacters(in: .whitespacesAndNewlines), !gym.isEmpty {
                Divider().padding(.leading, 52)
                ActionBlockRow(icon: "building-apartment-two", title: "Зал", value: gym)
            }

            if let h = profile.height {
                Divider().padding(.leading, 52)
                ActionBlockRow(icon: "ruler-2", title: "Рост", value: "\(h.measurementFormatted) см")
            }

            if let w = profile.weight {
                Divider().padding(.leading, 52)
                ActionBlockRow(icon: "ruler", title: "Вес", value: "\(w.measurementFormatted) кг")
            }
        }
        .actionBlockStyle()
    }
}

