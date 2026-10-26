//
//  TaskRepository.swift
//  kpi-schedule
//
//  Created by Maksym on 25.10.2026.
//

import Foundation
import Combine

/// Сховище завдань
protocol TaskRepository {
    var tasksPublisher: AnyPublisher<[StudyTask], Never> { get }
    func allTasks() -> [StudyTask]
    func task(with id: UUID) -> StudyTask?
    /// Додає нове завдання або оновлює існуюче
    func save(_ task: StudyTask)
    func delete(id: UUID)
}

/// Сховище файлів (відокремлено для можливої міграції на сервер)
protocol AttachmentStoring {
    /// Копіює зовнішній файл у внутрішнє сховище
    func importFile(from source: URL, taskID: UUID) throws -> TaskAttachment
    func fileURL(for attachment: TaskAttachment, taskID: UUID) -> URL
    func remove(_ attachment: TaskAttachment, taskID: UUID)
    /// Видаляє всі прикріплені файли при видаленні самого завдання
    func removeAll(for taskID: UUID)
}

/// Локальне збереження у Documents/Attachments.
struct FileAttachmentStorage: AttachmentStoring {
    private let root: URL

    init(root: URL = FileAttachmentStorage.defaultRoot) {
        self.root = root
    }

    static var defaultRoot: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Attachments", isDirectory: true)
    }

    func importFile(from source: URL, taskID: UUID) throws -> TaskAttachment {
        // Файли з «Файлів» / iCloud потребують security-scoped доступу.
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        let attachment = TaskAttachment(fileName: source.lastPathComponent)
        let target = fileURL(for: attachment, taskID: taskID)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: source, to: target)
        return attachment
    }

    func fileURL(for attachment: TaskAttachment, taskID: UUID) -> URL {
        folder(for: attachment, taskID: taskID).appendingPathComponent(attachment.fileName)
    }

    func remove(_ attachment: TaskAttachment, taskID: UUID) {
        try? FileManager.default.removeItem(at: folder(for: attachment, taskID: taskID))
    }

    func removeAll(for taskID: UUID) {
        try? FileManager.default.removeItem(at: root.appendingPathComponent(taskID.uuidString))
    }

    private func folder(for attachment: TaskAttachment, taskID: UUID) -> URL {
        root.appendingPathComponent(taskID.uuidString, isDirectory: true)
            .appendingPathComponent(attachment.id.uuidString, isDirectory: true)
    }
}
