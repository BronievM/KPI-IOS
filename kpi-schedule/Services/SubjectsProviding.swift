//
//  SubjectsProviding.swift
//  kpi-schedule
//
//  Created by Maksym on 25.10.2026.
//

import Foundation

/// Провайдер доступних предметів.
protocol SubjectsProviding {
    func subjects() -> [String]
    /// Вибіркові предмети (за замовчуванням таких немає)
    func electiveSubjects() -> Set<String>
}

extension SubjectsProviding {
    func electiveSubjects() -> Set<String> { [] }
}

/// Формує список предметів на основі даних із розкладу.
struct ScheduleSubjectsProvider: SubjectsProviding {
    let repository: ScheduleRepository

    func subjects() -> [String] {
        guard let groups = try? repository.fetchGroups() else { return [] }
        var result: Set<String> = []
        for group in groups {
            let days = (try? repository.fetchWeeklySchedule(for: group)) ?? []
            for lesson in days.flatMap(\.lessons) {
                result.insert(lesson.subjectName)
            }
        }
        return result.sorted()
    }

    func electiveSubjects() -> Set<String> {
        guard let groups = try? repository.fetchGroups() else { return [] }
        var result: Set<String> = []
        for group in groups {
            let days = (try? repository.fetchWeeklySchedule(for: group)) ?? []
            for lesson in days.flatMap(\.lessons) where lesson.isElective {
                result.insert(lesson.subjectName)
            }
        }
        return result
    }
}
