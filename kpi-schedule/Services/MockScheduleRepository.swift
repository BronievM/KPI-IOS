//
//  MockScheduleRepository.swift
//  kpi-schedule
//
//  Created by Maksym on 20.10.2026.
//

import Foundation

struct MockScheduleRepository: ScheduleRepository {
    var schedules: [(group: String, days: [DailySchedule])]

    init(schedules: [(group: String, days: [DailySchedule])]? = nil) {
        if let schedules { self.schedules = schedules; return }

        let monday = DailySchedule(dayOfWeek: "Monday", weekType: .first)
        monday.addLesson(LessonBuilder().subject("Demo").teacher("Demo").type(.lecture).online().build())
        self.schedules = [(group: "Demo", days: [monday])]
    }

    func fetchGroups() throws -> [String] {
        schedules.map(\.group)
    }

    func fetchWeeklySchedule(for group: String) throws -> [DailySchedule] {
        schedules.first { $0.group == group }?.days ?? []
    }
}
