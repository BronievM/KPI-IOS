//
//  RootView.swift
//  kpi-schedule
//
//  Created by Maksym on 24.10.2026.
//  Updated by Maksym on 06.11.2026.
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

    /// Звідки відкрито деталі завдання (наприклад, «Головна»). Лише тоді «Назад» у деталях веде туди, а не до списку
    @State private var taskOrigin: AppTab?
    
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
        // повернулися до списку завдань: «походження» більше не діє
        .onChange(of: taskCoordinator.path) { _, path in
            if path.isEmpty { taskOrigin = nil }
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
                onOpenTask: openTask,
                onOpenSchedule: openLesson,
                onOpenTasks: openTaskList
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        case .tasks:
            TaskFlowView(coordinator: taskCoordinator,
                         backTitle: taskOrigin?.title,
                         onBack: taskOrigin == nil ? nil : goBack)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        
    }
    
    // MARK: навігація
    
    private func select(_ tab: AppTab) {
        // без анімації, як у звичайному TabView: інакше видно перехресне розчинення екранів
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { selectedTab = tab }
    }
    
    /// З «Головної» відкриваємо деталі завдання
    private func openTask(_ id: UUID) {
        taskCoordinator.popToList()      // щоб не накопичувати екрани
        taskCoordinator.showDetail(id: id)
        taskOrigin = selectedTab
        select(.tasks)
    }

    /// З «Головної» відкриваємо пару в розкладі
    private func openLesson(_ lesson: Lesson) {
        scheduleViewModel.focus(on: lesson)
        select(.schedule)
    }

    /// «Назад» з деталей завдання, відкритих з іншої вкладки: одразу туди, без миготіння списку
    private func goBack() {
        guard let origin = taskOrigin else { return }
        taskOrigin = nil
        select(origin)
        taskCoordinator.popToList()
    }
    
    private func openTaskList(){
        taskCoordinator.popToList()
        select(.tasks)
    }

    // MARK: власний tab bar
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button { taskOrigin = nil; select(tab) } label: {
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
