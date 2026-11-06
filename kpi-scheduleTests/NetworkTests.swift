//
//  NetworkTests.swift
//  kpi-scheduleTests
//
//  Created by Maksym on 07.11.2026.
//

import XCTest
@testable import kpi_schedule

// MARK: - Заглушка URLSession

private final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class APIClientTests: XCTestCase {
    private let validSchedule = """
    {"scheduleFirstWeek":[{"day":"Пн","pairs":[{"name":"A","time":"08:30","type":"лек",
      "lecturer":{"name":"T"},"location":{"title":"18-1","uri":null},"dates":[]}]}],
     "scheduleSecondWeek":[]}
    """

    private func makeClient() -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return APIClient(baseURL: URL(string: "https://example.test")!, session: URLSession(configuration: config))
    }

    private func respond(_ status: Int, _ body: String) {
        StubURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!,
             Data(body.utf8))
        }
    }

    override func tearDown() {
        StubURLProtocol.handler = nil
        StubURLProtocol.lastRequest = nil
    }

    func testSuccessfulScheduleIsDecodedAndRequestIsBuiltCorrectly() async throws {
        respond(200, validSchedule)
        let response = try await makeClient().fetchSchedule(groupId: 4382)

        XCTAssertEqual(response.scheduleFirstWeek?.first?.pairs?.first?.name, "A")
        let request = try XCTUnwrap(StubURLProtocol.lastRequest)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/schedule/lessons")
        XCTAssertEqual(request.url?.query, "groupId=4382")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
    }

    func testGroupsAcceptPlainArrayAndDataWrapper() async throws {
        let item = #"{"id":1,"name":"ІО-42","faculty":"ФІОТ"}"#
        respond(200, "[\(item)]")
        let plain = try await makeClient().fetchGroups()
        respond(200, #"{"data":[\#(item)]}"#)
        let wrapped = try await makeClient().fetchGroups()
        XCTAssertEqual(plain, wrapped)
        XCTAssertEqual(plain.first?.name, "ІО-42")
    }

    func testHTTPStatusIsCheckedBeforeDecoding() async {
        respond(503, validSchedule)   // тіло коректне, але статус неуспішний
        do {
            _ = try await makeClient().fetchSchedule(groupId: 1)
            XCTFail("Очікували помилку")
        } catch NetworkError.invalidHTTPStatus(let code) {
            XCTAssertEqual(code, 503)
        } catch {
            XCTFail("Неправильний тип помилки: \(error)")
        }
    }

    func testBrokenJSONThrowsDecodingError() async {
        respond(200, #"{"scheduleFirstWeek": 42}"#)
        do {
            _ = try await makeClient().fetchSchedule(groupId: 1)
            XCTFail("Очікували помилку")
        } catch NetworkError.decodingError {
            // ok
        } catch {
            XCTFail("Неправильний тип помилки: \(error)")
        }
    }

    func testTransportFailureThrowsTransportError() async {
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        do {
            _ = try await makeClient().fetchGroups()
            XCTFail("Очікували помилку")
        } catch NetworkError.transportError {
            // ok
        } catch {
            XCTFail("Неправильний тип помилки: \(error)")
        }
    }
}

// MARK: - Стани екрана через ScheduleViewModel + мок API

private struct NoopOpener: LinkOpening { func open(_ url: URL) {} }

private struct FrozenClock: ScheduleClock {
    func snapshot() -> TimeSnapshot { TimeSnapshot(week: .first, weekday: .wednesday, minutes: 8 * 60 + 40) }
}

@MainActor
final class ScheduleLoadingStatesTests: XCTestCase {
    private var folder: URL!

    override func setUp() {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        UserDefaults.standard.set("ІО-42", forKey: "selectedGroup")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: folder)
    }

    private func makeVM(_ scenario: MockScheduleAPIService.Scenario) -> ScheduleViewModel {
        let api = MockScheduleAPIService(scenario: scenario, delayNanoseconds: 0)
        return ScheduleViewModel(repository: RemoteScheduleRepository(apiService: api, cacheFolder: folder),
                                 linkOpener: NoopOpener(), clock: FrozenClock(),
                                 electives: InMemoryElectiveStore(), links: InMemoryLessonLinkStore())
    }

    func testSuccessShowsSections() async {
        let vm = makeVM(.success)
        await vm.reload()
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.displayedError)
        XCTAssertEqual(vm.sections.count, 2)   // Пн і Ср першого тижня
    }

    func testEmptyResponseIsNotAnError() async {
        let vm = makeVM(.empty)
        await vm.reload()
        XCTAssertNil(vm.displayedError)
        XCTAssertFalse(vm.hasSchedule)
        XCTAssertTrue(vm.sections.isEmpty)
    }

    func testOfflineShowsErrorWhenNothingCached() async {
        let vm = makeVM(.offline)
        await vm.reload()
        XCTAssertNotNil(vm.refreshError)   // помилка не губиться після перечитування кешу
        XCTAssertFalse(vm.hasSchedule)
    }

    func testHTTPErrorAndBadFormatHaveDifferentMessages() async {
        let http = makeVM(.http500)
        await http.reload()
        XCTAssertTrue(http.displayedError?.contains("500") == true)

        let bad = makeVM(.badjson)
        await bad.reload()
        XCTAssertTrue(bad.displayedError?.contains("формат") == true)
    }

    func testCachedScheduleSurvivesFailedRefresh() async {
        await makeVM(.success).reload()          // заповнили кеш
        let vm = makeVM(.offline)
        await vm.reload()
        XCTAssertNotNil(vm.refreshError)         // банер «не вдалося оновити»
        XCTAssertTrue(vm.hasSchedule)            // але збережений розклад показано
        XCTAssertFalse(vm.sections.isEmpty)
    }

    func testRetryAfterFailureSucceeds() async {
        let vm = makeVM(.flaky)
        await vm.reload()
        XCTAssertNotNil(vm.refreshError)
        await vm.reload()                        // «Повторити»
        XCTAssertNil(vm.refreshError)
        XCTAssertTrue(vm.hasSchedule)
    }

    // MARK: регресії

    func testDisabledSubjectStaysInSubjectList() async {
        let vm = makeVM(.success)
        await vm.reload()
        let name = vm.subjectOptions[0].name
        vm.setSubject(name, enabled: false)
        _ = vm.allDays                            // «Головна» читає allDays
        XCTAssertTrue(vm.subjectOptions.contains { $0.name == name })   // не зникає зі списку
        vm.setSubject(name, enabled: true)
        XCTAssertFalse(vm.sections.isEmpty)
    }

    func testUserLinkIsSavedAppliedAndRemoved() async throws {
        let vm = makeVM(.success)
        await vm.reload()
        let lesson = try XCTUnwrap(vm.sections.flatMap(\.lessons).first)
        func current() -> String? {
            vm.sections.flatMap(\.lessons)
                .first { $0.subjectName == lesson.subjectName && $0.type == lesson.type }?.link
        }

        XCTAssertNotNil(vm.setLink("не лінк", for: lesson))
        XCTAssertNil(current())
        XCTAssertNil(vm.setLink("https://example.com/room", for: lesson))
        XCTAssertEqual(current(), "https://example.com/room")
        vm.removeLink(for: lesson)
        XCTAssertNil(current())
    }

    func testFocusSwitchesToWeekOfLesson() async throws {
        let vm = makeVM(.success)
        await vm.reload()
        let second = try XCTUnwrap(vm.allDays.first { $0.weekType == .second }?.lessons.first)
        vm.focus(on: second)
        XCTAssertEqual(vm.selectedWeek, .second)
        XCTAssertEqual(vm.focusedLessonID, second.id)
    }
}

// MARK: - «Спец. пари» (пари лише в окремі дати)

/// Середа 11.11.2026, 10:00, перший тиждень
private struct DatedClock: ScheduleClock {
    func snapshot() -> TimeSnapshot {
        let today = SystemScheduleClock.kyivCalendar.date(from: DateComponents(year: 2026, month: 11, day: 11))!
        return TimeSnapshot(week: .first, weekday: .wednesday, minutes: 10 * 60, today: today)
    }
}

final class ScheduleDatesTests: XCTestCase {
    private func lesson(_ name: String, _ time: String, dates: [String] = []) -> Lesson {
        LessonBuilder().subject(name).teacher("T").type(.lab).start(LessonTime(time)).room("1").dates(dates).build()
    }

    private func day(_ name: String, _ week: WeekType, _ lessons: [Lesson]) -> DailySchedule {
        var day = DailySchedule(dayOfWeek: name, weekType: week)
        day.lessons = lessons
        return day
    }

    func testNormalizeUnderstandsSeveralFormats() {
        XCTAssertEqual(LessonDates.normalize("2026-11-09"), "2026-11-09")
        XCTAssertEqual(LessonDates.normalize("2026-11-09T00:00:00Z"), "2026-11-09")
        XCTAssertEqual(LessonDates.normalize("09.11.2026"), "2026-11-09")
        XCTAssertEqual(LessonDates.normalize("9/1/2026"), "2026-01-09")
        XCTAssertEqual(LessonDates.normalize("якась дата"), "якась дата")
    }

    func testMapperAndAdapterKeepDates() throws {
        let json = """
        {"scheduleFirstWeek":[{"day":"Ср","pairs":[
          {"name":"Weekly","time":"08:30","type":"лек","dates":[]},
          {"name":"Special","time":"10:25","type":"лаб","dates":["11.11.2026","2026-11-25T00:00:00Z"]}]}],
         "scheduleSecondWeek":[]}
        """
        let dtos = try CampusScheduleMapper().dtos(from: Data(json.utf8), groupName: "G")
        let lessons = LessonDTOAdapter().adapt(dtos).flatMap(\.lessons)
        XCTAssertEqual(lessons.first { $0.subjectName == "Weekly" }?.dates, [])
        XCTAssertEqual(lessons.first { $0.subjectName == "Special" }?.dates, ["2026-11-11", "2026-11-25"])
    }

    private func makeVM() -> ScheduleViewModel {
        UserDefaults.standard.removeObject(forKey: "selectedGroup")
        let days = [
            day("Середа", .first, [lesson("A", "08:30"),
                                   lesson("S1", "10:25", dates: ["2026-11-11"]),
                                   lesson("S2", "12:20", dates: ["2026-11-18"])]),
            day("Середа", .second, [lesson("T1", "08:30", dates: ["2026-11-18"]),
                                    lesson("T2", "10:25", dates: ["2026-11-11"])])
        ]
        let vm = ScheduleViewModel(repository: MockScheduleRepository(schedules: [(group: "G", days: days)]),
                                   linkOpener: NoopOpener(), clock: DatedClock(),
                                   electives: InMemoryElectiveStore(), links: InMemoryLessonLinkStore())
        vm.load()
        return vm
    }

    func testSpecialLessonIsShownOnlyOnItsDate() {
        let vm = makeVM()
        XCTAssertEqual(vm.sections.first?.lessons.map(\.subjectName), ["A", "S1"])   // S2 лише 18.11
        XCTAssertEqual(vm.sections.first?.dateKey, "2026-11-11")
    }

    func testOtherWeekUsesDatesOfNextWeek() {
        let vm = makeVM()
        vm.selectedWeek = .second
        XCTAssertEqual(vm.sections.first?.lessons.map(\.subjectName), ["T1"])        // середа 18.11
        XCTAssertEqual(vm.sections.first?.dateKey, "2026-11-18")
    }

    func testHomeSkipsSpecialLessonThatIsNotToday() throws {
        let days = [
            day("Середа", .first, [lesson("S2", "14:00", dates: ["2026-11-18"])]),
            day("Четвер", .first, [lesson("W", "08:30")])
        ]
        guard case .upcoming(let next, let when) = HomeViewModel.lessonState(days: days, at: DatedClock().snapshot()) else {
            return XCTFail("Очікували наступну пару")
        }
        XCTAssertEqual(next.subjectName, "W")
        XCTAssertEqual(when, "завтра о 08:30")
    }

    func testSubjectsForTaskFormComeFromRealScheduleOfSelectedGroup() {
        let days = [day("Середа", .first, [lesson("A", "08:30"), lesson("B", "10:25")])]
        let repo = MockScheduleRepository(schedules: [(group: "G", days: days)])
        let store = InMemoryElectiveStore()
        store.save(["A"], for: "G")
        let provider = SelectedGroupSubjectsProvider(repository: repo, electives: store, selectedGroup: { "G" })
        XCTAssertEqual(provider.subjects(), ["A"])                 // лише відмічені в «Мої предмети»
        XCTAssertEqual(SelectedGroupSubjectsProvider(repository: repo, electives: InMemoryElectiveStore(),
                                                     selectedGroup: { "G" }).subjects(), ["A", "B"])
    }

    /// Фрагмент справжньої відповіді API (groupCode, tag, час із секундами, location: null)
    func testRealCampusResponseFormat() throws {
        let json = """
        {"groupCode":"4382","scheduleFirstWeek":[
          {"day":"Пн","pairs":[{"lecturer":{"id":"abc","name":"Галицький Д. В."},"type":"Лек",
            "time":"10:25:00","name":"Розробка мобільних застосувань під iOS","location":null,"tag":"lec",
            "dates":["2026-11-09","2026-11-23"]}]},
          {"day":"Вв","pairs":[{"lecturer":{"id":"def","name":"Корочкін О. В."},"type":"Лаб",
            "time":"12:20:00","name":"Паралельні та розподілені обчислення",
            "location":{"uri":"https://kpi.ua/k-18","title":"18-515"},"tag":"lab","dates":[]}]}],
         "scheduleSecondWeek":[]}
        """
        let dtos = try CampusScheduleMapper().dtos(from: Data(json.utf8), groupName: "ІО-42")
        let days = LessonDTOAdapter().adapt(dtos)
        let monday = try XCTUnwrap(days.first { $0.weekday == .monday }?.lessons.first)
        XCTAssertEqual(monday.type, .lecture)
        XCTAssertEqual(monday.startTime?.startText, "10:25")
        XCTAssertEqual(monday.dates, ["2026-11-09", "2026-11-23"])
        XCTAssertTrue(monday.isOnline)                 // location: null
        XCTAssertNil(monday.link)

        let tuesday = try XCTUnwrap(days.first { $0.weekday == .tuesday }?.lessons.first)
        XCTAssertEqual(tuesday.type, .lab)
        XCTAssertEqual(tuesday.room, "18-515")
        XCTAssertNil(tuesday.link)                     // uri будівлі не є лінком на пару
        XCTAssertTrue(tuesday.dates.isEmpty)           // щотижня
    }
}
