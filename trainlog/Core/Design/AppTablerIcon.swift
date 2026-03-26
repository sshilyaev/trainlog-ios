import SwiftUI
import UIKit

enum AppIconSize: CGFloat, CaseIterable {
    case s14 = 14
    case s16 = 16
    case s20 = 20
    case s24 = 24
    case s28 = 28
    case s32 = 32
    case s44 = 44
}

extension AppTablerIcon {
    func appIcon(_ size: AppIconSize, weight: Font.Weight = .semibold) -> some View {
        self.font(.system(size: size.rawValue, weight: weight))
    }
}

struct AppTablerIcon: View {
    let name: String

    init(_ name: String) {
        self.name = name
    }

    private static let tablerNameMap: [String: String] = [
        "archivebox": "archive",
        "archivebox.fill": "archive",
        "arrow-right": "arrow-right",
        "arrow.clockwise": "refresh",
        "arrow.down.right": "arrow-down-right",
        "arrow.left.arrow.right": "replace-user",
        "arrow.triangle.2.circlepath": "refresh",
        "arrow.up.arrow.down.circle": "arrows-exchange",
        "arrow.up.right": "arrow-up-right",
        "arrow.up.right.square": "external-link",
        "award-medal": "award",
        "bed.double.fill": "bed",
        "building.2": "stack-front",
        "building-apartment-two": "stack-front",
        "calculator": "calculator",
        "calendar": "calendar",
        "calendar-default": "calendar",
        "telegram": "brand-telegram",
        "calendar-filled": "calendar-event",
        "calendar.badge.checkmark": "calendar-check",
        "calendar.badge.exclamationmark": "calendar-event",
        "calendar.badge.plus": "calendar-plus",
        "calendar.circle.fill": "calendar",
        "chart.bar.fill": "chart-arrows-vertical",
        "chart.bar.xaxis": "chart-arrows-vertical",
        "chart.line.uptrend.xyaxis": "chart-arrows-vertical",
        "chart.xyaxis.line": "chart-arrows-vertical",
        "check-tick-circle": "circle-check",
        "checkmark": "check",
        "checkmark.circle": "circle-check",
        "checkmark.circle.fill": "circle-check",
        "chevron-left": "chevron-left",
        "chevron-right": "chevron-right",
        "chevron.down": "chevron-down",
        "chevron.up": "chevron-up",
        "circle": "circle",
        "clock.badge.checkmark": "clock-check",
        "coffee-cup-01": "michelin-bib-gourmand",
        "copy-default": "copy",
        "delete-dustbin-01": "trash-x",
        "doc.on.clipboard": "clipboard-text",
        "doc.on.doc.fill": "copy",
        "doc.text": "file-text",
        "dumbbell.fill": "treadmill",
        "ellipsis": "dots",
        "ellipsis.circle.fill": "dots-circle-horizontal",
        "envelope.fill": "mail",
        "exclamationmark.circle.fill": "alert-circle",
        "exclamationmark.triangle": "alert-triangle",
        "eye.fill": "eye",
        "eye.slash.fill": "eye-off",
        "figure.run": "run",
        "figure.stand": "user",
        "figure.strengthtraining.traditional": "treadmill",
        "figure.walk": "walk",
        "file-default": "file",
        "flag.checkered": "flag-check",
        "flame.fill": "flame",
        "filter-horizontal": "filter",
        "folder-default": "folder",
        "fork.knife": "tools-kitchen-2",
        "function": "math-function",
        "gearshape.fill": "settings",
        "globe": "world",
        "grid-dashboard-circle": "chart-arrows-vertical",
        "grid-dashboard-02": "calculator",
        "heart.slash.fill": "heart-off",
        "heart.text.square": "heartbeat",
        "heart.text.square.fill": "heartbeat",
        "home-simple": "home-2",
        "info.circle": "info-small",
        "info.circle.fill": "info-small",
        "iphone.slash": "device-mobile-x",
        "key": "key",
        "key.fill": "key",
        "key.slash": "key-off",
        "layer-three": "replace-user",
        "line.3.horizontal.decrease.circle": "filter",
        "list.bullet": "list",
        "lock.rotation": "lock-cog",
        "lock-close": "key",
        "log-out-right": "logout-2",
        "magnifyingglass": "search",
        "map": "map",
        "map-pin": "map-pin",
        "minus-circle": "circle-minus",
        "minus.circle.fill": "circle-minus",
        "multiple-cross-cancel-circle": "circle-x",
        "multiple-cross-cancel-square": "square-x",
        "note.text": "notes",
        "number": "number",
        "number.circle.fill": "number-0-small",
        "paperplane.fill": "send",
        "pencil": "pencil",
        "pencil-edit": "pencil",
        "pencil-scale": "ruler-2",
        "person": "user",
        "person.2": "users",
        "person.3.fill": "users-group",
        "person.badge.plus": "user-plus",
        "person.crop.circle.badge.plus": "user-plus",
        "person.crop.circle.badge.questionmark": "help-circle",
        "person.crop.rectangle.stack": "user-square-rounded",
        "person.fill": "user",
        "person.fill.badge.minus": "user-minus",
        "person.slash": "user-x",
        "phone.fill": "phone",
        "pills": "pill",
        "plus": "plus",
        "plus-circle": "circle-plus",
        "plus-square": "user-plus",
        "plus.circle": "circle-plus",
        "plus.circle.fill": "circle-plus",
        "qrcode": "qrcode",
        "questionmark.circle": "help-circle",
        "rectangle.portrait.and.arrow.right": "logout-2",
        "rublesign": "currency-rubel",
        "rublesign.circle": "currency-rubel",
        "ruler": "ruler",
        "ruler.fill": "ruler",
        "scalemass": "scale",
        "scope": "target",
        "search-default": "search",
        "settings-01": "settings",
        "sidebar-menu": "dots-vertical",
        "snowflake": "snowflake",
        "snowflake.slash": "snowflake-off",
        "sparkle-ai-01": "michelin-bib-gourmand",
        "sparkles": "sparkles",
        "sparkles.rectangle.stack.fill": "sparkles",
        "square.and.arrow.up.fill": "share",
        "square.and.pencil": "pencil",
        "square.grid.2x2": "layout-grid",
        "star.circle": "rosette",
        "star.circle.fill": "rosette",
        "tag": "tag",
        "target": "target",
        "ticket": "ticket",
        "ticket.fill": "ticket",
        "ticket.slash": "ticket-off",
        "trash": "trash-x",
        "trophy.fill": "trophy",
        "troubleshoot": "settings",
        "upload-up": "share",
        "user-circle": "user-circle",
        "user-default": "users",
        "send-plane-horizontal": "brand-telegram",
        "key-left": "scan",
        "user-love-heart": "user-heart",
        "wrench.and.screwdriver": "tools",
        "xmark": "x",
        "xmark.circle": "circle-x",
        "xmark.circle.fill": "circle-x"
    ]

    private var mappedName: String {
        AppTablerIcon.tablerNameMap[name] ?? name
    }

    private var assetName: String {
        "tabler-outline-\(mappedName)"
    }

    var body: some View {
        if UIImage(named: assetName) != nil {
            Image(assetName)
                .renderingMode(.template)
        } else {
            Image(systemName: "questionmark.circle")
                .renderingMode(.template)
        }
    }
}
