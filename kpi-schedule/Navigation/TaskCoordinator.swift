//
//  TaskCoordinator.swift
//  kpi-schedule
//
//  Created by Maksym on 25.10.2026.
//

import Foundation

/// Coordinator/Router потоку "Завдання". Єдине місце, де зберігається стан навігації та створюються ViewModel екранів.
/// Посилання: Coordinator -> listViewModel (strong), ViewModel -> Coordinator (weak)
final class TaskCoordinator: ObservableObject, TaskNavigating {
    @Published var path: [TaskRoute] = []
    @Published var sheet: TaskSheet?

    private let factory: TaskScreenFactory

    private(set) lazy var listViewModel: TaskListViewModel = self.factory.makeListViewModel(navigator: self)

    init(factory: TaskScreenFactory) {
        self.factory = factory
    }

    // MARK: TaskNavigating

    func showDetail(id: UUID) {
        // захист від подвійного тапу: той самий екран двічі не відкриваємо
        guard path.last != .detail(id) else { return }
        path.append(.detail(id))
    }

    func showCreate() {
        guard sheet == nil else { return }
        sheet = .create
    }

    func showEdit(id: UUID) {
        guard sheet == nil else { return }
        sheet = .edit(id)
    }

    func dismissSheet() {
        sheet = nil
    }

    func popToList() {
        path.removeAll()
    }

    func showInSchedule(subject: String) {
        NotificationCenter.default.post(name: .showInSchedule, object: subject)
    }

    // MARK: Створення екранів

    func makeDetailViewModel(id: UUID) -> TaskDetailViewModel {
        factory.makeDetailViewModel(id: id, navigator: self)
    }

    func makeFormViewModel(for sheet: TaskSheet) -> TaskFormViewModel {
        switch sheet {
        case .create:          return factory.makeFormViewModel(editing: nil, navigator: self)
        case .edit(let id):    return factory.makeFormViewModel(editing: id, navigator: self)
        }
    }
}
