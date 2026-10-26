//
//  AppContainer.swift
//  kpi-schedule
//
//  Created by Maksym on 21.10.2026.
//  Updated by Maksym on 25.10.2026.
//

import Foundation

/// Composition root
/// Щоб перейти на демо-дані, підставити MockScheduleRepository().
enum AppContainer {
    static func makeScheduleViewModel() -> ScheduleViewModel {
        ScheduleViewModel(
            repository: JSONScheduleRepository(json: SampleScheduleData.json),
            linkOpener: SystemLinkOpener(),
            clock: SystemScheduleClock()
        )
    }

    /// Завдання зберігаються локально (JSON у Documents).
    /// Щоб перейти на демо-дані без збереження: InMemoryTaskRepository(tasks: SampleTasks.make()).
    /// Одне сховище на весь застосунок (для «Завдання» і «Головна»).
    static func makeTaskRepository() -> TaskRepository {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return FileTaskRepository(fileURL: documents.appendingPathComponent("tasks.json"),
                                  attachments: FileAttachmentStorage())
    }

    static func makeTaskScreenFactory(repository: TaskRepository) -> TaskScreenFactory {
        let attachments = FileAttachmentStorage()
        let scheduleRepository = JSONScheduleRepository(json: SampleScheduleData.json)
        return TaskScreenFactory(
            repository: repository,
            subjects: ScheduleSubjectsProvider(repository: scheduleRepository),
            linkOpener: SystemLinkOpener(),
            attachments: attachments
        )
    }
}
