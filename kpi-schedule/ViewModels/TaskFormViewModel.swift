//
//  TaskFormViewModel.swift
//  kpi-schedule
//
//  Created by Maksym on 25.10.2026.
//

import Foundation

/// Швидкий вибір дедлайну
enum DeadlinePreset: CaseIterable {
    case noDeadline, today, tomorrow, nextWeek

    var title: String {
        switch self {
        case .noDeadline: return "Довгостроково"
        case .today:      return "Сьогодні"
        case .tomorrow:   return "Завтра"
        case .nextWeek:   return "За тиждень"
        }
    }

    /// Через скільки днів від сьогодні (nil = без дедлайну)
    var dayOffset: Int? {
        switch self {
        case .noDeadline: return nil
        case .today:      return 0
        case .tomorrow:   return 1
        case .nextWeek:   return 7
        }
    }
}

/// ViewModel екрану створення та редагування завдання
final class TaskFormViewModel: ObservableObject {
    /// Службове значення вибору: "Новий предмет…"
    static let customOption = "__custom__"

    @Published var title: String
    @Published var subjectSelection: String
    @Published var customSubject = ""
    @Published var hasDeadline: Bool
    @Published var deadline: Date
    @Published var link: String
    @Published var note: String
    @Published private(set) var attachments: [TaskAttachment]
    /// Помилка додавання файлу (показується алертом)
    @Published var attachmentError: String?

    let isEditing: Bool
    let availableSubjects: [String]

    /// Генерується одразу для можливості збереження файлів ще до збереження самого завдання.
    private let taskID: UUID
    private let originalAttachments: [TaskAttachment]
    private let wasDone: Bool
    private let repository: TaskRepository
    private let storage: AttachmentStoring
    private let now: () -> Date
    private weak var navigator: TaskNavigating?
    private var isSaved = false

    init(task: StudyTask?,
         repository: TaskRepository,
         subjects: SubjectsProviding,
         navigator: TaskNavigating?,
         now: @escaping () -> Date = Date.init,
         attachments: AttachmentStoring = FileAttachmentStorage()) {
        // Предмети: з розкладу та з наявних завдань
        var known = Set(subjects.subjects())
        known.formUnion(repository.allTasks().map(\.subject))
        if let task = task { known.insert(task.subject) }
        let list = known.filter { !$0.isEmpty }.sorted()

        self.availableSubjects = list
        self.taskID = task?.id ?? UUID()
        self.originalAttachments = task?.attachments ?? []
        self.attachments = task?.attachments ?? []
        self.storage = attachments
        self.now = now
        self.wasDone = task?.isDone ?? false
        self.isEditing = task != nil
        self.title = task?.title ?? ""
        self.subjectSelection = task?.subject ?? list.first ?? TaskFormViewModel.customOption
        self.hasDeadline = (task == nil) ? true : (task?.deadline != nil)
        self.deadline = task?.deadline ?? now().addingTimeInterval(7 * 24 * 60 * 60)
        self.link = task?.link ?? ""
        self.note = task?.note ?? ""
        self.repository = repository
        self.navigator = navigator
    }

    /// Який швидкий варіант зараз вибрано (nil = власна дата)
    var selectedPreset: DeadlinePreset? {
        guard hasDeadline else { return .noDeadline }
        return DeadlinePreset.allCases.first { preset in
            guard let offset = preset.dayOffset,
                  let day = Calendar.current.date(byAdding: .day, value: offset, to: now()) else { return false }
            return Calendar.current.isDate(deadline, inSameDayAs: day)
        }
    }

    /// Ставить дедлайн на кінець дня (23:59)
    func select(_ preset: DeadlinePreset) {
        guard let offset = preset.dayOffset else { hasDeadline = false; return }
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: offset, to: now()) ?? now()
        deadline = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: day) ?? day
        hasDeadline = true
    }

    var isCustomSubject: Bool { subjectSelection == TaskFormViewModel.customOption }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedNote: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }

    var resolvedSubject: String {
        let raw = isCustomSubject ? customSubject : subjectSelection
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedLink: String? {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Повідомлення про помилку валідації (nil, якщо дані коректні).
    var validationMessage: String? {
        if trimmedTitle.isEmpty { return "Введіть назву, наприклад «ЛАБ5»" }
        if resolvedSubject.isEmpty { return "Оберіть предмет або введіть новий" }
        if let link = normalizedLink, !TaskFormViewModel.isValidURL(link) {
            return "Некоректний URL матеріалів (потрібен http:// або https://)"
        }
        return nil
    }

    var canSave: Bool { validationMessage == nil }

    func save() {
        guard canSave else { return }
        let task = StudyTask(
            id: taskID,
            title: trimmedTitle,
            subject: resolvedSubject,
            deadline: hasDeadline ? deadline : nil,
            link: normalizedLink,
            note: trimmedNote,
            attachments: attachments,
            isDone: wasDone
        )
        repository.save(task)
        isSaved = true

        // Файли видаляються зі сховища лише при збереженні, щоб працювало "Скасувати".
        originalAttachments.filter { !attachments.contains($0) }.forEach { storage.remove($0, taskID: taskID) }
        navigator?.dismissSheet()
    }

    func cancel() {
        navigator?.dismissSheet()
    }

    // MARK: файли

    /// Обробка результату fileImporter
    func addAttachments(from result: Result<[URL], Error>) {
        switch result {
        case .failure:
            attachmentError = "Не вдалося вибрати файл"
        case .success(let urls):
            for url in urls {
                do {
                    attachments.append(try storage.importFile(from: url, taskID: taskID))
                } catch {
                    attachmentError = "Не вдалося додати файл «\(url.lastPathComponent)»"
                }
            }
        }
    }

    func removeAttachment(_ attachment: TaskAttachment) {
        attachments.removeAll { $0.id == attachment.id }
        // Нові файли видаляємо одразу, старі — після натискання "Зберегти"
        if !originalAttachments.contains(attachment) { storage.remove(attachment, taskID: taskID) }
    }

    /// Очищення тимчасових файлів, якщо форму закрито без збереження
    deinit {
        guard !isSaved else { return }
        attachments.filter { !originalAttachments.contains($0) }.forEach { storage.remove($0, taskID: taskID) }
    }

    private static func isValidURL(_ text: String) -> Bool {
        guard let url = URL(string: text),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else { return false }
        return true
    }
}
