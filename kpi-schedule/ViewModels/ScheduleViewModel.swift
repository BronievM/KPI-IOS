//
//  ScheduleViewModel.swift
//  kpi-schedule
//
//  Originally created by Maksym on 20.10.2026.
//  Updated by Maksym on 25.10.2026.
//

import Foundation

struct DaySection: Identifiable {
    let id: String
    let title: String
    let lessons: [Lesson]
    let isToday: Bool
}

final class ScheduleViewModel: ObservableObject {
    @Published private(set) var sections: [DaySection] = []
    @Published private(set) var groups: [String] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var currentWeek: WeekType = .first
    @Published private(set) var currentLessonID: UUID?

    @Published var selectedGroup: String = "" {
        didSet {
            guard oldValue != selectedGroup else { return }
            loadSchedule()
        }
    }
    @Published var selectedWeek: WeekType = .first {
        didSet { rebuildSections() }
    }
    @Published var filterOption: FilterOption = .all {
        didSet { rebuildSections() }
    }
    
    @Published var subjectFilter: String? = nil {
        didSet { rebuildSections() }
    }

    private let repository: ScheduleRepository
    private let linkOpener: LinkOpening
    private let clock: ScheduleClock
    private var days: [DailySchedule] = []

    init(repository: ScheduleRepository, linkOpener: LinkOpening, clock: ScheduleClock) {
        self.repository = repository
        self.linkOpener = linkOpener
        self.clock = clock
        let week = clock.snapshot().week
        self.currentWeek = week
        self.selectedWeek = week
    }

    func load() {
        do {
            groups = try repository.fetchGroups()
            errorMessage = nil
        } catch {
            groups = []
            days = []
            errorMessage = "Помилка: \(error.localizedDescription)"
            rebuildSections()
            return
        }

        if groups.contains(selectedGroup) {
            loadSchedule()
        } else if let first = groups.first {
            selectedGroup = first
        } else {
            days = []
            rebuildSections()
        }
    }


    /// Усі пари групи без фільтрів (для «Головної»)
    var allDays: [DailySchedule] { days }

    func refreshNow() {
        rebuildSections()
    }

    func open(_ lesson: Lesson) {
        guard let link = lesson.link, let url = URL(string: link) else { return }
        linkOpener.open(url)
    }

    private func loadSchedule() {
        do {
            days = try repository.fetchWeeklySchedule(for: selectedGroup)
            errorMessage = nil
        } catch {
            days = []
            errorMessage = "Помилка: \(error.localizedDescription)"
        }
        rebuildSections()
    }

    private func rebuildSections() {
        let now = clock.snapshot()
        let typeStrategy = filterOption.strategy
        let isCurrentWeekSelected = (selectedWeek == now.week)
        var currentID: UUID?

        let result: [DaySection] = days
            .filter { $0.weekType == selectedWeek }
            .compactMap { day -> DaySection? in
                let isToday = isCurrentWeekSelected && day.weekday != nil && day.weekday == now.weekday

                if isToday {
                    currentID = day.lessons.first { $0.startTime?.contains(minutes: now.minutes) == true }?.id
                }

                var filtered = typeStrategy.apply(to: day.lessons)

                if let subject = subjectFilter {
                    let subjectStrategy = SubjectFilter(subjectName: subject)
                    filtered = subjectStrategy.apply(to: filtered)
                }

                guard !filtered.isEmpty else { return nil }
                return DaySection(id: day.dayOfWeek, title: day.dayOfWeek, lessons: filtered, isToday: isToday)
            }

        currentWeek = now.week
        currentLessonID = currentID
        sections = result
    }
    
    func filterBySubject(_ subject: String) {
        self.subjectFilter = subject
    }

    func clearSubjectFilter() {
        self.subjectFilter = nil
    }
}
