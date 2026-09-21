//
//  kpi_scheduleApp.swift
//  kpi-schedule
//
//  Created by Maksym Broniev on 21.09.2026.
//

import SwiftUI

protocol ScheduleItem {
    var id: UUID { get }
    func getDetails() -> String
}

enum LessonType: String {
    case lecture = "Lecture"
    case practice = "Practice"
    case lab = "Lab work"
}

enum WeekType {
    case first
    case second
}

struct Lesson: ScheduleItem {
    let id: UUID
    var subjectName: String
    var teacher: String
    var type: LessonType
    var room: String?
    var isOnline: Bool
    var link: String?
    
    init(subjectName: String, teacher: String, type: LessonType, room: String? = nil, isOnline: Bool = false, link: String? = nil){
        self.id = UUID()
        self.subjectName = subjectName
        self.teacher = teacher
        self.type = type
        self.room = room
        self.isOnline = isOnline
        self.link = link
    }
    
    func getDetails() -> String {
        let location = room ?? (isOnline ? "Online" : "Unknown")
        return "[\(type.rawValue)] \(subjectName) | Teacher: \(teacher) | Location: \(location)"
    }
    
    func getLocation() -> String {
        return (room ?? (isOnline ? "Online" : "Unknown"))
    }
}

class DailySchedule {
    let dayOfWeek: String
    let weekType: WeekType
    var lessons: [Lesson]
    
    init(dayOfWeek: String, weekType: WeekType) {
        self.dayOfWeek = dayOfWeek
        self.weekType = weekType
        self.lessons = []
    }
    
    func addLesson(_ lessson: Lesson) {
        lessons.append(lessson)
    }
    
    func getLessons(by type: LessonType) -> [Lesson]{
        return lessons.filter{ $0.type == type }
    }
    
    func printDailySchedule() {
        print("\(dayOfWeek)")
        
        if lessons.isEmpty { print("Chill!!") }
        else {
            for(index, lesson) in lessons.enumerated() {
                print("\(index + 1): \(lesson.getDetails())")
            }
        }
    }
}

@main
struct kpi_scheduleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(weeklySchedule: createSchedule())
        }
    }
    
    private func createSchedule() -> [DailySchedule] {
        let mondaySchedule = DailySchedule(dayOfWeek: "Monday", weekType: .first)
        
        let IOSLecture = Lesson(subjectName: "IOS programming", teacher: "Halytskiy D. V.", type: .lecture, isOnline: true)
        
        mondaySchedule.addLesson(IOSLecture)
       
        
        
        let wednesdaySchedule = DailySchedule(dayOfWeek: "Wednesday", weekType: .first)
        
        let IOSPractice = Lesson(subjectName: "IOS programming", teacher: "Halytskiy D. V.", type: .lab, isOnline: true, link: "https://github.com/BronievM/KPI-IOS" )
        
        wednesdaySchedule.addLesson(IOSPractice)
        
        return [mondaySchedule, wednesdaySchedule]
    }
}
