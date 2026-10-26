//
//  TaskExtrasTests.swift
//  kpi-scheduleTests
//
//  Created by Maksym on 25.10.2026.
//

import XCTest
@testable import kpi_schedule

/// Файлове сховище в пам'яті: перевіряємо, що форма не залишає «сміття».
private final class FakeStorage: AttachmentStoring {
    private(set) var files: Set<UUID> = []
    func importFile(from source: URL, taskID: UUID) throws -> TaskAttachment {
        let attachment = TaskAttachment(fileName: source.lastPathComponent)
        files.insert(attachment.id)
        return attachment
    }
    func fileURL(for attachment: TaskAttachment, taskID: UUID) -> URL { URL(fileURLWithPath: "/dev/null") }
    func remove(_ attachment: TaskAttachment, taskID: UUID) { files.remove(attachment.id) }
    func removeAll(for taskID: UUID) { files.removeAll() }
}

private struct NoSubjects: SubjectsProviding {
    func subjects() -> [String] { [] }       // electiveSubjects() береться зі стандартної реалізації
}

final class TaskExtrasTests: XCTestCase {

    func testOldTasksJSONWithoutAttachmentsStillDecodes() throws {
        let json = #"[{"id":"7B1F1E0A-0000-4000-8000-000000000001","title":"ЛАБ1","subject":"iOS"}]"#
        let tasks = try JSONDecoder().decode([StudyTask].self, from: Data(json.utf8))
        XCTAssertEqual(tasks.first?.title, "ЛАБ1")
        XCTAssertEqual(tasks.first?.attachments, [])
        XCTAssertEqual(tasks.first?.isDone, false)
    }

    func testSecondTapOnSubjectShowsEverything() {
        let repo = InMemoryTaskRepository(tasks: [
            StudyTask(title: "A", subject: "X"), StudyTask(title: "B", subject: "Y")
        ])
        let vm = TaskListViewModel(repository: repo, navigator: nil)
        vm.toggleSubject("X")
        XCTAssertEqual(vm.sections.map(\.subject), ["X"])
        vm.toggleSubject("X")
        XCTAssertNil(vm.selectedSubject)
        XCTAssertEqual(vm.sections.map(\.subject), ["X", "Y"])
    }

    func testSearchMatchesTitleSubjectAndNote() {
        let repo = InMemoryTaskRepository(tasks: [
            StudyTask(title: "ЛАБ5", subject: "Мережі"),
            StudyTask(title: "ЛАБ6", subject: "iOS", note: "потрібен Xcode")
        ])
        let vm = TaskListViewModel(repository: repo, navigator: nil)
        vm.searchText = "лаб5"
        XCTAssertEqual(vm.sections.flatMap(\.rows).map(\.title), ["ЛАБ5"])
        vm.searchText = "xcode"
        XCTAssertEqual(vm.sections.flatMap(\.rows).map(\.title), ["ЛАБ6"])
        vm.searchText = ""
        XCTAssertEqual(vm.sections.flatMap(\.rows).count, 2)
    }

    func testAdapterReadsElectiveFlag() throws {
        let json = """
        [{"group":"G","day":"Понеділок","subject":"Вибірковий","teacher":"T","type":"Лекція","elective":true},
         {"group":"G","day":"Понеділок","subject":"Обов'язковий","teacher":"T","type":"Лекція"}]
        """
        let repo = JSONScheduleRepository(json: json)
        let lessons = try repo.fetchWeeklySchedule(for: "G").flatMap(\.lessons)
        XCTAssertEqual(lessons.first { $0.subjectName == "Вибірковий" }?.isElective, true)
        XCTAssertEqual(lessons.first { $0.subjectName == "Обов'язковий" }?.isElective, false)
        XCTAssertEqual(ScheduleSubjectsProvider(repository: repo).electiveSubjects(), ["Вибірковий"])
        XCTAssertEqual(NoSubjects().electiveSubjects(), [])
    }

    func testDeadlinePresets() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let vm = TaskFormViewModel(task: nil, repository: InMemoryTaskRepository(),
                                   subjects: NoSubjects(), navigator: nil, now: { now })
        XCTAssertEqual(vm.selectedPreset, .nextWeek)          // за замовчуванням +7 днів
        vm.select(.tomorrow)
        XCTAssertTrue(vm.hasDeadline)
        XCTAssertEqual(vm.selectedPreset, .tomorrow)
        vm.select(.noDeadline)
        XCTAssertFalse(vm.hasDeadline)
        XCTAssertEqual(vm.selectedPreset, .noDeadline)
    }

    func testCancelledFormRemovesNewFiles_savedFormKeepsThem() {
        let storage = FakeStorage()
        let repo = InMemoryTaskRepository()
        let file = URL(fileURLWithPath: "/tmp/umova.pdf")

        var cancelled: TaskFormViewModel? = TaskFormViewModel(
            task: nil, repository: repo, subjects: NoSubjects(), navigator: nil, attachments: storage)
        cancelled?.addAttachments(from: .success([file]))
        XCTAssertEqual(storage.files.count, 1)
        cancelled = nil                                   // форму закрито без збереження
        XCTAssertTrue(storage.files.isEmpty)

        let saved = TaskFormViewModel(
            task: nil, repository: repo, subjects: NoSubjects(), navigator: nil, attachments: storage)
        saved.title = "ЛАБ1"
        saved.customSubject = "iOS"
        saved.subjectSelection = TaskFormViewModel.customOption
        saved.addAttachments(from: .success([file]))
        saved.save()
        XCTAssertEqual(storage.files.count, 1)
        XCTAssertEqual(repo.allTasks().first?.attachments.count, 1)
    }

    // MARK: «Головна»

    private func day(_ name: String, _ week: WeekType, _ hour: Int, _ minute: Int, link: String? = nil) -> DailySchedule {
        let d = DailySchedule(dayOfWeek: name, weekType: week)
        d.addLesson(LessonBuilder().subject("iOS").teacher("T").link(link).start(LessonTime(hour: hour, minute: minute)).build())
        return d
    }

    func testHomeShowsCurrentLessonWithProgress() {
        let now = TimeSnapshot(week: .first, weekday: .monday, minutes: 8 * 60 + 30 + 19)
        guard case .current(let lesson, let progress, let left) =
                HomeViewModel.lessonState(days: [day("Понеділок", .first, 8, 30)], at: now) else {
            return XCTFail("очікувалась поточна пара")
        }
        XCTAssertEqual(lesson.subjectName, "iOS")
        XCTAssertEqual(progress, 19.0 / 95.0, accuracy: 0.001)
        XCTAssertEqual(left, 76)
    }

    func testHomeUpcomingToday_tomorrow_andAcrossWeekFlip() {
        func when(_ days: [DailySchedule], _ snapshot: TimeSnapshot) -> String? {
            if case .upcoming(_, let when) = HomeViewModel.lessonState(days: days, at: snapshot) { return when }
            return nil
        }
        XCTAssertEqual(when([day("Понеділок", .first, 8, 30)],
                            TimeSnapshot(week: .first, weekday: .monday, minutes: 8 * 60)), "через 30 хв")
        XCTAssertEqual(when([day("Вівторок", .first, 10, 25)],
                            TimeSnapshot(week: .first, weekday: .monday, minutes: 18 * 60)), "завтра о 10:25")
        // пари є лише в другому тижні: з середи першого тижня найближча — понеділок наступного
        XCTAssertEqual(when([day("Понеділок", .second, 8, 30)],
                            TimeSnapshot(week: .first, weekday: .wednesday, minutes: 12 * 60)), "Понеділок, 08:30")
        XCTAssertNil(when([], TimeSnapshot(week: .first, weekday: .monday, minutes: 0)))
    }

    func testDurationTextAndDeadlineToday() {
        XCTAssertEqual(HomeViewModel.durationText(80), "1 год 20 хв")
        XCTAssertEqual(HomeViewModel.durationText(45), "45 хв")
        XCTAssertEqual(HomeViewModel.durationText(120), "2 год")
        let now = Date()
        XCTAssertTrue(DeadlineInfo(deadline: now, isDone: false, now: now).isToday)
        XCTAssertFalse(DeadlineInfo(deadline: now, isDone: true, now: now).isToday)
    }
}
