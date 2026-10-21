//
//  kpi_scheduleApp.swift
//  kpi-schedule
//
//  Originally created by Maksym Broniev on 21.09.2026.
//  Edited on 20.10.2026.
//

import SwiftUI
@main
struct kpi_scheduleApp: App {
    @StateObject private var scheduleViewModel = AppContainer.makeScheduleViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: scheduleViewModel)
        }
    }
}
