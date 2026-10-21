//
//  LessonDTOAdapter.swift
//  kpi-schedule
//
//  Created by Maksym on 20.10.2026.
//

import Foundation

struct LessonDTO: Decodable {
    let group: String
    let day: String
    let week: String?
    let subject: String
    let teacher: String
    let type: String
    let time: String?
    let room: String?
    let online: Bool?
    let link: String?
}

// Adapter
struct LessonDTOAdapter {
    func adapt(_ dtos: [LessonDTO]) -> [DailySchedule] {
        var days: [DailySchedule] = []

        for dto in dtos {
            guard let type = lessonType(from: dto.type) else { continue }
            let week = weekType(from: dto.week)

            let builder = LessonBuilder()
                .subject(dto.subject)
                .teacher(dto.teacher)
                .type(type)
                .room(dto.room)
                .link(dto.link)
                .start(dto.time.flatMap { LessonTime($0) })
            if dto.online == true { builder.online() }
            let lesson = builder.build()

            if let day = days.first(where: { $0.dayOfWeek == dto.day && $0.weekType == week }) {
                day.addLesson(lesson)
            } else {
                let day = DailySchedule(dayOfWeek: dto.day, weekType: week)
                day.addLesson(lesson)
                days.append(day)
            }
        }

        for day in days {
            day.lessons.sort {
                ($0.startTime?.minutesFromMidnight ?? Int.max) < ($1.startTime?.minutesFromMidnight ?? Int.max)
            }
        }
        return days.sorted {
            ($0.weekday?.rawValue ?? Int.max) < ($1.weekday?.rawValue ?? Int.max)
        }
    }

    private func lessonType(from text: String) -> LessonType? {
        switch text.lowercased() {
        case "lecture", "lec":
            return .lecture
        case "laboratory", "laboratory work", "lab work", "lab":
            return .lab
        case "practical", "practice", "prac":
            return .practice
        default:
            return nil
        }
    }

    private func weekType(from text: String?) -> WeekType {
        let value = text?.lowercased() ?? ""
        return (value == "second" || value == "2") ? .second : .first
    }
}
