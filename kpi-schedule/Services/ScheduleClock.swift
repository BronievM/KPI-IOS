//
//  ScheduleClock.swift
//  kpi-schedule
//
//  Created by Maksym on 20.10.2026.
//

import Foundation

struct TimeSnapshot {
    let week: WeekType
    let weekday: Weekday?
    let minutes: Int
}

protocol ScheduleClock {
    func snapshot() -> TimeSnapshot
}

struct SystemScheduleClock: ScheduleClock {
    private let calendar: Calendar
    private let anchorDate: Date
    private let now: () -> Date

    static var kyivCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Kyiv") ?? .current
        calendar.firstWeekday = 1
        return calendar
    }

    init(firstWeekMonday: DateComponents = DateComponents(year: 2026, month: 9, day: 14),
         calendar: Calendar = SystemScheduleClock.kyivCalendar,
         now: @escaping () -> Date = Date.init) {
        self.calendar = calendar
        self.now = now
        let firstDate = calendar.date(from: firstWeekMonday) ?? Date(timeIntervalSince1970: 0)
        self.anchorDate = calendar.startOfDay(for: firstDate)
    }

    func snapshot() -> TimeSnapshot {
        let date = now()
        let today = calendar.startOfDay(for: date)
        
        let days = calendar.dateComponents([.day], from: anchorDate, to: today).day ?? 0
        
        let weekIndex = max(0, days) / 7
        let week: WeekType = (weekIndex % 2 == 0) ? .first : .second

        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        
        return TimeSnapshot(
            week: week,
            weekday: Weekday(calendarWeekday: parts.weekday ?? 0),
            minutes: (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        )
    }
}