//
//  HomeViewModel.swift
//  kpi-schedule
//
//  Created by Maksym on 25.10.2026.
//

import Foundation
import Combine

/// Що показати в картці «пара»
enum LessonState {
    /// Пара йде зараз: `progress` від 0 до 1, `minutesLeft` до кінця
    case current(Lesson, progress: Double, minutesLeft: Int)
    /// Наступна пара; `when`: «через 1 год 20 хв», «завтра о 10:25»
    case upcoming(Lesson, when: String)
    case none
}

/// Найближчий дедлайн (невиконане завдання, включно з простроченими)
struct HotDeadline: Identifiable {
    let id: UUID
    let title: String
    let subject: String
    let text: String
    let urgency: DeadlineUrgency
    let isToday: Bool
}

/// ViewModel екрана «Головна»: поточна/наступна пара, найближчі дедлайни, загальний прогрес
final class HomeViewModel: ObservableObject {
    @Published private(set) var lessonState: LessonState = .none
    @Published private(set) var deadlines: [HotDeadline] = []
    @Published private(set) var progress = TaskProgress(done: 0, total: 0)

    private let schedule: ScheduleViewModel
    private let tasks: TaskRepository
    private let clock: ScheduleClock
    private let now: () -> Date
    private var cancellables: Set<AnyCancellable> = []

    init(schedule: ScheduleViewModel,
         tasks: TaskRepository,
         clock: ScheduleClock = SystemScheduleClock(),
         now: @escaping () -> Date = Date.init) {
        self.schedule = schedule
        self.tasks = tasks
        self.clock = clock
        self.now = now
        // оновлюємось, коли змінюються завдання або розклад
        tasks.tasksPublisher
            .sink { [weak self] tasks in self?.updateTasks(tasks) }
            .store(in: &cancellables)
        schedule.objectWillChange
            .sink { [weak self] _ in DispatchQueue.main.async { self?.updateLesson() } }
            .store(in: &cancellables)
    }

    /// Викликається при появі екрана і за таймером
    func refresh() {
        if schedule.groups.isEmpty { schedule.load() }   // «Головна» може відкритися раніше за «Розклад»
        updateLesson()
        updateTasks(tasks.allTasks())
    }

    func open(_ lesson: Lesson) { schedule.open(lesson) }

    private func updateLesson() {
        lessonState = HomeViewModel.lessonState(days: schedule.allDays, at: clock.snapshot())
    }

    private func updateTasks(_ all: [StudyTask]) {
        progress = TaskProgress(tasks: all)
        let current = now()
        deadlines = all
            .filter { !$0.isDone && $0.deadline != nil }
            .sorted { ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }
            .prefix(3)
            .map { task in
                let info = DeadlineInfo(deadline: task.deadline, isDone: task.isDone, now: current)
                return HotDeadline(id: task.id, title: task.title, subject: task.subject,
                                   text: info.text, urgency: info.urgency, isToday: info.isToday)
            }
    }

    // MARK: логіка (без UI, тому легко тестується)

    /// Поточна пара або найближча наступна (до двох тижнів уперед)
    static func lessonState(days: [DailySchedule], at now: TimeSnapshot) -> LessonState {
        guard let today = now.weekday else { return .none }

        func timed(_ week: WeekType, _ weekday: Weekday) -> [(lesson: Lesson, time: LessonTime)] {
            days.filter { $0.weekType == week && $0.weekday == weekday }
                .flatMap(\.lessons)
                .compactMap { lesson in lesson.startTime.map { (lesson: lesson, time: $0) } }
                .sorted { $0.time < $1.time }
        }

        if let running = timed(now.week, today).first(where: { $0.time.contains(minutes: now.minutes) }) {
            let total = LessonTime.pairDurationMinutes
            let elapsed = now.minutes - running.time.minutesFromMidnight
            return .current(running.lesson, progress: Double(elapsed) / Double(total), minutesLeft: total - elapsed)
        }

        for offset in 0...14 {     // включно з 14-м днем: той самий день тижня через два тижні
            let index = (today.rawValue - 1) + offset
            guard let weekday = Weekday(rawValue: index % 7 + 1) else { continue }
            // після неділі тиждень міняється
            let flipped = (index / 7) % 2 == 1
            let week: WeekType = flipped ? (now.week == .first ? .second : .first) : now.week
            let candidates = timed(week, weekday).filter { offset > 0 || $0.time.minutesFromMidnight > now.minutes }
            guard let next = candidates.first else { continue }

            let when: String
            switch offset {
            case 0:  when = "через " + HomeViewModel.durationText(next.time.minutesFromMidnight - now.minutes)
            case 1:  when = "завтра о \(next.time.startText)"
            default: when = "\(weekday.localizedName), \(next.time.startText)"
            }
            return .upcoming(next.lesson, when: when)
        }
        return .none
    }

    /// 80 -> «1 год 20 хв», 45 -> «45 хв»
    static func durationText(_ minutes: Int) -> String {
        let hours = minutes / 60, rest = minutes % 60
        if hours == 0 { return "\(rest) хв" }
        return rest == 0 ? "\(hours) год" : "\(hours) год \(rest) хв"
    }
}
