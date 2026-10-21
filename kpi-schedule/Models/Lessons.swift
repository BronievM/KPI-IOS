//
//  Lessons.swift
//  kpi-schedule
//
//  Created by Maksym on 20.10.2026.
//

import Foundation

struct Lesson: ScheduleItem {
    let id: UUID
    var subjectName: String
    var teacher: String
    var type: LessonType
    var room: String?
    var isOnline: Bool
    var link: String?
    var startTime: LessonTime?

    init(subjectName: String, teacher: String, type: LessonType, room: String? = nil, isOnline: Bool = false, link: String? = nil, startTime: LessonTime? = nil) {
        self.id = UUID()
        self.subjectName = subjectName
        self.teacher = teacher
        self.type = type
        self.room = room
        self.isOnline = isOnline
        self.link = link
        self.startTime = startTime
    }

    func getDetails() -> String {
        "[\(type.rawValue)] \(subjectName) | Teacher: \(teacher) | Location: \(getLocation())"
    }

    func getLocation() -> String {
           room ?? (isOnline ? "Online" : "Unknown")
       }
}
