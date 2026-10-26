//
//  TaskListViewModel.swift
//  kpi-schedule
//
//  Created by Maksym on 25.10.2026.
//

import Foundation
import Combine

/// Рядок списку (презентаційна модель)
struct TaskRowModel: Identifiable, Equatable {
    let id: UUID
    let title: String
    let subject: String
    let note: String
    let isDone: Bool
    let deadlineText: String
    let urgency: DeadlineUrgency
    let isDueToday: Bool
    let hasLink: Bool
    let hasAttachments: Bool

    init(task: StudyTask, now: Date) {
        let info = DeadlineInfo(deadline: task.deadline, isDone: task.isDone, now: now)
        id = task.id
        title = task.title
        subject = task.subject
        note = task.note
        isDone = task.isDone
        deadlineText = info.text
        urgency = info.urgency
        isDueToday = info.isToday
        hasLink = task.link != nil
        hasAttachments = !task.attachments.isEmpty
    }
}

/// Секція предмета з прогресом
struct SubjectSectionModel: Identifiable, Equatable {
    let subject: String
    let progress: TaskProgress
    let rows: [TaskRowModel]
    var id: String { subject }
}

final class TaskListViewModel: ObservableObject {
    @Published private(set) var sections: [SubjectSectionModel] = []
    /// Загальний прогрес усіх завдань, не залежить від фільтрів.
    @Published private(set) var overall = TaskProgress(done: 0, total: 0)
    @Published private(set) var subjects: [String] = []

    @Published var selectedSubject: String? = nil {
        didSet { rebuild() }
    }
    @Published var onlyUnfinished = false {
        didSet { rebuild() }
    }
    /// Пошук за назвою, предметом і нотаткою.
    @Published var searchText = "" {
        didSet { rebuild() }
    }

    private let repository: TaskRepository
    private weak var navigator: TaskNavigating?
    private let now: () -> Date
    private var allTasks: [StudyTask] = []
    private var cancellable: AnyCancellable?

    init(repository: TaskRepository, navigator: TaskNavigating?, now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.navigator = navigator
        self.now = now
        // Підписка на сховище: список сам оновлюється після будь-якої зміни.
        cancellable = repository.tasksPublisher.sink { [weak self] tasks in
            self?.allTasks = tasks
            self?.rebuild()
        }
    }

    // MARK: наміри користувача

    func select(_ id: UUID) { navigator?.showDetail(id: id) }

    /// Повторний тап по вибраному предмету знімає фільтр
    func toggleSubject(_ subject: String) {
        selectedSubject = (selectedSubject == subject) ? nil : subject
    }

    func addTapped() { navigator?.showCreate() }
    func edit(_ id: UUID) { navigator?.showEdit(id: id) }

    func toggleDone(_ id: UUID) {
        guard var task = allTasks.first(where: { $0.id == id }) else { return }
        task.isDone.toggle()
        repository.save(task)
    }

    func delete(_ id: UUID) {
        repository.delete(id: id)
    }

    // MARK: побудова стану

    private func rebuild() {
        overall = TaskProgress(tasks: allTasks)
        subjects = Array(Set(allTasks.map(\.subject))).sorted()

        // якщо вибраного предмета вже немає, скидаємо фільтр
        if let selected = selectedSubject, !subjects.contains(selected) {
            selectedSubject = nil
            return
        }

        let current = now()
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let visible = allTasks.filter { task in
            (selectedSubject == nil || task.subject == selectedSubject)
                && (!onlyUnfinished || !task.isDone)
                && (query.isEmpty || TaskListViewModel.matches(task, query))
        }
        let grouped = Dictionary(grouping: visible, by: \.subject)

        sections = grouped.keys.sorted().map { subject in
            // прогрес рахуємо за всіма завданнями предмета
            let all = allTasks.filter { $0.subject == subject }
            let rows = (grouped[subject] ?? [])
                .sorted(by: TaskListViewModel.order)
                .map { TaskRowModel(task: $0, now: current) }
            return SubjectSectionModel(subject: subject, progress: TaskProgress(tasks: all), rows: rows)
        }
    }

    private static func matches(_ task: StudyTask, _ query: String) -> Bool {
        [task.title, task.subject, task.note].contains { $0.localizedCaseInsensitiveContains(query) }
    }

    /// Сортування: невиконані -> найближчий дедлайн -> за назвою.
    private static func order(_ lhs: StudyTask, _ rhs: StudyTask) -> Bool {
        if lhs.isDone != rhs.isDone { return !lhs.isDone }
        switch (lhs.deadline, rhs.deadline) {
        case let (l?, r?) where l != r: return l < r
        case (_?, nil):                 return true
        case (nil, _?):                 return false
        default:                        return lhs.title < rhs.title
        }
    }
}
