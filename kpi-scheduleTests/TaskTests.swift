import XCTest
@testable import kpi_schedule

private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)   // 2027-01-15 08:00 UTC
private let day: TimeInterval = 86_400

private var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}

private final class SpyNavigator: TaskNavigating {
    private(set) var calls: [String] = []
    func showDetail(id: UUID) { calls.append("detail:\(id)") }
    func showCreate() { calls.append("create") }
    func showEdit(id: UUID) { calls.append("edit:\(id)") }
    func dismissSheet() { calls.append("dismiss") }
    func popToList() { calls.append("pop") }
    func showInSchedule(subject: String) { calls.append("schedule:\(subject)") }
}

private final class SpyLinkOpener: LinkOpening {
    private(set) var opened: [URL] = []
    func open(_ url: URL) { opened.append(url) }
}

private struct StubSubjects: SubjectsProviding {
    var list: [String] = []
    func subjects() -> [String] { list }
}

private func makeTask(_ title: String = "ЛАБ1",
                      subject: String = "S1",
                      done: Bool = false,
                      deadlineDays: Double? = 1,
                      link: String? = nil) -> StudyTask {
    StudyTask(title: title,
              subject: subject,
              deadline: deadlineDays.map { fixedNow.addingTimeInterval($0 * day) },
              link: link,
              isDone: done)
}

// MARK: - Модель

final class StudyTaskModelTests: XCTestCase {
    func testOverdue() {
        XCTAssertTrue(makeTask(deadlineDays: -1).isOverdue(at: fixedNow))
        XCTAssertFalse(makeTask(deadlineDays: 1).isOverdue(at: fixedNow))
        XCTAssertFalse(makeTask(done: true, deadlineDays: -1).isOverdue(at: fixedNow))   // виконане не прострочене
        XCTAssertFalse(makeTask(deadlineDays: nil).isOverdue(at: fixedNow))              // довгостроково
    }

    func testProgress() {
        let progress = TaskProgress(tasks: [makeTask(done: true), makeTask(done: false), makeTask(done: true)])
        XCTAssertEqual(progress.done, 2)
        XCTAssertEqual(progress.total, 3)
        XCTAssertEqual(progress.fraction, 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(TaskProgress(tasks: []).fraction, 0)
    }

    func testTaskIsCodable() throws {
        let task = makeTask(link: "https://example.com")
        let data = try JSONEncoder().encode(task)
        XCTAssertEqual(try JSONDecoder().decode(StudyTask.self, from: data), task)
    }
}

final class DeadlineInfoTests: XCTestCase {
    private func info(_ days: Double?, done: Bool = false) -> DeadlineInfo {
        DeadlineInfo(deadline: days.map { fixedNow.addingTimeInterval($0 * day) },
                     isDone: done, now: fixedNow, calendar: utcCalendar)
    }

    func testTexts() {
        XCTAssertEqual(info(nil).text, "Довгостроково")
        XCTAssertEqual(info(0).text, "сьогодні")
        XCTAssertEqual(info(1).text, "завтра")
        XCTAssertEqual(info(24).text, "24 дні")
        XCTAssertEqual(info(-2).text, "прострочено на 2 дні")
    }

    func testUrgency() {
        XCTAssertEqual(info(nil).urgency, .none)
        XCTAssertEqual(info(-1).urgency, .overdue)
        XCTAssertEqual(info(0).urgency, .soon)
        XCTAssertEqual(info(3).urgency, .soon)
        XCTAssertEqual(info(10).urgency, .normal)
        XCTAssertEqual(info(-1, done: true).urgency, .none)   // виконане не підсвічується
    }

    func testUkrainianPlurals() {
        XCTAssertEqual(DeadlineInfo.daysText(1), "1 день")
        XCTAssertEqual(DeadlineInfo.daysText(2), "2 дні")
        XCTAssertEqual(DeadlineInfo.daysText(5), "5 днів")
        XCTAssertEqual(DeadlineInfo.daysText(11), "11 днів")
        XCTAssertEqual(DeadlineInfo.daysText(12), "12 днів")
        XCTAssertEqual(DeadlineInfo.daysText(21), "21 день")
        XCTAssertEqual(DeadlineInfo.daysText(22), "22 дні")
    }
}

// MARK: - Репозиторії та предмети

final class TaskRepositoryTests: XCTestCase {
    func testSaveInsertsAndUpdates() {
        let repo = InMemoryTaskRepository()
        var task = makeTask()
        repo.save(task)
        task.title = "Changed"
        repo.save(task)
        XCTAssertEqual(repo.allTasks().count, 1)
        XCTAssertEqual(repo.task(with: task.id)?.title, "Changed")
    }

    func testDelete() {
        let task = makeTask()
        let repo = InMemoryTaskRepository(tasks: [task])
        repo.delete(id: task.id)
        XCTAssertNil(repo.task(with: task.id))
    }

    func testFileRepositoryPersistsBetweenInstances() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }

        let first = FileTaskRepository(fileURL: url, fallback: [])
        let task = makeTask("Persisted")
        first.save(task)

        let second = FileTaskRepository(fileURL: url, fallback: [])
        XCTAssertEqual(second.task(with: task.id)?.title, "Persisted")
    }

    func testScheduleSubjectsProviderCollectsUniqueSortedSubjects() {
        let monday = DailySchedule(dayOfWeek: "Monday", weekType: .first)
        monday.addLesson(LessonBuilder().subject("B").teacher("T").type(.lecture).build())
        monday.addLesson(LessonBuilder().subject("A").teacher("T").type(.lab).build())
        let tuesday = DailySchedule(dayOfWeek: "Tuesday", weekType: .first)
        tuesday.addLesson(LessonBuilder().subject("B").teacher("T").type(.practice).build())

        let repo = MockScheduleRepository(schedules: [(group: "G", days: [monday, tuesday])])
        XCTAssertEqual(ScheduleSubjectsProvider(repository: repo).subjects(), ["A", "B"])
    }
}

// MARK: - Список

final class TaskListViewModelTests: XCTestCase {
    private func makeSUT(_ tasks: [StudyTask], navigator: TaskNavigating? = nil) -> (TaskListViewModel, InMemoryTaskRepository) {
        let repo = InMemoryTaskRepository(tasks: tasks)
        return (TaskListViewModel(repository: repo, navigator: navigator, now: { fixedNow }), repo)
    }

    private var sample: [StudyTask] {
        [
            makeTask("ЛАБ1", subject: "S1", done: true),
            makeTask("ЛАБ2", subject: "S1", done: false, deadlineDays: 5),
            makeTask("ЛАБ1", subject: "S2", done: false, deadlineDays: nil)
        ]
    }

    func testGroupsBySubjectWithProgress() {
        let (vm, _) = makeSUT(sample)
        XCTAssertEqual(vm.sections.map(\.subject), ["S1", "S2"])
        XCTAssertEqual(vm.sections[0].progress, TaskProgress(done: 1, total: 2))
        XCTAssertEqual(vm.sections[1].progress, TaskProgress(done: 0, total: 1))
        XCTAssertEqual(vm.overall, TaskProgress(done: 1, total: 3))
        XCTAssertEqual(vm.subjects, ["S1", "S2"])
    }

    func testSubjectFilterKeepsOverallProgress() {
        let (vm, _) = makeSUT(sample)
        vm.selectedSubject = "S2"
        XCTAssertEqual(vm.sections.map(\.subject), ["S2"])
        XCTAssertEqual(vm.overall, TaskProgress(done: 1, total: 3))   // загальний прогрес не залежить від фільтра
    }

    func testOnlyUnfinishedFilterKeepsSubjectProgress() {
        let (vm, _) = makeSUT(sample)
        vm.onlyUnfinished = true
        XCTAssertEqual(vm.sections[0].rows.map(\.title), ["ЛАБ2"])
        XCTAssertEqual(vm.sections[0].progress, TaskProgress(done: 1, total: 2))   // прогрес предмета не змінюється
    }

    func testRowsAreSortedUnfinishedFirstThenByDeadline() {
        let tasks = [
            makeTask("done", done: true, deadlineDays: 1),
            makeTask("none", deadlineDays: nil),
            makeTask("late", deadlineDays: 9),
            makeTask("soon", deadlineDays: 2)
        ]
        let (vm, _) = makeSUT(tasks)
        XCTAssertEqual(vm.sections[0].rows.map(\.title), ["soon", "late", "none", "done"])
    }

    func testRowShowsDeadlineText() {
        let (vm, _) = makeSUT([makeTask("ЛАБ1", deadlineDays: nil)])
        XCTAssertEqual(vm.sections[0].rows[0].deadlineText, "Довгостроково")
    }

    func testToggleDoneUpdatesRowAndProgress() {
        let tasks = sample
        let (vm, repo) = makeSUT(tasks)
        vm.toggleDone(tasks[1].id)
        XCTAssertEqual(repo.task(with: tasks[1].id)?.isDone, true)
        XCTAssertEqual(vm.overall, TaskProgress(done: 2, total: 3))
    }

    func testDeletingLastTaskOfSelectedSubjectResetsFilter() {
        let tasks = sample
        let (vm, repo) = makeSUT(tasks)
        vm.selectedSubject = "S2"
        repo.delete(id: tasks[2].id)
        XCTAssertNil(vm.selectedSubject)
        XCTAssertEqual(vm.sections.map(\.subject), ["S1"])
    }

    func testListUpdatesAfterRepositoryChange() {
        let (vm, repo) = makeSUT([])
        XCTAssertTrue(vm.sections.isEmpty)
        repo.save(makeTask("new"))
        XCTAssertEqual(vm.sections.first?.rows.first?.title, "new")
    }

    func testIntentsGoToNavigator() {
        let nav = SpyNavigator()
        let task = makeTask()
        let (vm, _) = makeSUT([task], navigator: nav)
        vm.select(task.id)
        vm.addTapped()
        XCTAssertEqual(nav.calls, ["detail:\(task.id)", "create"])
    }
}

// MARK: - Деталі

final class TaskDetailViewModelTests: XCTestCase {
    private func makeSUT(_ task: StudyTask, navigator: TaskNavigating? = nil, opener: LinkOpening = SpyLinkOpener()) -> (TaskDetailViewModel, InMemoryTaskRepository) {
        let repo = InMemoryTaskRepository(tasks: [task])
        let vm = TaskDetailViewModel(taskID: task.id, repository: repo, navigator: navigator, linkOpener: opener, now: { fixedNow })
        return (vm, repo)
    }

    func testToggleDoneSavesToRepository() {
        let task = makeTask()
        let (vm, repo) = makeSUT(task)
        vm.toggleDone()
        XCTAssertEqual(vm.task?.isDone, true)
        XCTAssertEqual(repo.task(with: task.id)?.isDone, true)
        vm.toggleDone()
        XCTAssertEqual(vm.task?.isDone, false)
    }

    func testOpenLinkUsesOpenerOnlyWhenLinkExists() {
        let spy = SpyLinkOpener()
        let (withoutLink, _) = makeSUT(makeTask(), opener: spy)
        withoutLink.openLink()
        XCTAssertTrue(spy.opened.isEmpty)

        let (withLink, _) = makeSUT(makeTask(link: "https://example.com/task"), opener: spy)
        withLink.openLink()
        XCTAssertEqual(spy.opened, [URL(string: "https://example.com/task")!])
    }

    func testDetailUpdatesWhenTaskIsEditedElsewhere() {
        let task = makeTask("old")
        let (vm, repo) = makeSUT(task)
        var edited = task
        edited.title = "new"
        repo.save(edited)
        XCTAssertEqual(vm.task?.title, "new")
    }

    func testDeadlineInfoIsAvailable() {
        let (vm, _) = makeSUT(makeTask(deadlineDays: nil))
        XCTAssertEqual(vm.deadlineInfo?.text, "Довгостроково")
    }

    func testEditAndDeleteGoThroughNavigator() {
        let nav = SpyNavigator()
        let task = makeTask()
        let (vm, repo) = makeSUT(task, navigator: nav)
        vm.editTapped()
        vm.deleteTapped()
        XCTAssertTrue(vm.showDeleteConfirmation)
        vm.deleteConfirmed()
        XCTAssertEqual(nav.calls, ["edit:\(task.id)", "pop"])
        XCTAssertNil(repo.task(with: task.id))
        XCTAssertNil(vm.task)
    }

    func testShowInScheduleGoesThroughNavigatorWithSubject() {
        let nav = SpyNavigator()
        let (vm, _) = makeSUT(makeTask(subject: "Networks"), navigator: nav)
        vm.showInSchedule()
        XCTAssertEqual(nav.calls, ["schedule:Networks"])
    }
}

// MARK: - Форма

final class TaskFormViewModelTests: XCTestCase {
    private func makeSUT(task: StudyTask? = nil,
                         stored: [StudyTask] = [],
                         scheduleSubjects: [String] = ["Math", "Art"],
                         navigator: TaskNavigating? = nil) -> (TaskFormViewModel, InMemoryTaskRepository) {
        let repo = InMemoryTaskRepository(tasks: stored)
        let vm = TaskFormViewModel(task: task, repository: repo, subjects: StubSubjects(list: scheduleSubjects),
                                   navigator: navigator, now: { fixedNow })
        return (vm, repo)
    }

    func testSubjectsAreMergedAndSorted() {
        let (vm, _) = makeSUT(stored: [makeTask(subject: "Zoology")])
        XCTAssertEqual(vm.availableSubjects, ["Art", "Math", "Zoology"])
        XCTAssertEqual(vm.subjectSelection, "Art")
    }

    func testValidationMessagesInOrder() {
        let (vm, _) = makeSUT(scheduleSubjects: [])
        XCTAssertEqual(vm.subjectSelection, TaskFormViewModel.customOption)
        XCTAssertNotNil(vm.validationMessage)               // немає назви
        vm.title = "ЛАБ5"
        XCTAssertEqual(vm.validationMessage, "Оберіть предмет або введіть новий")
        vm.customSubject = "  New subject "
        XCTAssertNil(vm.validationMessage)
        vm.link = "not a url"
        XCTAssertNotNil(vm.validationMessage)
        vm.link = "https://example.com"
        XCTAssertNil(vm.validationMessage)
    }

    func testCreateSavesTaskWithSubjectAndDismisses() {
        let nav = SpyNavigator()
        let (vm, repo) = makeSUT(navigator: nav)
        vm.title = "  ЛАБ5 "
        vm.subjectSelection = "Math"
        vm.link = "https://example.com/a"
        vm.save()

        let saved = repo.allTasks()
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved[0].title, "ЛАБ5")
        XCTAssertEqual(saved[0].subject, "Math")
        XCTAssertEqual(saved[0].link, "https://example.com/a")
        XCTAssertNotNil(saved[0].deadline)
        XCTAssertFalse(saved[0].isDone)
        XCTAssertEqual(nav.calls, ["dismiss"])
    }

    func testCustomSubjectIsUsed() {
        let (vm, repo) = makeSUT()
        vm.title = "ЛАБ1"
        vm.subjectSelection = TaskFormViewModel.customOption
        vm.customSubject = "Philosophy"
        vm.save()
        XCTAssertEqual(repo.allTasks().first?.subject, "Philosophy")
    }

    func testNoDeadlineSavesNil() {
        let (vm, repo) = makeSUT()
        vm.title = "ЛАБ1"
        vm.hasDeadline = false
        vm.save()
        XCTAssertNil(repo.allTasks().first?.deadline)
    }

    func testInvalidFormIsNotSaved() {
        let nav = SpyNavigator()
        let (vm, repo) = makeSUT(navigator: nav)
        vm.save()
        XCTAssertTrue(repo.allTasks().isEmpty)
        XCTAssertTrue(nav.calls.isEmpty)
    }

    func testEditKeepsIdAndDoneState() {
        let task = makeTask("old", subject: "Math", done: true)
        let (vm, repo) = makeSUT(task: task, stored: [task])
        XCTAssertTrue(vm.isEditing)
        XCTAssertEqual(vm.subjectSelection, "Math")
        vm.title = "renamed"
        vm.save()
        XCTAssertEqual(repo.allTasks().count, 1)
        XCTAssertEqual(repo.task(with: task.id)?.title, "renamed")
        XCTAssertEqual(repo.task(with: task.id)?.isDone, true)
    }

    func testEditingTaskWithoutDeadlineKeepsToggleOff() {
        let task = makeTask(deadlineDays: nil)
        let (vm, _) = makeSUT(task: task, stored: [task])
        XCTAssertFalse(vm.hasDeadline)
    }

    func testCancelOnlyDismisses() {
        let nav = SpyNavigator()
        let (vm, repo) = makeSUT(navigator: nav)
        vm.title = "x"
        vm.cancel()
        XCTAssertEqual(nav.calls, ["dismiss"])
        XCTAssertTrue(repo.allTasks().isEmpty)
    }
}

// MARK: - Coordinator

final class TaskCoordinatorTests: XCTestCase {
    private func makeSUT(tasks: [StudyTask] = []) -> TaskCoordinator {
        let factory = TaskScreenFactory(repository: InMemoryTaskRepository(tasks: tasks),
                                        subjects: StubSubjects(),
                                        linkOpener: SpyLinkOpener(),
                                        now: { fixedNow })
        return TaskCoordinator(factory: factory)
    }

    func testShowDetailPushesOnlyOnce() {
        let id = UUID()
        let coordinator = makeSUT()
        coordinator.showDetail(id: id)
        coordinator.showDetail(id: id)            // подвійний тап
        XCTAssertEqual(coordinator.path, [.detail(id)])
    }

    func testPopToListClearsStack() {
        let coordinator = makeSUT()
        coordinator.showDetail(id: UUID())
        coordinator.popToList()
        XCTAssertTrue(coordinator.path.isEmpty)
    }

    func testSheetPresentAndDismiss() {
        let id = UUID()
        let coordinator = makeSUT()
        coordinator.showCreate()
        XCTAssertEqual(coordinator.sheet, .create)
        coordinator.showEdit(id: id)               // поки відкрита форма, друга не відкривається
        XCTAssertEqual(coordinator.sheet, .create)
        coordinator.dismissSheet()
        XCTAssertNil(coordinator.sheet)
        coordinator.showEdit(id: id)
        XCTAssertEqual(coordinator.sheet, .edit(id))
    }

    func testEditFormIsPrefilledFromRepository() {
        let task = makeTask("prefilled", subject: "Math")
        let coordinator = makeSUT(tasks: [task])
        let form = coordinator.makeFormViewModel(for: .edit(task.id))
        XCTAssertTrue(form.isEditing)
        XCTAssertEqual(form.title, "prefilled")
        XCTAssertEqual(form.subjectSelection, "Math")
    }

    func testListViewModelIsReusedAndNavigatesThroughCoordinator() {
        let task = makeTask()
        let coordinator = makeSUT(tasks: [task])
        XCTAssertTrue(coordinator.listViewModel === coordinator.listViewModel)
        coordinator.listViewModel.select(task.id)
        coordinator.listViewModel.addTapped()
        XCTAssertEqual(coordinator.path, [.detail(task.id)])
        XCTAssertEqual(coordinator.sheet, .create)
    }
}