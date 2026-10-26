//
//  Weekday.swift
//  kpi-schedule
//
//  Created by Maksym on 21.10.2026.
//

import Foundation

/// День тижня. Потрібен, щоб сортувати дні та порівнювати день з розкладу з поточним днем
enum Weekday: Int, CaseIterable, Comparable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    /// Ініціалізатор з рядка (регістр не важливий). Підтримує англійські,
    /// скорочені українські та повні українські назви.
    init?(name: String) {
        switch name.lowercased() {
        case "monday", "mon", "пн", "понеділок":
            self = .monday
        case "tuesday", "tue", "вт", "вв", "вівторок":
            self = .tuesday
        case "wednesday", "wed", "ср", "середа":
            self = .wednesday
        case "thursday", "thu", "чт", "четвер":
            self = .thursday
        case "friday", "fri", "пт", "п'ятниця", "пятниця":
            self = .friday
        case "saturday", "sat", "сб", "субота":
            self = .saturday
        case "sunday", "sun", "нд", "неділя":
            self = .sunday
        default:
            return nil
        }
    }

    /// Значення з Calendar (1 = неділя ... 7 = субота).
    init?(calendarWeekday: Int) {
        let iso = calendarWeekday == 1 ? 7 : calendarWeekday - 1
        guard let day = Weekday(rawValue: iso) else { return nil }
        self = day
    }

    static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    /// Дні тижня в UI українською
    var localizedName: String {
        switch self {
        case .monday: return "Понеділок"
        case .tuesday: return "Вівторок"
        case .wednesday: return "Середа"
        case .thursday: return "Четвер"
        case .friday: return "П'ятниця"
        case .saturday: return "Субота"
        case .sunday: return "Неділя"
        }
    }
}
