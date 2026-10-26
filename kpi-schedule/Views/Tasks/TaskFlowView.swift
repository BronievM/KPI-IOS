//
//  TaskFlowView.swift
//  kpi-schedule
//
//  Created by Maksym on 25.10.2026.
//

import SwiftUI

/// Корінь потоку завдань. Навігацією (стеком та модальними вікнами) керує Coordinator
struct TaskFlowView: View {
    /// Coordinator створюється в `RootView`, щоб інші вкладки могли відкрити завдання
    @ObservedObject var coordinator: TaskCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            TaskListScreen(viewModel: coordinator.listViewModel)
                .navigationDestination(for: TaskRoute.self) { route in
                    switch route {
                    case .detail(let id):
                        TaskDetailScreen(viewModel: coordinator.makeDetailViewModel(id: id))
                    }
                }
        }
        .sheet(item: $coordinator.sheet) { sheet in
            TaskFormScreen(viewModel: coordinator.makeFormViewModel(for: sheet))
        }
    }
}
