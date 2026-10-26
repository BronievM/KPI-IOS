//
//  TaskNavigating.swift
//  kpi-schedule
//
//  Created by Maksym on 25.10.2026.
//

import Foundation

/// Навігаційні наміри ViewModel (без прив'язки до деталей UI)
/// AnyObject дозволяє ViewModel тримати weak-посилання на навігатора
extension Notification.Name {
    /// Сигнал для переходу на вкладку розкладу та показу предмета
    static let showInSchedule = Notification.Name("ShowInSchedule")
}

protocol TaskNavigating: AnyObject {
    func showDetail(id: UUID)
    func showCreate()
    func showInSchedule(subject: String)
    func showEdit(id: UUID)
    func dismissSheet()
    func popToList()
}
