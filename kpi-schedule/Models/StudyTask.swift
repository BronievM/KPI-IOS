//
//  StudyTask.swift
//  kpi-schedule
//
//  Created by Maksym on 25.10.2026.
//

import Foundation

/// Файл, прикріплений до завдання. Сам файл лежить у `AttachmentStoring`,
/// у моделі зберігається лише ідентифікатор і назва (шлях враховується).
struct TaskAttachment: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    /// Назва файлу з розширенням.
    var fileName: String
}

/// Навчальне завдання з предмета (наприклад, «ЛАБ5» з «Computer Networks»).
/// (Назва не `Task`, щоб не конфліктувати з Swift Concurrency)
struct StudyTask: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var subject: String
    /// nil = «довгостроково»
    var deadline: Date?
    /// «Матеріали (URL)» (посилання на завдання, Classroom, репозиторій тощо).
    var link: String?
    var note: String = ""
    /// Прикріплені файли (методичка, скриншот, умова).
    var attachments: [TaskAttachment] = []
    /// Поки один локальний користувач. У ЛР4 => окреме виконання для кожного студента.
    var isDone: Bool = false

    func isOverdue(at date: Date) -> Bool {
        guard let deadline = deadline, !isDone else { return false }
        return deadline < date
    }

    enum CodingKeys: String, CodingKey {
        case id, title, subject, deadline, link, note, attachments, isDone
    }
}

extension StudyTask {
    /// Власний декодер
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decode(String.self, forKey: .title)
        subject = try c.decode(String.self, forKey: .subject)
        deadline = try c.decodeIfPresent(Date.self, forKey: .deadline)
        link = try c.decodeIfPresent(String.self, forKey: .link)
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        attachments = try c.decodeIfPresent([TaskAttachment].self, forKey: .attachments) ?? []
        isDone = try c.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
    }
}
