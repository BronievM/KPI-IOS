//
//  TaskScreenFactory.swift
//  kpi-schedule
//
//  Created by Maksym on 25.10.2026.
//

import Foundation

/// Створює ViewModel екранів із потрібними залежностями
/// Coordinator користується фабрикою і не знає про конкретні репозиторії
final class TaskScreenFactory {
    private let repository: TaskRepository
    private let subjects: SubjectsProviding
    private let linkOpener: LinkOpening
    private let now: () -> Date
    private let attachments: AttachmentStoring

    init(repository: TaskRepository,
         subjects: SubjectsProviding,
         linkOpener: LinkOpening,
         now: @escaping () -> Date = Date.init,
         attachments: AttachmentStoring = FileAttachmentStorage()) {
        self.attachments = attachments
        self.repository = repository
        self.subjects = subjects
        self.linkOpener = linkOpener
        self.now = now
    }

    func makeListViewModel(navigator: TaskNavigating) -> TaskListViewModel {
        TaskListViewModel(repository: repository, navigator: navigator, now: now)
    }

    func makeDetailViewModel(id: UUID, navigator: TaskNavigating) -> TaskDetailViewModel {
        TaskDetailViewModel(taskID: id, repository: repository, navigator: navigator, linkOpener: linkOpener, now: now, attachments: attachments)
    }

    /// `id == nil` -> створення, інакше редагування наявного завдання.
    func makeFormViewModel(editing id: UUID?, navigator: TaskNavigating) -> TaskFormViewModel {
        let task = id.flatMap { repository.task(with: $0) }
        return TaskFormViewModel(task: task, repository: repository, subjects: subjects, navigator: navigator, now: now, attachments: attachments)
    }
}
