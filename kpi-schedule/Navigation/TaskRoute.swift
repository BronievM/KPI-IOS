//
//  TaskRoute.swift
//  kpi-schedule
//
//  Created by Maksym on 25.10.2026.
//

import Foundation

/// Маршрути стекової навігації
enum TaskRoute: Hashable {
    case detail(UUID)
}

/// Модальні екрани
enum TaskSheet: Identifiable, Equatable {
    case create
    case edit(UUID)

    var id: String {
        switch self {
        case .create:         return "create"
        case .edit(let id):   return "edit-\(id.uuidString)"
        }
    }
}
