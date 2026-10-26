//
//  LessonType.swift
//  kpi-schedule
//
//  Created by Maksym on 21.10.2026.
//

import Foundation

enum LessonType: String, Codable {
    case lecture = "Лекція"
    case practice = "Практика"
    case lab = "Лабораторна"
}

enum WeekType: String, Codable {
    case first = "перший"
    case second = "другий"
}
