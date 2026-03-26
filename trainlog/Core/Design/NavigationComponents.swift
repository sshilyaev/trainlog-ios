import SwiftUI

/// Единая кнопка «Назад» для тулбаров экранов и шитов.
/// В шитах с формой trailing-кнопку (Сохранить/Добавить) оформляйте через
/// `.fontWeight(.regular)` и `.foregroundStyle(.primary)` для единого стиля.
struct BackToolbarButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Назад", appIcon: "chevron-left")
        }
    }
}

