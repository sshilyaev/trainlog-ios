import SwiftUI

struct ProfileContactSection: View {
    let phoneNumber: String?
    let telegramUsername: String?

    var body: some View {
        if hasAnyContact {
            VStack(spacing: 0) {
                if let phone = phoneNumber, !phone.isEmpty {
                    ActionBlockRow(icon: "phone", title: "Телефон", value: PhoneFormatter.displayString(phone))
                    if let telegramUsername, !telegramUsername.isEmpty {
                        Divider().padding(.leading, 52)
                    }
                }
                if let telegramUsername, !telegramUsername.isEmpty {
                    ActionBlockRow(icon: "send-plane-horizontal", title: "Telegram", value: "@\(telegramUsername)")
                }
            }
            .actionBlockStyle()
        }
    }

    private var hasAnyContact: Bool {
        (phoneNumber != nil && !(phoneNumber?.isEmpty ?? true)) ||
        (telegramUsername != nil && !(telegramUsername?.isEmpty ?? true))
    }
}
