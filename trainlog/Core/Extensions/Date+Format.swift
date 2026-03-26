//
//  Date+Format.swift
//  TrainLog
//

import Foundation

extension Date {
    /// Краткая дата на русском (день.месяц.год).
    var formattedRuShort: String {
        let f = DateFormatter()
        f.locale = .ru
        f.dateStyle = .short
        return f.string(from: self)
    }

    /// Дата на русском в формате «11 марта 2025».
    var formattedRuMedium: String {
        let f = DateFormatter()
        f.locale = .ru
        f.dateStyle = .medium
        return f.string(from: self)
    }

    /// День и месяц на русском: «12 марта» (для кратких подписей).
    var formattedRuDayMonth: String {
        let f = DateFormatter()
        f.locale = .ru
        f.dateFormat = "d MMMM"
        return f.string(from: self)
    }

    /// Краткая дата без года для списков: «12 мар».
    var formattedRuList: String {
        let f = DateFormatter()
        f.locale = .ru
        f.dateFormat = "d MMM"
        return f.string(from: self)
    }

    /// Полная дата на русском: «11 марта 2025 г.».
    var formattedRuLong: String {
        let f = DateFormatter()
        f.locale = .ru
        f.dateStyle = .long
        return f.string(from: self)
    }

    /// Время суток, напр. «15:42» (локаль ru).
    var formattedRuTime: String {
        let f = DateFormatter()
        f.locale = .ru
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: self)
    }

    /// Месяц и год с заглавной: «Март 2025» (для заголовков календаря).
    var formattedRuMonthYear: String {
        let f = DateFormatter()
        f.locale = .ru
        f.dateFormat = "LLLL yyyy"
        return f.string(from: self).capitalized
    }
}

extension DateInterval {
    /// Подпись календарной недели для сводок: «17 мар — 23 мар 2025».
    var formattedRuWeekRangeCaption: String {
        let cal = Calendar.current
        let startDay = cal.startOfDay(for: start)
        guard let endExclusive = cal.date(byAdding: .day, value: -1, to: end) else {
            return startDay.formattedRuMedium
        }
        let endDay = cal.startOfDay(for: endExclusive)
        if startDay == endDay {
            return startDay.formattedRuMedium
        }
        let y1 = cal.component(.year, from: startDay)
        let y2 = cal.component(.year, from: endDay)
        if y1 == y2 {
            return "\(startDay.formattedRuList) — \(endDay.formattedRuList) \(y1)"
        }
        return "\(startDay.formattedRuMedium) — \(endDay.formattedRuMedium)"
    }
}
