//
//  RootView.swift
//  kpi-schedule
//
//  Created by Maksym on 24.10.2026.
//  Updated by Maksym on 26.10.2026.
//

import SwiftUI

/// Вкладки застосунку (порядок зліва направо)
enum AppTab: Int, CaseIterable {
    case schedule, home, tasks

    var title: String {
        switch self {
        case .schedule: return "Розклад"
        case .home:     return "Головна"
        case .tasks:    return "Завдання"
        }
    }

    var symbol: String {
        switch self {
        case .schedule: return "calendar"
        case .home:     return "house.fill"
        case .tasks:    return "checklist"
        }
    }
}

struct RootView: View {
    @ObservedObject var scheduleViewModel: ScheduleViewModel
    let taskFactory: TaskScreenFactory
    let taskRepository: TaskRepository
    
    /// Coordinator живе тут, щоб «Головна» могла відкрити деталі завдання
    @StateObject private var taskCoordinator: TaskCoordinator
    
    /// Спочатку відкривається «Головна»
    @State private var selectedTab: AppTab = .home
    
    init(scheduleViewModel: ScheduleViewModel, taskFactory: TaskScreenFactory, taskRepository: TaskRepository) {
        self.scheduleViewModel = scheduleViewModel
        self.taskFactory = taskFactory
        self.taskRepository = taskRepository
        _taskCoordinator = StateObject(wrappedValue: TaskCoordinator(factory: taskFactory))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            tabBar
        }
        .onReceive(NotificationCenter.default.publisher(for: .showInSchedule)) { notification in
            if let subject = notification.object as? String {
                scheduleViewModel.filterBySubject(subject)
                select(.schedule)
            }
        }
    }
    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .schedule:
            ContentView(viewModel: scheduleViewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        case .home:
            HomeView(
                schedule: scheduleViewModel,
                tasks: taskRepository,
                onOpenTask: openTask
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        case .tasks:
            TaskFlowView(coordinator: taskCoordinator)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        
    }
    
    // MARK: навігація
    
    private func select(_ tab: AppTab) {
        withAnimation(.snappy) { selectedTab = tab }
    }
    
    /// З «Головної» відкриваємо деталі завдання
    private func openTask(_ id: UUID) {
        taskCoordinator.popToList()      // щоб не накопичувати екрани
        taskCoordinator.showDetail(id: id)
        select(.tasks)
    }
    
    // MARK: власний tab bar
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button { select(tab) } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.symbol).font(.title3)
                        Text(tab.title).font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}
