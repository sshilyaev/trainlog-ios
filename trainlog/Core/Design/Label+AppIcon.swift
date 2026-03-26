import SwiftUI

extension Label where Title == Text, Icon == AppTablerIcon {
    init(_ title: String, appIcon: String) {
        self.init {
            Text(title)
        } icon: {
            AppTablerIcon(appIcon)
        }
    }
}
