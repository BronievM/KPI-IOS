//
//  SampleSchedule.swift
//  kpi-schedule
//
//  Created by Maksym on 25.10.2026.
//

import Foundation

enum SampleScheduleData {
    static let json = """
    [
        { "group": "ІО-42", "day": "Понеділок", "week": "перший", "time": "08:30", "subject": "Комп’ютерна графіка та мультимедіа", "teacher": "Родіонов П. Ю.", "type": "Лекція", "online": true, "elective": true },
        { "group": "ІО-42", "day": "Понеділок", "week": "перший", "time": "10:25", "subject": "Розробка мобільних застосувань під iOS", "teacher": "Галицький Д. В.", "type": "Лекція", "online": true, "elective": true },
        { "group": "ІО-42", "day": "Понеділок", "week": "перший", "time": "12:20", "subject": "Інформаційне забезпечення промислових роботів", "teacher": "Нікітін В. А.", "type": "Лекція", "online": true, "elective": true },
        { "group": "ІО-42", "day": "Понеділок", "week": "перший", "time": "14:15", "subject": "Розробка мобільних застосувань під iOS", "teacher": "Галицький Д. В.", "type": "Лекція", "online": true, "elective": true },
        
        { "group": "ІО-42", "day": "Вівторок", "week": "перший", "time": "12:20", "subject": "Паралельні та розподілені обчислення", "teacher": "Корочкін О. В.", "type": "Лабораторна", "online": false, "room": "18-515" },
        { "group": "ІО-42", "day": "Вівторок", "week": "перший", "time": "14:15", "subject": "Архітектура комп'ютерів. Частина 2. Процесори", "teacher": "Каплунов А. В.", "type": "Лабораторна", "online": false, "room": "18-535" },
        
        { "group": "ІО-42", "day": "Середа", "week": "перший", "time": "08:30", "subject": "Розробка мобільних застосувань під iOS", "teacher": "Галицький Д. В.", "type": "Лабораторна", "online": false, "room": "18-416", "elective": true, "link": "https://github.com/BronievM/KPI-IOS/tree/main" },
        
        { "group": "ІО-42", "day": "Четвер", "week": "перший", "time": "08:30", "subject": "Архітектура комп'ютерів. Частина 2. Процесори", "teacher": "Клименко І. А.", "type": "Лекція", "online": true },
        { "group": "ІО-42", "day": "Четвер", "week": "перший", "time": "10:25", "subject": "Паралельні та розподілені обчислення", "teacher": "Корочкін О. В.", "type": "Лекція", "online": true },
        { "group": "ІО-42", "day": "Четвер", "week": "перший", "time": "12:20", "subject": "Комп'ютерні мережі", "teacher": "Кулаков Ю. О.", "type": "Лекція", "online": true },
        
        { "group": "ІО-42", "day": "Субота", "week": "перший", "time": "14:15", "subject": "Практичний курс іноземної мови професійного спрямування. Частина 1", "teacher": "Дорошенко Л. В.", "type": "Практика", "online": true },

        { "group": "ІО-42", "day": "Понеділок", "week": "другий", "time": "08:30", "subject": "Комп’ютерна графіка та мультимедіа", "teacher": "Родіонов П. Ю.", "type": "Лекція", "online": true, "elective": true },
        { "group": "ІО-42", "day": "Понеділок", "week": "другий", "time": "10:25", "subject": "Розробка мобільних застосувань під iOS", "teacher": "Галицький Д. В.", "type": "Лекція", "online": true, "elective": true },
        { "group": "ІО-42", "day": "Понеділок", "week": "другий", "time": "12:20", "subject": "Інформаційне забезпечення промислових роботів", "teacher": "Нікітін В. А.", "type": "Лекція", "online": true, "elective": true },
        { "group": "ІО-42", "day": "Понеділок", "week": "другий", "time": "16:10", "subject": "Комп’ютерна графіка та мультимедіа", "teacher": "Родіонов П. Ю.", "type": "Лекція", "online": true, "elective": true },
        
        { "group": "ІО-42", "day": "Вівторок", "week": "другий", "time": "10:25", "subject": "Вступ до штучного інтелекту в комп’ютерній інженерії", "teacher": "Кочура Ю. П.", "type": "Лабораторна", "online": false, "room": "18-538", "elective": true },
        { "group": "ІО-42", "day": "Вівторок", "week": "другий", "time": "12:20", "subject": "Комп'ютерні мережі", "teacher": "Алєнін О. І.", "type": "Лабораторна", "online": false, "room": "18-516" },
        
        { "group": "ІО-42", "day": "Середа", "week": "другий", "time": "08:30", "subject": "Інформаційне забезпечення промислових роботів", "teacher": "Тюляков Д. І.", "type": "Лабораторна", "online": false, "room": "18-534", "elective": true },
        { "group": "ІО-42", "day": "Середа", "week": "другий", "time": "10:25", "subject": "Комп’ютерна графіка та мультимедіа", "teacher": "Родіонов П. Ю.", "type": "Лабораторна", "online": false, "room": "18-417", "elective": true },
        
        { "group": "ІО-42", "day": "Четвер", "week": "другий", "time": "08:30", "subject": "Архітектура комп'ютерів. Частина 2. Процесори", "teacher": "Клименко І. А.", "type": "Лекція", "online": true },
        { "group": "ІО-42", "day": "Четвер", "week": "другий", "time": "10:25", "subject": "Паралельні та розподілені обчислення", "teacher": "Корочкін О. В.", "type": "Лекція", "online": true },
        { "group": "ІО-42", "day": "Четвер", "week": "другий", "time": "12:20", "subject": "Комп'ютерні мережі", "teacher": "Кулаков Ю. О.", "type": "Лекція", "online": true },
        { "group": "ІО-42", "day": "Четвер", "week": "другий", "time": "14:15", "subject": "Комп'ютерні мережі", "teacher": "Кулаков Ю. О.", "type": "Лекція", "online": true },
        { "group": "ІО-42", "day": "Четвер", "week": "другий", "time": "16:10", "subject": "Вступ до штучного інтелекту в комп’ютерній інженерії", "teacher": "Таран В. І.", "type": "Лекція", "online": true, "elective": true },
        
        { "group": "ІО-42", "day": "Субота", "week": "другий", "time": "14:15", "subject": "Практичний курс іноземної мови професійного спрямування. Частина 1", "teacher": "Дорошенко Л. В.", "type": "Практика", "online": true }
    ]
    """
}
