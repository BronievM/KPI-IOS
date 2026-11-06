//
//  Lesson.swift
//  kpi-schedule
//
//  Created by Maksym on 21.10.2026.
//  Updated by Maksym on 06.10.2026.
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
    var dates: [String]
    
    init(subjectName: String, teacher: String, type: LessonType, room: String? = nil, isOnline: Bool = false, link: String? = nil, startTime: LessonTime? = nil, isElective: Bool = false, dates: [String] = []) {
        self.id = UUID()
        self.subjectName = subjectName
        self.teacher = teacher
        self.type = type
        self.room = room
        self.isOnline = isOnline
        self.link = link
        self.startTime = startTime
        self.isElective = isElective
        self.dates = dates
    }

    func occurs(on dateKey: String?) -> Bool {
            guard let dateKey, !dates.isEmpty else { return true }
            return dates.contains(dateKey)
        }

        /// «Спец. заняття · 4 з 7» (nil для звичайних пар)
        func occurrenceText(on dateKey: String?) -> String? {
            guard !dates.isEmpty else { return nil }
            let sorted = dates.sorted()
            if let dateKey, let index = sorted.firstIndex(of: dateKey) {
                return "Спец. заняття · \(index + 1) з \(sorted.count)"
            }
            return "Спец. заняття"
        }

        /// «Далі: 09 лист · 23 лист · 07 груд» (до трьох наступних дат; nil для звичайних пар)
        func nextDatesText(after dateKey: String?) -> String? {
            guard let dateKey, !dates.isEmpty else { return nil }
            let months = ["січ", "лют", "бер", "квіт", "трав", "черв", "лип", "серп", "вер", "жовт", "лист", "груд"]
            let next = dates.sorted().filter { $0 > dateKey }.prefix(3).compactMap { date -> String? in
                let p = date.split(separator: "-")
                guard p.count == 3, let m = Int(p[1]), (1...12).contains(m) else { return nil }
                return "\(p[2]) \(months[m - 1])"
            }
            return next.isEmpty ? "Остання дата" : "Далі: " + next.joined(separator: " · ")
        }

    
    func getLocation() -> String {
        room ?? (isOnline ? "Онлайн" : "Аудиторія не вказана")
    }
}

/// Дати «спец. пар». Пара з непорожнім `dates` іде лише в ці дати, а не щотижня.
enum LessonDates {
    /// Приводить дату з API до `yyyy-MM-dd`. Неопізнаний формат повертає як є
    static func normalize(_ raw: String) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        let iso = text.prefix(10).split(separator: "-")
        if iso.count == 3, iso[0].count == 4,
           let y = Int(iso[0]), let m = Int(iso[1]), let d = Int(iso[2]) {
            return format(y, m, d)
        }
        let parts = text.split(whereSeparator: { $0 == "." || $0 == "/" })
        if parts.count == 3, parts[2].count == 4,
           let d = Int(parts[0]), let m = Int(parts[1]), let y = Int(parts[2]) {
            return format(y, m, d)
        }
        return text
    }

    static func key(for date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return format(c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private static func format(_ y: Int, _ m: Int, _ d: Int) -> String {
        String(format: "%04d-%02d-%02d", y, m, d)
    }
}
