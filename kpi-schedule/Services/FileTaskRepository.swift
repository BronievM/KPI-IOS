//
//  FileTaskRepository.swift
//  kpi-schedule
//
//  Created by Maksym on 25.10.2026.
//

import Foundation
import Combine

/// Локальне збереження завдань у JSON
/// Обгортка над InMemoryTaskRepository, що автоматично записує зміни на диск
final class FileTaskRepository: TaskRepository {
    private let store: InMemoryTaskRepository
    private let attachments: AttachmentStoring?
    private var cancellable: AnyCancellable?

    init(fileURL: URL, fallback: [StudyTask] = SampleTasks.make(), attachments: AttachmentStoring? = nil) {
        self.attachments = attachments
        let initial = FileTaskRepository.load(from: fileURL) ?? fallback
        store = InMemoryTaskRepository(tasks: initial)
        // Ігноруємо початкове значення, щоб зайвий раз не перезаписувати файл при ініціалізації
        cancellable = store.tasksPublisher.dropFirst().sink { tasks in
            FileTaskRepository.write(tasks, to: fileURL)
        }
    }

    var tasksPublisher: AnyPublisher<[StudyTask], Never> { store.tasksPublisher }
    func allTasks() -> [StudyTask] { store.allTasks() }
    func task(with id: UUID) -> StudyTask? { store.task(with: id) }
    func save(_ task: StudyTask) { store.save(task) }
    func delete(id: UUID) {
        store.delete(id: id)
        attachments?.removeAll(for: id)     // Видаляємо файли разом із завданням
    }

    private static func load(from url: URL) -> [StudyTask]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([StudyTask].self, from: data)
    }

    private static func write(_ tasks: [StudyTask], to url: URL) {
        do {
            let data = try JSONEncoder().encode(tasks)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Не вдалося зберегти завдання: \(error)")
        }
    }
}
