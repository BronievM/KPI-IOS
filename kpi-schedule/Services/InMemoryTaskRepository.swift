//
//  InMemoryTaskRepository.swift
//  kpi-schedule
//
//  Created by Maksym on 25.10.2026.
//

import Foundation
import Combine

/// Демонстраційна / тестова реалізація (усе в пам'яті)
final class InMemoryTaskRepository: TaskRepository {
    private let subject: CurrentValueSubject<[StudyTask], Never>

    init(tasks: [StudyTask] = []) {
        subject = CurrentValueSubject(tasks)
    }

    var tasksPublisher: AnyPublisher<[StudyTask], Never> {
        subject.eraseToAnyPublisher()
    }

    func allTasks() -> [StudyTask] {
        subject.value
    }

    func task(with id: UUID) -> StudyTask? {
        subject.value.first { $0.id == id }
    }

    func save(_ task: StudyTask) {
        var all = subject.value
        if let index = all.firstIndex(where: { $0.id == task.id }) {
            all[index] = task
        } else {
            all.append(task)
        }
        subject.send(all)
    }

    func delete(id: UUID) {
        subject.send(subject.value.filter { $0.id != id })
    }
}
