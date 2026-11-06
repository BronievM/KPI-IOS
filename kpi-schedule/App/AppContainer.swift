//
//  AppContainer.swift
//  kpi-schedule
//
//  Created by Maksym on 21.10.2026.
//  Updated by Maksym on 06.11.2026.
//

import Foundation

/// Composition root
/// Щоб перейти на демо-дані, підставити MockScheduleRepository().
enum AppContainer {
    /// Одне джерело розкладу на весь застосунок: з ним працюють і вкладка «Розклад», і форма завдання
    static let scheduleRepository: ScheduleRepository = makeScheduleRepository()

    private static func makeScheduleRepository() -> ScheduleRepository {
        if let mock = MockScheduleAPIService.fromLaunchArguments() {
            // демонстрація станів: окремий тимчасовий кеш, щоб не чіпати справжні дані
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("mock-api-cache", isDirectory: true)
            try? FileManager.default.removeItem(at: folder)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            return RemoteScheduleRepository(apiService: mock, cacheFolder: folder)
        }
        return RemoteScheduleRepository(apiService: APIClient())
    }

    static func makeScheduleViewModel() -> ScheduleViewModel {
        let repository = scheduleRepository

        return ScheduleViewModel(
            repository: repository,
            linkOpener: SystemLinkOpener(),
            clock: SystemScheduleClock()
        )
    }

    /// Завдання зберігаються локально (JSON у Documents)
    /// Щоб перейти на демо-дані без збереження: InMemoryTaskRepository(tasks: SampleTasks.make())
    static func makeTaskRepository() -> TaskRepository {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return FileTaskRepository(fileURL: documents.appendingPathComponent("tasks.json"),
                                  attachments: FileAttachmentStorage())
    }

    static func makeTaskScreenFactory(repository: TaskRepository) -> TaskScreenFactory {
        let attachments = FileAttachmentStorage()
        return TaskScreenFactory(
            repository: repository,
            subjects: SelectedGroupSubjectsProvider(repository: scheduleRepository),
            linkOpener: SystemLinkOpener(),
            attachments: attachments
        )
    }
}
