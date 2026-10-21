//
//  JSONScheduleRepository.swift
//  kpi-schedule
//
//  Created by Maksym on 20.10.2026.
//

import Foundation

/// A repository that loads schedule data from a JSON string and provides group and weekly schedule information.
struct JSONScheduleRepository: ScheduleRepository {
    private let data: Data
    private let adapter = LessonDTOAdapter()

    init(json: String) {
        self.data = Data(json.utf8)
    }

    func fetchGroups() throws -> [String] {
        let dtos = try JSONDecoder().decode([LessonDTO].self, from: data)
        var groups: [String] = []
        for dto in dtos where !groups.contains(dto.group) {
            groups.append(dto.group)
        }
        return groups
    }

    func fetchWeeklySchedule(for group: String) throws -> [DailySchedule] {
       let dtos = try JSONDecoder().decode([LessonDTO].self, from: data)
       return adapter.adapt(dtos.filter { $0.group == group })
    }
}
