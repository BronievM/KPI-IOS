//
//  TaskProgress.swift
//  kpi-schedule
//
//  Created by Maksym on 25.10.2026.
//

import Foundation

/// Прогрес «виконано з усіх» (для предмета або загальний).
struct TaskProgress: Equatable {
    let done: Int
    let total: Int

    init(done: Int, total: Int) {
        self.done = done
        self.total = total
    }

    init(tasks: [StudyTask]) {
        self.done = tasks.filter(\.isDone).count
        self.total = tasks.count
    }

    var fraction: Double { total == 0 ? 0 : Double(done) / Double(total) }
}
