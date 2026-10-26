//
//  SampleTasks.swift
//  kpi-schedule
//
//  Created by Maksym on 25.10.2026.
//

import Foundation

enum SampleTasks {
    static func make(now: Date = Date()) -> [StudyTask] {
        let day: TimeInterval = 24 * 60 * 60
        let ios = "Розробка мобільних застосувань під iOS"
        let networks = "Комп'ютерні мережі"
        let ai = "Вступ до штучного інтелекту в комп’ютерній інженерії"
        let graphics = "Комп’ютерна графіка та мультимедіа"
        let classroom = "https://classroom.google.com"
        
        return [
            StudyTask(title: "ЛАБ2", subject: ios, deadline: now.addingTimeInterval(-9 * day), link: classroom, isDone: true),
            StudyTask(title: "ЛАБ3", subject: ios, deadline: now.addingTimeInterval(3 * day), link: classroom),
            StudyTask(title: "ЛАБ4", subject: ios, deadline: now.addingTimeInterval(17 * day)),
            
            StudyTask(title: "ЛАБ6", subject: networks, isDone: true),
            StudyTask(title: "ЛАБ7", subject: networks),
            StudyTask(title: "ЛАБ8", subject: networks),
            StudyTask(title: "ЛАБ9", subject: networks),
            
            StudyTask(title: "ЛАБ3", subject: ai, deadline: now.addingTimeInterval(-2 * day), link: classroom, isDone: true),
            StudyTask(title: "ЛАБ4", subject: ai, deadline: now.addingTimeInterval(12 * day), link: classroom),
            StudyTask(title: "ЛАБ5", subject: ai, deadline: now.addingTimeInterval(26 * day), link: classroom),
            
            StudyTask(title: "ЛАБ4", subject: graphics, isDone: true),
            StudyTask(title: "ЛАБ5", subject: graphics, isDone: true),
            StudyTask(title: "ЛАБ6", subject: graphics)
        ]
    }
}
