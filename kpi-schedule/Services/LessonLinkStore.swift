//
//  LessonLinkStore.swift
//  kpi-schedule
//
//  Created by Maksym on 06.11.2026.
//

import Foundation

/// Збережені користувачем лінки
protocol LessonLinkStoring {
    func link(subject: String, type: LessonType) -> String?
    /// `nil` видаляє лінк
    func save(_ link: String?, subject: String, type: LessonType)
}

/// Зберігає лінки в UserDefaults
struct LocalLessonLinkStore: LessonLinkStoring {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    private func key(_ subject: String, _ type: LessonType) -> String {
        "lessonLink.\(type.rawValue)|\(subject)"
    }

    func link(subject: String, type: LessonType) -> String? {
        defaults.string(forKey: key(subject, type))
    }

    func save(_ link: String?, subject: String, type: LessonType) {
        if let link { defaults.set(link, forKey: key(subject, type)) }
        else { defaults.removeObject(forKey: key(subject, type)) }
    }
}

/// Для тестів
final class InMemoryLessonLinkStore: LessonLinkStoring {
    private var storage: [String: String] = [:]
    init() {}
    func link(subject: String, type: LessonType) -> String? { storage["\(type.rawValue)|\(subject)"] }
    func save(_ link: String?, subject: String, type: LessonType) { storage["\(type.rawValue)|\(subject)"] = link }
}
