//
//  TaskDetailViewModel.swift
//  kpi-schedule
//
//  Created by Maksym on 25.10.2026.
//

import Foundation
import Combine

final class TaskDetailViewModel: ObservableObject {
    @Published private(set) var task: StudyTask?
    @Published var showDeleteConfirmation = false
    /// URL файлу для перегляду в Quick Look
    @Published var previewURL: URL?

    private let taskID: UUID
    private let repository: TaskRepository
    private weak var navigator: TaskNavigating?
    private let linkOpener: LinkOpening
    private let now: () -> Date
    private let attachments: AttachmentStoring
    private var cancellable: AnyCancellable?

    init(taskID: UUID,
         repository: TaskRepository,
         navigator: TaskNavigating?,
         linkOpener: LinkOpening,
         now: @escaping () -> Date = Date.init,
         attachments: AttachmentStoring = FileAttachmentStorage()) {
        self.attachments = attachments
        self.taskID = taskID
        self.repository = repository
        self.navigator = navigator
        self.linkOpener = linkOpener
        self.now = now

        // Передаємо на екран лише id: актуальні дані беремо зі сховища, тому екран оновлюється сам
        cancellable = repository.tasksPublisher
            .map { tasks in tasks.first { $0.id == taskID } }
            .sink { [weak self] task in self?.task = task }
    }

    var deadlineInfo: DeadlineInfo? {
        guard let task = task else { return nil }
        return DeadlineInfo(deadline: task.deadline, isDone: task.isDone, now: now())
    }

    func toggleDone() {
        guard var current = task else { return }
        current.isDone.toggle()
        repository.save(current)
    }

    func openLink() {
        guard let link = task?.link, let url = URL(string: link) else { return }
        linkOpener.open(url)
    }

    func open(_ attachment: TaskAttachment) {
        let url = attachments.fileURL(for: attachment, taskID: taskID)
        // файл міг зникнути: тоді нічого не відкриваємо
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        previewURL = url
    }

    /// Текст для ShareLink
    var shareText: String? {
        guard let task = task else { return nil }
        var lines = ["\(task.title) — \(task.subject)"]
        if let deadline = task.deadline {
            let style = Date.FormatStyle(date: .long, time: .shortened).locale(Locale(identifier: "uk_UA"))
            lines.append("Дедлайн: \(deadline.formatted(style))")
        }
        if !task.note.isEmpty { lines.append(task.note) }
        if let link = task.link { lines.append("Матеріали: \(link)") }
        return lines.joined(separator: "\n")
    }

    func editTapped() { navigator?.showEdit(id: taskID) }
    func deleteTapped() { showDeleteConfirmation = true }

    func deleteConfirmed() {
        navigator?.popToList()          // Закриваємо екран перед видаленням
        repository.delete(id: taskID)
    }
    
    func showInSchedule() {
        guard let subject = task?.subject else { return }
        navigator?.showInSchedule(subject: subject)
    }
}
