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
    /// Групи з факультетами (для екрана вибору групи)
    func fetchGroupDirectory() throws -> [CampusGroup]
    
    // асинхронні методи для оновлення кешу з мережі
    func refreshGroups() async throws
    func refreshSchedule(for group: String) async throws
}

extension ScheduleRepository {
    /// Для локальних і мок-репозиторіїв факультетів немає
    func fetchGroupDirectory() throws -> [CampusGroup] {
        try fetchGroups().enumerated().map { CampusGroup(id: $0.offset, name: $0.element, faculty: "Загальні") }
    }
    // Порожня реалізація для локальних та мок-репозиторіїв
    func refreshGroups() async throws { }
    func refreshSchedule(for group: String) async throws { }
}
