//
//  Weekday.swift
//  kpi-schedule
//
//  Created by Maksym on 20.10.2026.
//

import Foundation

enum Weekday: Int, CaseIterable, Comparable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    init?(name: String) {
        switch name.lowercased() {
        case "monday", "mon", "пн":    self = .monday
        case "tuesday", "tue", "вт", "вв": self = .tuesday
        case "wednesday", "wed", "ср": self = .wednesday
        case "thursday", "thu", "чт":  self = .thursday
        case "friday", "fri", "пт":    self = .friday
        case "saturday", "sat", "сб":  self = .saturday
        case "sunday", "sun", "нд":    self = .sunday
        default: return nil
        }
    }

    init?(calendarWeekday: Int) {
        let iso = calendarWeekday == 1 ? 7 : calendarWeekday - 1
        guard let day = Weekday(rawValue: iso) else { return nil }
        self = day
    }

    static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.rawValue < rhs.rawValue }
}
