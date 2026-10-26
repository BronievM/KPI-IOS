//
//  LessonTime.swift
//  kpi-schedule
//
//  Created by Maksym on 21.10.2026.
//

import Foundation

/// Час початку пари (хвилини від початку доби).
struct LessonTime: Comparable, Hashable {
    /// Тривалість пари: 1 год 35 хв.
    static let pairDurationMinutes = 95

    let minutesFromMidnight: Int

    init(hour: Int, minute: Int) {
        self.minutesFromMidnight = hour * 60 + minute
    }

    /// "08:30" або "08:30:00"
    init?(_ text: String) {
        let parts = text.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        self.init(hour: hour, minute: minute)
    }

    var startText: String { Self.format(minutesFromMidnight) }
    var endText: String { Self.format(minutesFromMidnight + Self.pairDurationMinutes) }
    var rangeText: String { "\(startText)–\(endText)" }

    /// Чи йде пара в момент `minutes` (хвилини від початку доби)
    func contains(minutes: Int) -> Bool {
        minutes >= minutesFromMidnight && minutes < minutesFromMidnight + Self.pairDurationMinutes
    }

    static func < (lhs: LessonTime, rhs: LessonTime) -> Bool {
        lhs.minutesFromMidnight < rhs.minutesFromMidnight
    }

    private static func format(_ total: Int) -> String {
        String(format: "%02d:%02d", (total / 60) % 24, total % 60)
    }
}
