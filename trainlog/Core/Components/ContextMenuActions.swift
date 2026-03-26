import SwiftUI

struct EditMenuAction: View {
    let action: () -> Void
    var title: String = "Редактировать"

    var body: some View {
        Button(action: action) {
            Label(title, appIcon: "pencil-edit")
        }
    }
}

struct DeleteMenuAction: View {
    let action: () -> Void
    var title: String = "Удалить"

    var body: some View {
        Button(role: .destructive, action: action) {
            Label(title, appIcon: "delete-dustbin-01")
        }
    }
}

struct CancelMenuAction: View {
    let action: () -> Void
    var title: String = "Отменить"

    var body: some View {
        Button(role: .destructive, action: action) {
            Label(title, appIcon: "multiple-cross-cancel-circle")
        }
    }
}
