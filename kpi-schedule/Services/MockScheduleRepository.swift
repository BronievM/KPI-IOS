//
//  MockScheduleRepository.swift
//  kpi-schedule
//
//  Created by Maksym on 21.10.2026.
//  Updated by Maksym on 25.10.2026.
//

import Foundation

/// Тестовий репозиторій із хардкод-даними в пам'яті
struct MockScheduleRepository: ScheduleRepository {
    var schedules: [(group: String, days: [DailySchedule])]

    init(schedules: [(group: String, days: [DailySchedule])]? = nil) {
        if let schedules { self.schedules = schedules; return }

        let monday = DailySchedule(dayOfWeek: "Понеділок", weekType: .first)
        monday.addLesson(
            LessonBuilder().subject("Демонстраційний предмет").teacher("Викладач Д. Д.").type(.lecture).online().build()
        )
        self.schedules = [(group: "ДЕМО-1", days: [monday])]
    }

    func fetchGroups() throws -> [String] { schedules.map(\.group) }

    func fetchWeeklySchedule(for group: String) throws -> [DailySchedule] {
        schedules.first { $0.group == group }?.days ?? []
    }
}
