//
//  MockSheduleAPIService.swift
//  kpi-schedule
//
//  Created by Maksym on 06.11.2026.
//

import Foundation

/// Підміна ScheduleAPIService. Режими -api-mode
/// success, empty, offline, http500, badjson, flaky (перший запит розкладу падає, повтор успішний).
final class MockScheduleAPIService: ScheduleAPIService {
    enum Scenario: String {
        case success, empty, offline, http500, badjson, flaky
    }

    private let scenario: Scenario
    private let delayNanoseconds: UInt64
    private(set) var scheduleCalls = 0

    init(scenario: Scenario, delayNanoseconds: UInt64 = 800_000_000) {
        self.scenario = scenario
        self.delayNanoseconds = delayNanoseconds
    }

    /// nil, якщо аргумент `-api-mode` не передано (тоді працює реальний API)
    static func fromLaunchArguments(_ defaults: UserDefaults = .standard) -> MockScheduleAPIService? {
        guard let raw = defaults.string(forKey: "api-mode"),
              let scenario = Scenario(rawValue: raw) else { return nil }
        return MockScheduleAPIService(scenario: scenario)
    }

    func fetchGroups() async throws -> [CampusGroup] {
        try await pause()
        try failIfNeeded()
        if scenario == .empty { return [.default] }
        return [.default,
                CampusGroup(id: 1, name: "ІО-41", faculty: "ФІОТ"),
                CampusGroup(id: 2, name: "КВ-31", faculty: "ФПМ")]
    }

    func fetchSchedule(groupId: Int) async throws -> CampusScheduleResponse {
        try await pause()
        scheduleCalls += 1
        if scenario == .flaky && scheduleCalls == 1 {
            throw NetworkError.transportError(URLError(.notConnectedToInternet))
        }
        try failIfNeeded()
        if scenario == .empty {
            return CampusScheduleResponse(scheduleFirstWeek: [], scheduleSecondWeek: [])
        }
        return Self.sample
    }

    private func pause() async throws {
        try await Task.sleep(nanoseconds: delayNanoseconds)
    }

    private func failIfNeeded() throws {
        switch scenario {
        case .offline:
            throw NetworkError.transportError(URLError(.notConnectedToInternet))
        case .http500:
            throw NetworkError.invalidHTTPStatus(500)
        case .badjson:
            throw NetworkError.decodingError(
                DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Mock: неправильний формат")))
        case .success, .empty, .flaky:
            break
        }
    }

    private static var sample: CampusScheduleResponse {
        func pair(_ name: String, _ time: String, _ type: String, _ teacher: String, room: String?) -> CampusPair {
            CampusPair(name: name, time: time, type: type,
                       lecturer: .init(name: teacher),
                       location: .init(title: room, uri: nil), dates: nil)
        }
        let first = [
            CampusDay(day: "Пн", pairs: [pair("Розробка мобільних застосувань під iOS", "10:25", "лек", "Галицький Д. В.", room: nil)]),
            CampusDay(day: "Ср", pairs: [pair("Розробка мобільних застосувань під iOS", "08:30", "лаб", "Галицький Д. В.", room: "18-416")])
        ]
        let second = [
            CampusDay(day: "Вт", pairs: [pair("Комп'ютерні мережі", "12:20", "лаб", "Алєнін О. І.", room: "18-516")])
        ]
        return CampusScheduleResponse(scheduleFirstWeek: first, scheduleSecondWeek: second)
    }
}
