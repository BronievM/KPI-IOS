//
//  kpi_scheduleTests.swift
//  kpi-scheduleTests
//
//  Created by Maksym on 21.09.2026.
//

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


    func testTodayAndCurrentLessonAreMarked() {
        let vm = makeSUT()
        let wednesday = vm.sections.first { $0.title == "Wednesday" }
        XCTAssertEqual(wednesday?.isToday, true)
        XCTAssertEqual(vm.sections.first { $0.title == "Monday" }?.isToday, false)
        XCTAssertEqual(vm.currentLessonID, wednesday?.lessons.first?.id)   // пара B (08:30)
    }

    func testNoCurrentLessonBetweenPairs() {
        let vm = makeSUT(clock: FixedClock(minutes: 10 * 60 + 15))
        XCTAssertNil(vm.currentLessonID)
        XCTAssertEqual(vm.sections.first { $0.title == "Wednesday" }?.isToday, true)
    }

    func testNothingIsMarkedWhenViewingAnotherWeek() {
        let vm = makeSUT()
        vm.selectedWeek = .second
        XCTAssertTrue(vm.sections.allSatisfy { !$0.isToday })
        XCTAssertNil(vm.currentLessonID)
    }


    func testLabFilterHidesDaysWithoutLabs() {
        let vm = makeSUT()
        vm.filterOption = .labs
        XCTAssertEqual(vm.sections.map(\.title), ["Wednesday"])
        XCTAssertEqual(vm.sections.first?.lessons.count, 2)
    }

    func testOnlineFilter() {
        let vm = makeSUT()
        vm.filterOption = .online
        XCTAssertEqual(vm.sections.flatMap(\.lessons).count, 2)
    }

    func testOpenCallsOpenerOnlyWhenLinkExists() {
        let spy = SpyLinkOpener()
        let vm = makeSUT(opener: spy)
        let lessons = vm.sections.flatMap(\.lessons)

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

    private func firstWeekDays() throws -> [DailySchedule] {
        let repo = JSONScheduleRepository(json: SampleScheduleData.json)
        return try repo.fetchWeeklySchedule(for: "ІО-42").filter { $0.weekType == .first }
    }

    func testJSONRepositoryReturnsGroups() throws {
        let repo = JSONScheduleRepository(json: SampleScheduleData.json)
        XCTAssertEqual(try repo.fetchGroups(), ["ІО-42"])
    }

    func testAdapterKeepsRealTypesFromJSON() throws {
        let tuesday = try firstWeekDays().first { $0.dayOfWeek == "Tuesday" }
        XCTAssertEqual(tuesday?.lessons.map(\.type), [.lab, .lab])
        let all = try JSONScheduleRepository(json: SampleScheduleData.json).fetchWeeklySchedule(for: "ІО-42")
        XCTAssertTrue(all.flatMap(\.lessons).contains { $0.type == .practice })
    }

    func testAdapterSortsDaysAndLessons() throws {
        let days = try firstWeekDays()
        XCTAssertEqual(days.map(\.dayOfWeek), ["Monday", "Tuesday", "Wednesday", "Thursday"])
        XCTAssertEqual(days[0].lessons.map(\.subjectName).first, "Computer Graphics and Multimedia")   // 08:30
        XCTAssertEqual(days[0].lessons.compactMap { $0.startTime?.startText }, ["08:30", "10:25", "12:20"])
    }

    func testAdapterSeparatesWeeks() throws {
        let all = try JSONScheduleRepository(json: SampleScheduleData.json).fetchWeeklySchedule(for: "ІО-42")
        XCTAssertEqual(all.filter { $0.weekType == .first }.count, 4)
        XCTAssertEqual(all.filter { $0.weekType == .second }.count, 5)
    }

    func testAdapterMapsLinkAndRoom() throws {
        let days = try firstWeekDays()
        let wednesday = days.first { $0.dayOfWeek == "Wednesday" }
        XCTAssertEqual(wednesday?.lessons.first?.link, "https://github.com/BronievM/KPI-IOS")
        XCTAssertEqual(wednesday?.lessons.last?.room, "18-200")
    }

    func testAdapterSkipsUnknownType() {
        let dto = LessonDTO(group: "G", day: "Monday", week: nil, subject: "X", teacher: "T",
                            type: "Seminar", time: nil, room: nil, online: nil, link: nil)
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
        XCTAssertEqual(snapshot(2026, 9, 20, 9, 0).week, .first)
        XCTAssertEqual(snapshot(2026, 10, 19, 9, 0).week, .second)
        XCTAssertEqual(snapshot(2026, 10, 26, 9, 0).week, .first)
        XCTAssertEqual(snapshot(2026, 9, 10, 9, 0).week, .second)  
    }

    func testWeekdayAndMinutes() {
        let s = snapshot(2026, 10, 20, 10, 30)
        XCTAssertEqual(s.week, .second)
        XCTAssertEqual(s.weekday, .tuesday)
        XCTAssertEqual(s.minutes, 10 * 60 + 30)
    }
}
