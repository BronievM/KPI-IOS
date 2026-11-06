//
//  ElectiveStore.swift
//  kpi-schedule
//
//  Created by Maksym on 06.11.2026.
//

import Foundation
 
/// Вибіркові предмети
/// nil = вибір ще не робився (показуємо все)
protocol ElectiveStoring {
    func selection(for group: String) -> Set<String>?
    func save(_ selection: Set<String>, for group: String)
}
 
/// Зберігає вибір у UserDefaults
struct LocalElectiveStore: ElectiveStoring {
    private let defaults: UserDefaults
 
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
 
    private func key(_ group: String) -> String { "subjects.\(group)" }
 
    func selection(for group: String) -> Set<String>? {
        guard let list = defaults.array(forKey: key(group)) as? [String] else { return nil }
        return Set(list)
    }
 
    func save(_ selection: Set<String>, for group: String) {
        defaults.set(selection.sorted(), forKey: key(group))
    }
}
 
/// Для тестів
final class InMemoryElectiveStore: ElectiveStoring {
    private var storage: [String: Set<String>] = [:]
    init() {}
    func selection(for group: String) -> Set<String>? { storage[group] }
    func save(_ selection: Set<String>, for group: String) { storage[group] = selection }
}
 
/// Предмет для екрана вибору
struct ElectiveOption: Identifiable, Equatable {
    let name: String
    let teachers: [String]
    /// Здогадка: предмет, імовірно, вибірковий. Лише підказка в меню
    var likelyElective = false
    var id: String { name }
}
