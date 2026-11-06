//
//  ScheduleViewModel.swift
//  kpi-schedule
//
//  Originally created by Maksym on 20.10.2026.
//  Updated by Maksym on 06.11.2026.
//

import Foundation

struct DaySection: Identifiable {
    let id: String
    let title: String
    let lessons: [Lesson]
    let isToday: Bool
    /// Дата цього дня для вибраного тижня. потрібна для «спец. пар»
    var dateKey: String? = nil
}

final class ScheduleViewModel: ObservableObject {
    @Published private(set) var sections: [DaySection] = []
    @Published private(set) var groups: [String] = []
    /// Помилка читання даних (локально)
    @Published private(set) var errorMessage: String?
    /// Помилка оновлення з мережі (зрозуміле повідомлення для користувача)
    @Published private(set) var refreshError: String?
    /// Іде запит до сервера
    @Published private(set) var isLoading = false
    /// Пара, до якої треба прокрутити розклад (після переходу з «Головної»)
    @Published var focusedLessonID: UUID?
    @Published var highlightedLessonID: UUID?
    @Published private(set) var currentWeek: WeekType = .first
    @Published private(set) var currentLessonID: UUID?
    /// Предмети, які студент відвідує. nil = вибір ще не робився (показуємо все)
    @Published private(set) var selectedSubjects: Set<String>?

    private static let groupKey = "selectedGroup"

    @Published var selectedGroup: String = "" {
        didSet {
            guard oldValue != selectedGroup, !selectedGroup.isEmpty else { return }
            UserDefaults.standard.set(selectedGroup, forKey: Self.groupKey)
            selectedSubjects = electives.selection(for: selectedGroup)
            loadSchedule()
            Task { await refreshCurrent() }
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
    private let electives: ElectiveStoring
    private let linkOpener: LinkOpening
    private let clock: ScheduleClock
    private let links: LessonLinkStoring
    private var inFlight = 0 { didSet { isLoading = inFlight > 0 } }
    private var days: [DailySchedule] = []
    private var didStartNetworkLoad = false

    init(repository: ScheduleRepository,
         linkOpener: LinkOpening,
         clock: ScheduleClock,
         electives: ElectiveStoring = LocalElectiveStore(),
         links: LessonLinkStoring = LocalLessonLinkStore()) {
        self.links = links
        self.repository = repository
        self.linkOpener = linkOpener
        self.clock = clock
        self.electives = electives
        let week = clock.snapshot().week
        self.currentWeek = week
        self.selectedWeek = week
        // у init didSet не спрацьовує: просто відновлюємо збережену групу
        let saved = UserDefaults.standard.string(forKey: Self.groupKey) ?? ""
        self.selectedGroup = saved
        self.selectedSubjects = saved.isEmpty ? nil : electives.selection(for: saved)
    }

    // MARK: завантаження

    func load() {
        updateGroupList()
        if selectedGroup.isEmpty, let first = groups.first {
            didStartNetworkLoad = true     // вибір групи сам запустить оновлення, повний reload був би дублем
            selectedGroup = first          // лише коли групу ще ніколи не обирали
        } else {
            loadSchedule()
        }

        guard !didStartNetworkLoad else { return }
        didStartNetworkLoad = true
        Task { await reload() }
    }

    /// Оновлення з мережі (перший запуск, pull-to-refresh, кнопка «Повторити»)
    @MainActor
    func reload() async {
        inFlight += 1
        defer { inFlight -= 1 }
        do {
            try await repository.refreshGroups()
        } catch is CancellationError {
            return
        } catch {
            print("Групи: працюємо з кешем (\(error))")
        }
        updateGroupList(strict: true)

        // збережену групу замінюємо, лише якщо її справді прибрали зі списку
        if !selectedGroup.isEmpty, !groups.contains(selectedGroup), let first = groups.first {
            selectedGroup = first          
            return
        }
        await refreshCurrent()
    }

    @MainActor
    private func refreshCurrent() async {
        let group = selectedGroup
        guard !group.isEmpty else { return }
        inFlight += 1
        defer { inFlight -= 1 }
        refreshError = nil
        do {
            try await repository.refreshSchedule(for: group)
        } catch is CancellationError {
            return
        } catch {
            guard group == selectedGroup else { return }  
            refreshError = error.localizedDescription
        }
        guard group == selectedGroup else { return }
        loadSchedule()
    }

    var hasSchedule: Bool { !days.isEmpty }
    var displayedError: String? { errorMessage ?? refreshError }
    var allSubjectsHidden: Bool { selectedSubjects?.isEmpty == true }

    private func updateGroupList(strict: Bool = false) {
        var list = (try? repository.fetchGroups()) ?? []
        if !strict, !selectedGroup.isEmpty, !list.contains(selectedGroup) {
            list.insert(selectedGroup, at: 0)
        }
        groups = list
    }

    // MARK: предмети

    /// Усі предмети поточної групи для екрана профілю
    var subjectOptions: [ElectiveOption] {
        let lessons: [Lesson] = days.flatMap { $0.lessons }
        let grouped: [String: [Lesson]] = Dictionary(grouping: lessons) { $0.subjectName }
        return grouped.map { name, list in
            ElectiveOption(
                name: name,
                teachers: Array(Set(list.map { $0.teacher }.filter { !$0.isEmpty })).sorted(),
                likelyElective: list.contains { $0.isElective })
        }
        .sorted { $0.name < $1.name }
    }

    func isSubjectEnabled(_ name: String) -> Bool {
        selectedSubjects?.contains(name) ?? true
    }

    func setSubject(_ name: String, enabled: Bool) {
        var set = selectedSubjects ?? Set(subjectOptions.map { $0.name })
        if enabled { set.insert(name) } else { set.remove(name) }
        selectedSubjects = set
        electives.save(set, for: selectedGroup)
        rebuildSections()
        objectWillChange.send()
    }

    func enableAllSubjects() {
        let all = Set(subjectOptions.map { $0.name })
        selectedSubjects = all
        electives.save(all, for: selectedGroup)
        rebuildSections()
        objectWillChange.send()
    }

    private func isVisible(_ lesson: Lesson) -> Bool {
        isSubjectEnabled(lesson.subjectName)
    }

    /// Найближча дата заняття предмета (для предметів, що ходять у конкретні дати)
    func nextDate(for subject: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = SystemScheduleClock.kyivCalendar
        formatter.timeZone = SystemScheduleClock.kyivCalendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let today = SystemScheduleClock.kyivCalendar.startOfDay(for: Date())
        let lessons: [Lesson] = days.flatMap { $0.lessons }
        let dates: [String] = lessons.filter { $0.subjectName == subject }.flatMap { $0.dates }
        return dates
            .compactMap { formatter.date(from: $0) }
            .filter { $0 >= today }
            .min()
    }

    // MARK: для екранів

    /// Пари групи з урахуванням вибору предметів, без фільтрів (для «Головної»)
    var allDays: [DailySchedule] {
        days.map { day in
            var copy = day
            copy.lessons = day.lessons.filter(isVisible)
            return copy
        }
    }

    func refreshNow() {
        rebuildSections()
    }

    func open(_ lesson: Lesson) {
        guard let link = lesson.link, let url = URL(string: link) else { return }
        linkOpener.open(url)
    }

    func filterBySubject(_ subject: String) {
        subjectFilter = subject
    }

    func clearSubjectFilter() {
        subjectFilter = nil
    }
    
    @Published private(set) var directory: [CampusGroup] = []
    @Published private(set) var directoryError: String?
    @Published private(set) var isDirectoryLoading = false

    var selectedGroupInfo: CampusGroup? {
        directory.first { $0.name == selectedGroup }
    }

    /// Список груп з факультетами. З кешу; з мережі, якщо в кеші лише група за замовчуванням або виконано pull-to-refresh
    @MainActor
    func loadGroupDirectory(forceRefresh: Bool = false) async {
        readDirectory()
        guard forceRefresh || directory.count <= 1 else { return }
        isDirectoryLoading = true
        defer { isDirectoryLoading = false }
        do {
            try await repository.refreshGroups()
            directoryError = nil
            readDirectory()
            updateGroupList()
        } catch is CancellationError {
            return
        } catch {
            directoryError = error.localizedDescription
        }
    }

    private func readDirectory() {
        let list = (try? repository.fetchGroupDirectory()) ?? []
        directory = (list.isEmpty ? [.default] : list).sorted { $0.name < $1.name }
    }

    @MainActor
    func chooseGroup(_ group: CampusGroup) async {
        selectedGroup = group.name
    }

    // MARK: лінки на пари (локально, на пристрої)

    /// Повертає текст помилки або nil, якщо збережено. Порожній текст видаляє лінк.
    func setLink(_ text: String, for lesson: Lesson) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            removeLink(for: lesson)
            return nil
        }
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              url.host?.isEmpty == false else {
            return "Введіть коректне посилання, що починається з https://"
        }
        links.save(trimmed, subject: lesson.subjectName, type: lesson.type)
        loadSchedule()
        return nil
    }

    func removeLink(for lesson: Lesson) {
        links.save(nil, subject: lesson.subjectName, type: lesson.type)
        loadSchedule()
    }

    /// Накладає збережені користувачем лінки на пари
    private func applyLinks() {
        days = days.map { day in
            var copy = DailySchedule(dayOfWeek: day.dayOfWeek, weekType: day.weekType)
            copy.lessons = day.lessons.map { lesson in
                guard let saved = links.link(subject: lesson.subjectName, type: lesson.type) else { return lesson }
                var updated = lesson
                updated.link = saved
                return updated
            }
            return copy
        }
    }

    /// Показати пару в розкладі: потрібний тиждень, без фільтрів, з прокруткою
    func focus(on lesson: Lesson) {
        filterOption = .all
        subjectFilter = nil
        // id пар перегенеровуються при кожному load(), тому шукаємо за змістом
        let key = Self.focusKey(lesson)
        focusKey = key
        if let day = days.first(where: { $0.lessons.contains { Self.focusKey($0) == key } }) {
            selectedWeek = day.weekType
        }
        rebuildSections()
    }

    private var focusKey: String?

    private static func focusKey(_ l: Lesson) -> String {
        "\(l.subjectName)|\(l.type)|\(String(describing: l.startTime))|\(l.teacher)"
    }
    
    func endFocus() {
        guard let id = focusedLessonID else {return}
        highlightedLessonID = focusedLessonID
        focusKey = nil
        focusedLessonID = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.highlightedLessonID = nil
        }
    }

    // MARK: внутрішнє

    private func loadSchedule() {
        do {
            days = try repository.fetchWeeklySchedule(for: selectedGroup)
            applyLinks()
            errorMessage = nil
        } catch {
            days = []
            errorMessage = "Помилка: \(error.localizedDescription)"
        }
        rebuildSections()
        objectWillChange.send()
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

                // дата цього дня у вибраному тижні
                let dayKey: String? = {
                    guard let weekday = day.weekday, let nowWeekday = now.weekday else { return nil }
                    return now.dateKey(addingDays: weekday.rawValue - nowWeekday.rawValue + (isCurrentWeekSelected ? 0 : 7))
                }()

                // «спец. пари» лишаємо лише в їхні дати
                var filtered = typeStrategy.apply(to: day.lessons).filter(isVisible).filter { $0.occurs(on: dayKey) }

                if let subject = subjectFilter {
                    filtered = SubjectFilter(subjectName: subject).apply(to: filtered)
                }

                if isToday {
                    currentID = filtered.first { $0.startTime?.contains(minutes: now.minutes) == true }?.id
                }

                guard !filtered.isEmpty else { return nil }
                return DaySection(id: day.dayOfWeek, title: day.dayOfWeek, lessons: filtered, isToday: isToday, dateKey: dayKey)
            }

        currentWeek = now.week
        currentLessonID = currentID
        sections = result
        if let key = focusKey {
            focusedLessonID = result.flatMap(\.lessons).first { Self.focusKey($0) == key }?.id
        }
    }
}
