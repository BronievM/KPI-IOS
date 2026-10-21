//
//  ScheduleRepository.swift
//  kpi-schedule
//
//  Created by Maksym on 20.10.2026.
//

import Foundation

protocol ScheduleRepository {
    func fetchGroups() throws -> [String]
    func fetchWeeklySchedule(for group: String) throws -> [DailySchedule]
}
