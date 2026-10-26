//
//  kpi_scheduleApp.swift
//  kpi-schedule
//
//  Created by Maksym on 21.10.2026.
//  Updated by Maksym on 25.10.2026.
//

import SwiftUI

@main
struct kpi_scheduleApp: App {
    @StateObject private var scheduleViewModel = AppContainer.makeScheduleViewModel()
    private let taskRepository: TaskRepository
    private let taskFactory: TaskScreenFactory

    init() {
        let repository = AppContainer.makeTaskRepository()
        taskRepository = repository
        taskFactory = AppContainer.makeTaskScreenFactory(repository: repository)
    }

    var body: some Scene {
        WindowGroup {
            RootView(scheduleViewModel: scheduleViewModel, taskFactory: taskFactory, taskRepository: taskRepository)
                // увесь інтерфейс українською
                .environment(\.locale, Locale(identifier: "uk_UA"))
        }
    }
}
