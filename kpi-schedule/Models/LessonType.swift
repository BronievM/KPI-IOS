//
//  LessonType.swift
//  kpi-schedule
//
//  Created by Maksym on 20.10.2026.
//

import Foundation

enum LessonType: String, Codable {
    case lecture = "Lecture"
    case practice = "Practice"
    case lab = "Lab work"
}

enum WeekType {
    case first
    case second
}
