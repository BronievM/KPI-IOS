//
//  APIClient.swift
//  kpi-schedule
//
//  Created by Maksym on 06.11.2026.
//  Updated on 24.11.2026
//

import Foundation

struct CampusGroup: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let name: String
    let faculty: String
    static let `default` = CampusGroup(id: 4382, name: "ІО-42", faculty: "ФІОТ")
}

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

struct CampusScheduleResponse: Codable {
    let scheduleFirstWeek: [CampusDay]?
    let scheduleSecondWeek: [CampusDay]?
}

struct CampusDay: Codable {
    let day: String
    let pairs: [CampusPair]?
}

protocol ScheduleAPIService {
    func fetchGroups() async throws -> [CampusGroup]
    func fetchSchedule(groupId: Int) async throws -> CampusScheduleResponse
}

private struct GroupsWrapper: Decodable {
    let data: [CampusGroup]
}

/// Мережевий шар: лише запити, перевірка HTTP-статусу й декодування.
/// Екрани й ViewModel працюють з ним тільки через протокол `ScheduleAPIService`.
///
/// Запит: `GET https://api.campus.kpi.ua/schedule/groups` та
///        `GET https://api.campus.kpi.ua/schedule/lessons?groupId=<id>`
final class APIClient: ScheduleAPIService {
    private let baseURL: URL
    private let session: URLSession
    
    /// `session` передається ззовні, тому в тестах можна підставити URLProtocol-заглушку
    // З 16.11.2026 КБІС КПІ обмежило прямий доступ до API для сторонніх клієнтів (403 без Origin/Referer від schedule.kpi.ua)
    init(baseURL: URL = URL(string: "https://api.campus.kpi.ua")!,
         session: URLSession? = nil) {
        self.baseURL = baseURL
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 15
            config.timeoutIntervalForResource = 30
            config.httpAdditionalHeaders = [
                "Accept": "application/json, text/plain, */*",
                "Accept-Language": "uk-UA,uk;q=0.9,en-US;q=0.8,en;q=0.7",
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0",
                "Origin": "https://schedule.kpi.ua",
                "Referer": "https://schedule.kpi.ua/"
            ]
            self.session = URLSession(configuration: config)
        }
    }
    
    func fetchGroups() async throws -> [CampusGroup] {
        let data = try await loadData(from: baseURL.appendingPathComponent("schedule/groups"))
        do {
            let decoder = JSONDecoder()
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
    /// Тут розрізняються транспортна помилка та HTTP-помилка; декодування відбувається вже після цього.
    private func loadData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.assumesHTTP3Capable = false
        
        var lastError: Error?
        
        for attempt in 0..<2 {
            do {
                let (data, response) = try await session.data(for: request)
                
                guard let http = response as? HTTPURLResponse else {
                    throw NetworkError.invalidHTTPStatus(0)
                }
                guard (200...299).contains(http.statusCode) else {
                    throw NetworkError.invalidHTTPStatus(http.statusCode)
                }
                return data
            } catch let error as URLError where error.code == .cancelled {
                throw CancellationError()
            } catch let error as URLError where error.code == .networkConnectionLost && attempt == 0 {
                lastError = error
                continue
            } catch let error as NetworkError {
                throw error
            } catch {
                throw NetworkError.transportError(error)
            }
        }
        
        throw NetworkError.transportError(lastError ?? URLError(.networkConnectionLost))
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
            return "Немає з'єднання з сервером. Перевірте інтернет і спробуйте ще раз."
        case .invalidHTTPStatus(let code):
            return "Сервер відповів помилкою (код \(code)). Спробуйте пізніше."
        case .decodingError:
            return "Сервер повернув дані в неочікуваному форматі."
        case .invalidURL:
            return "Неправильна адреса запиту."
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
