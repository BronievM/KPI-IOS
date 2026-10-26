//
//  Lesson.swift
//  kpi-schedule
//
//  Created by Maksym on 21.10.2026.
//  Updated by Maksym on 25.10.2026.
//

import Foundation

struct Lesson {
    let id: UUID
    var subjectName: String
    var teacher: String
    var type: LessonType
    var room: String?
    var isOnline: Bool
    var link: String?
    var startTime: LessonTime?
    /// Вибірковий предмет (є не в усіх студентів групи)
    var isElective: Bool

    init(subjectName: String, teacher: String, type: LessonType, room: String? = nil, isOnline: Bool = false, link: String? = nil, startTime: LessonTime? = nil, isElective: Bool = false) {
        self.id = UUID()
        self.subjectName = subjectName
        self.teacher = teacher
        self.type = type
        self.room = room
        self.isOnline = isOnline
        self.link = link
        self.startTime = startTime
        self.isElective = isElective
    }

    func getLocation() -> String {
        room ?? (isOnline ? "Онлайн" : "Аудиторія не вказана")
    }
}
