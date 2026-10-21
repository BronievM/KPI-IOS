//
//  DaulySchedule.swift
//  kpi-schedule
//
//  Created by Maksym on 20.10.2026.
//

import Foundation

class DailySchedule {
        let dayOfWeek: String
    let weekType: WeekType
    var lessons: [Lesson]

    init(dayOfWeek: String, weekType: WeekType) {
        self.dayOfWeek = dayOfWeek
        self.weekType = weekType
        self.lessons = []
    }

    var weekday: Weekday? { Weekday(name: dayOfWeek) }

    func addLesson(_ lesson: Lesson) {
        lessons.append(lesson)
    }

    func getLessons(by type: LessonType) -> [Lesson] {
        lessons.filter { $0.type == type }
    }
}
