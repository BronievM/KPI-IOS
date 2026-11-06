//
//  RemoteScheduleRepository.swift
//  kpi-schedule
//
//  Created by Maksym on 06.11.2026.
//

import Foundation

// MARK: - Репозиторій

/// Розклад з API КПІ з кешем на диску
final class RemoteScheduleRepository: ScheduleRepository {
    private let apiService: ScheduleAPIService
    private let cacheFolder: URL
    private let mapper = CampusScheduleMapper()
    private let adapter = LessonDTOAdapter()
    
    // Блокування для безпечного доступу з різних потоків
    private let lock = NSLock()
    private var cachedDTOs: [LessonDTO] = []
    
    init(
        apiService: ScheduleAPIService = APIClient(),
        cacheFolder: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    ) {
        self.apiService = apiService
        self.cacheFolder = cacheFolder
        if !FileManager.default.fileExists(atPath: groupsCacheURL.path) {
                    let defaultGroup = CampusGroup.default // ІО-42 (id: 4382)
                    if let data = try? JSONEncoder().encode([defaultGroup]) {
                        try? data.write(to: groupsCacheURL, options: .atomic)
                    }
                }
    }
    
    // MARK: - Локальні шляхи

    private var groupsCacheURL: URL {
        cacheFolder.appendingPathComponent("groups-cache.json")
    }

    private func scheduleCacheURL(for groupId: Int) -> URL {
        cacheFolder.appendingPathComponent("schedule-\(groupId).json")
    }

    // MARK: - ScheduleRepository (Робота з групами)

    func fetchGroups() throws -> [String] {
        // Читаємо групи з локального файлу (синхронно)
        guard let data = try? Data(contentsOf: groupsCacheURL),
              let cachedGroups = try? JSONDecoder().decode([CampusGroup].self, from: data) else {
            return []
        }
        return cachedGroups.map { $0.name }
    }
    
    func fetchGroupDirectory() throws -> [CampusGroup] {
        guard let data = try? Data(contentsOf: groupsCacheURL),
              let groups = try? JSONDecoder().decode([CampusGroup].self, from: data) else {
            return []
        }
        return groups
    }

    func refreshGroups() async throws {
        // Звертаємось до APIClient
        let groups = try await apiService.fetchGroups()
        // Зберігаємо в кеш
        if let data = try? JSONEncoder().encode(groups) {
            try? data.write(to: groupsCacheURL, options: .atomic)
        }
    }

    // MARK: - ScheduleRepository (Робота з розкладом)

    func fetchWeeklySchedule(for group: String) throws -> [DailySchedule] {
        // Знаходимо ID групи з кешу
        guard let data = try? Data(contentsOf: groupsCacheURL),
              let cachedGroups = try? JSONDecoder().decode([CampusGroup].self, from: data),
              let groupModel = cachedGroups.first(where: { $0.name == group }) else {
            return []
        }
        
        // Читаємо розклад з кешу
        // Немає кешу або він пошкоджений - повертаємо порожньо, мережа оновить
        guard let scheduleData = try? Data(contentsOf: scheduleCacheURL(for: groupModel.id)),
              let dtos = try? mapper.dtos(from: scheduleData, groupName: group) else {
            return []
        }
        
        // Повертаємо адаптовані моделі для UI
        lock.lock(); defer { lock.unlock() }
        cachedDTOs = dtos
        return adapter.adapt(dtos)
    }
    
    func refreshSchedule(for group: String) async throws {
        // Знаходимо ID групи з кешу
        guard let data = try? Data(contentsOf: groupsCacheURL),
              let cachedGroups = try? JSONDecoder().decode([CampusGroup].self, from: data),
              let groupModel = cachedGroups.first(where: { $0.name == group }) else {
            throw NetworkError.invalidURL
        }
        
        // Йдемо в мережу через APIClient
        let response = try await apiService.fetchSchedule(groupId: groupModel.id)
        
        // Зберігаємо новий JSON у кеш
        if let encoded = try? JSONEncoder().encode(response) {
            try? encoded.write(to: scheduleCacheURL(for: groupModel.id), options: .atomic)
        }
    }
}
