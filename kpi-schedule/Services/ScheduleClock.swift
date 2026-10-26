//
//  ScheduleClock.swift
//  kpi-schedule
//
//  Created by Maksym on 21.10.2026.
//

import Foundation

/// Знімок поточного часу
struct TimeSnapshot {
    let week: WeekType
    let weekday: Weekday?
    let minutes: Int
}

/// Провайдер часу для можливості підміни `Date()` у тестах.
protocol ScheduleClock {
    func snapshot() -> TimeSnapshot
}

/// Реальний годинник. Відлік першого тижня йде від "firstWeekMonday"
struct SystemScheduleClock: ScheduleClock {
    private let calendar: Calendar
    private let firstWeekMonday: Date
    private let now: () -> Date

    static var kyivCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Kyiv") ?? .current
        calendar.firstWeekday = 2
        return calendar
    }

    init(firstWeekMonday: DateComponents = DateComponents(year: 2026, month: 9, day: 14),
         calendar: Calendar = SystemScheduleClock.kyivCalendar,
         now: @escaping () -> Date = Date.init) {
        self.calendar = calendar
        self.firstWeekMonday = calendar.date(from: firstWeekMonday) ?? Date(timeIntervalSince1970: 0)
        self.now = now
    }

    func snapshot() -> TimeSnapshot {
        let date = now()
        let anchor = calendar.startOfDay(for: firstWeekMonday)
        let today = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: anchor, to: today).day ?? 0
        let weekIndex = Int((Double(days) / 7).rounded(.down))
        let week: WeekType = weekIndex % 2 == 0 ? .first : .second

        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        return TimeSnapshot(
            week: week,
            weekday: Weekday(calendarWeekday: parts.weekday ?? 0),
            minutes: (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        )
    }
}
