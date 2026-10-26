import XCTest
@testable import kpi_schedule

private final class SpyLinkOpener: LinkOpening {
    private(set) var opened: [URL] = []
    func open(_ url: URL) { opened.append(url) }
}

private struct FailingRepository: ScheduleRepository {
    struct Boom: Error {}
    func fetchGroups() throws -> [String] { throw Boom() }
    func fetchWeeklySchedule(for group: String) throws -> [DailySchedule] { throw Boom() }
}

/// Годинник із фіксованим "зараз": середа, 08:40, 1-й тиждень.
private struct FixedClock: ScheduleClock {
    var week: WeekType = .first
    var weekday: Weekday? = .wednesday
    var minutes: Int = 8 * 60 + 40
    func snapshot() -> TimeSnapshot { TimeSnapshot(week: week, weekday: weekday, minutes: minutes) }
}

final class ScheduleViewModelTests: XCTestCase {

    private func makeDays() -> [DailySchedule] {
        let mon = DailySchedule(dayOfWeek: "Monday", weekType: .first)
        mon.addLesson(LessonBuilder().subject("A").teacher("T").type(.lecture).start(LessonTime("08:30")).online().build())

        let wed = DailySchedule(dayOfWeek: "Wednesday", weekType: .first)
        wed.addLesson(LessonBuilder().subject("B").teacher("T").type(.lab).start(LessonTime("08:30")).room("18-101").build())
        wed.addLesson(LessonBuilder().subject("C").teacher("T").type(.lab).start(LessonTime("10:25")).online(link: "https://example.com").build())

        let wed2 = DailySchedule(dayOfWeek: "Wednesday", weekType: .second)
        wed2.addLesson(LessonBuilder().subject("E").teacher("T").type(.practice).start(LessonTime("08:30")).room("1").build())
        return [mon, wed, wed2]
    }

    private func makeOtherGroupDays() -> [DailySchedule] {
        let tue = DailySchedule(dayOfWeek: "Tuesday", weekType: .first)
        tue.addLesson(LessonBuilder().subject("D").teacher("T").type(.practice).room("1").build())
        return [tue]
    }

    private func makeSUT(opener: LinkOpening = SpyLinkOpener(), clock: ScheduleClock = FixedClock()) -> ScheduleViewModel {
        let repo = MockScheduleRepository(schedules: [
            (group: "A-1", days: makeDays()),
            (group: "A-2", days: makeOtherGroupDays())
        ])
        let vm = ScheduleViewModel(repository: repo, linkOpener: opener, clock: clock)
        vm.load()
        return vm
    }

    // MARK: група

    func testLoadSelectsFirstGroupAndBuildsSections() {
        let vm = makeSUT()
        XCTAssertEqual(vm.groups, ["A-1", "A-2"])
        XCTAssertEqual(vm.selectedGroup, "A-1")
        XCTAssertEqual(vm.sections.map(\.title), ["Monday", "Wednesday"])
    }

    func testChangingGroupReloadsSchedule() {
        let vm = makeSUT()
        vm.selectedGroup = "A-2"
        XCTAssertEqual(vm.sections.map(\.title), ["Tuesday"])
    }

    // MARK: тиждень

    func testDefaultWeekFollowsClock() {
        let vm = makeSUT(clock: FixedClock(week: .second))
        XCTAssertEqual(vm.selectedWeek, .second)
        XCTAssertEqual(vm.currentWeek, .second)
        XCTAssertEqual(vm.sections.map(\.title), ["Wednesday"])
    }

    func testSwitchingWeekShowsOnlyThatWeek() {
        let vm = makeSUT()
        XCTAssertEqual(vm.sections.flatMap(\.lessons).count, 3)   // A, B, C
        vm.selectedWeek = .second
        XCTAssertEqual(vm.sections.flatMap(\.lessons).map(\.subjectName), ["E"])
    }

    // MARK: сьогодні / поточна пара

    func testTodayAndCurrentLessonAreMarked() {
        let vm = makeSUT()   // середа, 08:40, 1-й тиждень
        let wednesday = vm.sections.first { $0.title == "Wednesday" }
        XCTAssertEqual(wednesday?.isToday, true)
        XCTAssertEqual(vm.sections.first { $0.title == "Monday" }?.isToday, false)
        XCTAssertEqual(vm.currentLessonID, wednesday?.lessons.first?.id)   // пара B (08:30)
    }

    func testNoCurrentLessonBetweenPairs() {
        let vm = makeSUT(clock: FixedClock(minutes: 10 * 60 + 15))   // 10:15 — вже після B, ще до C
        XCTAssertNil(vm.currentLessonID)
        XCTAssertEqual(vm.sections.first { $0.title == "Wednesday" }?.isToday, true)
    }

    func testNothingIsMarkedWhenViewingAnotherWeek() {
        let vm = makeSUT()
        vm.selectedWeek = .second
        XCTAssertTrue(vm.sections.allSatisfy { !$0.isToday })
        XCTAssertNil(vm.currentLessonID)
    }

    // MARK: фільтри, посилання, помилки

    func testLabFilterHidesDaysWithoutLabs() {
        let vm = makeSUT()
        vm.filterOption = .labs
        XCTAssertEqual(vm.sections.map(\.title), ["Wednesday"])
        XCTAssertEqual(vm.sections.first?.lessons.count, 2)
    }

    func testOnlineFilter() {
        let vm = makeSUT()
        vm.filterOption = .online
        XCTAssertEqual(vm.sections.flatMap(\.lessons).count, 2)   // A і C
    }

    func testOpenCallsOpenerOnlyWhenLinkExists() {
        let spy = SpyLinkOpener()
        let vm = makeSUT(opener: spy)
        let lessons = vm.sections.flatMap(\.lessons)   // A, B, C

        vm.open(lessons[0])
        XCTAssertTrue(spy.opened.isEmpty)

        vm.open(lessons[2])
        XCTAssertEqual(spy.opened, [URL(string: "https://example.com")!])
    }

    func testRepositoryFailureSetsErrorMessage() {
        let vm = ScheduleViewModel(repository: FailingRepository(), linkOpener: SpyLinkOpener(), clock: FixedClock())
        vm.load()
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(vm.sections.isEmpty)
    }
}

final class LessonDTOAdapterTests: XCTestCase {

    /// Власні дані тесту: рядки навмисно перемішані (порядок днів і часу), щоб перевірити сортування.
    /// Тест не залежить від демо-розкладу `SampleScheduleData`, який можна змінювати.
    private static let json = """
    [
      {"group":"G","day":"Thursday","week":"first","time":"08:30","subject":"Th","teacher":"T","type":"Lecture","online":true},
      {"group":"G","day":"Tuesday","week":"first","time":"12:20","subject":"Lab2","teacher":"T","type":"Laboratory","room":"1-1"},
      {"group":"G","day":"Monday","week":"first","time":"12:20","subject":"Mon3","teacher":"T","type":"Lecture","online":true},
      {"group":"G","day":"Monday","week":"first","time":"08:30","subject":"Computer Graphics and Multimedia","teacher":"T","type":"Lecture","online":true},
      {"group":"G","day":"Monday","week":"first","time":"10:25","subject":"Mon2","teacher":"T","type":"Lecture","online":true},
      {"group":"G","day":"Wednesday","week":"first","time":"10:25","subject":"Wed2","teacher":"T","type":"Laboratory","room":"18-200"},
      {"group":"G","day":"Wednesday","week":"first","time":"08:30","subject":"Wed1","teacher":"T","type":"Laboratory","online":true,"link":"https://github.com/BronievM/KPI-IOS"},
      {"group":"G","day":"Tuesday","week":"first","time":"10:25","subject":"Lab1","teacher":"T","type":"Laboratory","room":"1-2"},
      {"group":"G","day":"Monday","week":"second","time":"08:30","subject":"S1","teacher":"T","type":"Practical","room":"2-1"},
      {"group":"G","day":"Tuesday","week":"second","time":"08:30","subject":"S2","teacher":"T","type":"Lecture","online":true},
      {"group":"G","day":"Wednesday","week":"second","time":"08:30","subject":"S3","teacher":"T","type":"Lecture","online":true},
      {"group":"G","day":"Thursday","week":"second","time":"08:30","subject":"S4","teacher":"T","type":"Lecture","online":true},
      {"group":"G","day":"Saturday","week":"second","time":"14:15","subject":"S5","teacher":"T","type":"Lecture","online":true}
    ]
    """

    private func allDays() throws -> [DailySchedule] {
        try JSONScheduleRepository(json: Self.json).fetchWeeklySchedule(for: "G")
    }

    private func firstWeekDays() throws -> [DailySchedule] {
        try allDays().filter { $0.weekType == .first }
    }

    func testJSONRepositoryReturnsGroups() throws {
        XCTAssertEqual(try JSONScheduleRepository(json: Self.json).fetchGroups(), ["G"])
        // демо-дані застосунку теж читаються
        XCTAssertFalse(try JSONScheduleRepository(json: SampleScheduleData.json).fetchGroups().isEmpty)
    }

    func testAdapterKeepsRealTypesFromJSON() throws {
        let tuesday = try firstWeekDays().first { $0.dayOfWeek == "Tuesday" }
        XCTAssertEqual(tuesday?.lessons.map(\.type), [.lab, .lab])
        XCTAssertTrue(try allDays().flatMap(\.lessons).contains { $0.type == .practice })
    }

    func testAdapterSortsDaysAndLessons() throws {
        let days = try firstWeekDays()
        XCTAssertEqual(days.map(\.dayOfWeek), ["Monday", "Tuesday", "Wednesday", "Thursday"])
        XCTAssertEqual(days[0].lessons.map(\.subjectName).first, "Computer Graphics and Multimedia")   // 08:30
        XCTAssertEqual(days[0].lessons.compactMap { $0.startTime?.startText }, ["08:30", "10:25", "12:20"])
    }

    func testAdapterSeparatesWeeks() throws {
        let all = try allDays()
        XCTAssertEqual(all.filter { $0.weekType == .first }.count, 4)
        XCTAssertEqual(all.filter { $0.weekType == .second }.count, 5)
    }

    func testAdapterMapsLinkAndRoom() throws {
        let wednesday = try firstWeekDays().first { $0.dayOfWeek == "Wednesday" }
        XCTAssertEqual(wednesday?.lessons.first?.link, "https://github.com/BronievM/KPI-IOS")
        XCTAssertEqual(wednesday?.lessons.last?.room, "18-200")
    }

    func testAdapterSkipsUnknownType() {
        let dto = LessonDTO(group: "G", day: "Monday", week: nil, subject: "X", teacher: "T",
                            type: "Seminar", time: nil, room: nil, online: nil, link: nil, elective: nil)
        XCTAssertTrue(LessonDTOAdapter().adapt([dto]).isEmpty)
    }

    func testBuilderBuildsLesson() {
        let l = LessonBuilder().subject("S").teacher("T").type(.practice).room("1").start(LessonTime("14:15")).build()
        XCTAssertEqual(l.getLocation(), "1")
        XCTAssertFalse(l.isOnline)
        XCTAssertEqual(l.startTime?.rangeText, "14:15–15:50")
    }
}

final class LessonTimeTests: XCTestCase {
    func testParsingAndRange() {
        XCTAssertEqual(LessonTime("08:30")?.rangeText, "08:30–10:05")
        XCTAssertEqual(LessonTime("08:30:00"), LessonTime(hour: 8, minute: 30))
        XCTAssertNil(LessonTime("abc"))
    }

    func testContains() {
        let time = LessonTime(hour: 8, minute: 30)
        XCTAssertTrue(time.contains(minutes: 8 * 60 + 30))
        XCTAssertTrue(time.contains(minutes: 10 * 60 + 4))
        XCTAssertFalse(time.contains(minutes: 10 * 60 + 5))
        XCTAssertFalse(time.contains(minutes: 8 * 60 + 29))
    }
}

final class SystemScheduleClockTests: XCTestCase {
    private func snapshot(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> TimeSnapshot {
        let calendar = SystemScheduleClock.kyivCalendar
        let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
        return SystemScheduleClock(now: { date }).snapshot()
    }

    func testAnchorMondayIsFirstWeek() {
        let s = snapshot(2026, 9, 14, 9, 0)
        XCTAssertEqual(s.week, .first)
        XCTAssertEqual(s.weekday, .monday)
    }

    func testWeeksAlternate() {
        XCTAssertEqual(snapshot(2026, 9, 20, 9, 0).week, .first)    // неділя першого тижня
        XCTAssertEqual(snapshot(2026, 10, 19, 9, 0).week, .second)  // пн 19.10 — 2-й тиждень (за реальним розкладом)
        XCTAssertEqual(snapshot(2026, 10, 26, 9, 0).week, .first)
        XCTAssertEqual(snapshot(2026, 9, 10, 9, 0).week, .second)   // до початку відліку
    }

    func testWeekdayAndMinutes() {
        let s = snapshot(2026, 10, 20, 10, 30)
        XCTAssertEqual(s.week, .second)
        XCTAssertEqual(s.weekday, .tuesday)
        XCTAssertEqual(s.minutes, 10 * 60 + 30)
    }
}
