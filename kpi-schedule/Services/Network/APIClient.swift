//
//  APIClient.swift
//  kpi-schedule
//
//  Created by Maksym on 06.11.2026.
//

import Foundation

// Моделі даних, що відповідають JSON-структурам API
struct CampusGroup: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let name: String
    let faculty: String
    static let `default` = CampusGroup(id: 4382, name: "ІО-42", faculty: "ФІОТ")
}

// Модель даних для одного пари (заняття) у розкладі
struct CampusPair: Codable {
    let name: String
    let time: String?
    let type: String?
    let lecturer: Lecturer?
    let location: Location?
    let dates: [String]?
    
    struct Lecturer: Codable {
        let name: String?
    }
    
    struct Location: Codable {
        let title: String?
        let uri: String?
    }
}

// Модель даних для розкладу на тиждень
struct CampusScheduleResponse: Codable {
    let scheduleFirstWeek: [CampusDay]?
    let scheduleSecondWeek: [CampusDay]?
}

// Модель даних для одного дня у розкладі
struct CampusDay: Codable {
    let day: String
    let pairs: [CampusPair]?
}

// Протокол для мережевого шару, що визначає методи для отримання груп та розкладу
protocol ScheduleAPIService {
    func fetchGroups() async throws -> [CampusGroup]
    func fetchSchedule(groupId: Int) async throws -> CampusScheduleResponse
}

// Обгортка для декодування JSON-об'єкта з ключем "data", що містить масив груп
private struct GroupsWrapper: Decodable {
    let data: [CampusGroup]
}

/// Мережевий шар (лише запити, перевірка HTTP-статусу й декодування)
///
/// Запит: `GET https://api.campus.kpi.ua/schedule/groups` та
///        `GET https://api.campus.kpi.ua/schedule/lessons?groupId=<id>`
final class APIClient: ScheduleAPIService {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = URL(string: "https://api.campus.kpi.ua")!,
         session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func fetchGroups() async throws -> [CampusGroup] {
        let data = try await loadData(from: baseURL.appendingPathComponent("schedule/groups"))
        do {
            let decoder = JSONDecoder()
            // API може віддати і масив, і обгортку {"data": [...]}
            if let groups = try? decoder.decode([CampusGroup].self, from: data) {
                return groups
            }
            return try decoder.decode(GroupsWrapper.self, from: data).data
        } catch {
            throw NetworkError.decodingError(error)
        }
    }

    func fetchSchedule(groupId: Int) async throws -> CampusScheduleResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("schedule/lessons"),
                                       resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "groupId", value: String(groupId))]
        guard let url = components?.url else { throw NetworkError.invalidURL }

        let data = try await loadData(from: url)
        do {
            return try JSONDecoder().decode(CampusScheduleResponse.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }

    /// Виконує запит і повертає дані лише для статусу 2xx.
    private func loadData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw NetworkError.transportError(error)   // немає інтернету, таймаут тощо
        }

        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidHTTPStatus(0)
        }
        guard (200...299).contains(http.statusCode) else {
            throw NetworkError.invalidHTTPStatus(http.statusCode)
        }
        return data
    }
}

enum NetworkError: Error, LocalizedError {
    case transportError(Error)
    case invalidHTTPStatus(Int)
    case decodingError(Error)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .transportError:
            return "Немає з'єднання з сервером. Перевірте інтернет і спробуйте ще раз"
        case .invalidHTTPStatus(let code):
            return "Сервер відповів помилкою (код \(code)). Спробуйте пізніше"
        case .decodingError:
            return "Сервер повернув дані в неочікуваному форматі"
        case .invalidURL:
            return "Неправильна адреса запиту"
        }
    }
}

enum GroupSearch {
    static func filter(_ groups: [CampusGroup], query: String) -> [CampusGroup] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return groups }
        return groups.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) ||
            $0.faculty.localizedCaseInsensitiveContains(trimmed)
        }
    }
}
