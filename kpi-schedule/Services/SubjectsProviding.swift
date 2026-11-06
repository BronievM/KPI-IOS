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

/// Предмети для форми завдання. Реальний розклад вибраної групи (з кешу API),
/// лише ті, які студент залишив у "Мої предмети"
struct SelectedGroupSubjectsProvider: SubjectsProviding {
    let repository: ScheduleRepository
    var electives: ElectiveStoring = LocalElectiveStore()
    var selectedGroup: () -> String = { UserDefaults.standard.string(forKey: "selectedGroup") ?? "" }

    private func lessons() -> [Lesson] {
        let group = selectedGroup()
        guard !group.isEmpty else { return [] }
        let all = ((try? repository.fetchWeeklySchedule(for: group)) ?? []).flatMap(\.lessons)
        guard let chosen = electives.selection(for: group) else { return all }
        return all.filter { chosen.contains($0.subjectName) }
    }

    func subjects() -> [String] {
        Array(Set(lessons().map(\.subjectName))).sorted()
    }

    func electiveSubjects() -> Set<String> {
        Set(lessons().filter(\.isElective).map(\.subjectName))
    }
}
