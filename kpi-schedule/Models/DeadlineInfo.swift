//
//  DeadlineInfo.swift
//  kpi-schedule
//
//  Created by Maksym on 25.10.2026.
//

import Foundation

enum DeadlineUrgency: Equatable {
    case none       // без дедлайну або вже виконано
    case normal
    case soon       // сьогодні, завтра або за кілька днів
    case overdue
}

/// Текст і "терміновість" дедлайну («24 дні», «завтра», «прострочено на 2 дні», «Довгостроково»)
struct DeadlineInfo: Equatable {
    let text: String
    let urgency: DeadlineUrgency
    /// Дедлайн сьогодні (і завдання не виконано)
    let isToday: Bool

    init(deadline: Date?, isDone: Bool, now: Date, calendar: Calendar = .current) {
        guard let deadline = deadline else {
            text = "Довгостроково"
            urgency = .none
            isToday = false
            return
        }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: deadline)
        ).day ?? 0

        isToday = (days == 0) && !isDone

        if days < 0 {
            text = "прострочено на \(DeadlineInfo.daysText(-days))"
            urgency = isDone ? .none : .overdue
        } else if days == 0 {
            text = "сьогодні"
            urgency = isDone ? .none : .soon
        } else if days == 1 {
            text = "завтра"
            urgency = isDone ? .none : .soon
        } else {
            text = DeadlineInfo.daysText(days)
            urgency = isDone ? .none : (days <= 3 ? .soon : .normal)
        }
    }

    /// «1 день», «2 дні», «5 днів», «21 день»...
    static func daysText(_ n: Int) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        let word: String
        if mod10 == 1 && mod100 != 11 {
            word = "день"
        } else if (2...4).contains(mod10) && !(12...14).contains(mod100) {
            word = "дні"
        } else {
            word = "днів"
        }
        return "\(n) \(word)"
    }
}
