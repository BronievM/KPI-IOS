//
//  ScheduleRepository.swift
//  kpi-schedule
//
//  Created by Maksym on 21.10.2026.
//

import Foundation

/// Абстракція джерела даних розкладу
protocol ScheduleRepository {
    func fetchGroups() throws -> [String]
    func fetchWeeklySchedule(for group: String) throws -> [DailySchedule]
}
