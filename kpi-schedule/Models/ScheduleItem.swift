//
//  ScheduleItem.swift
//  kpi-schedule
//
//  Created by Maksym on 20.10.2026.
//

import Foundation

protocol ScheduleItem {
    var id: UUID { get }
    func getDetails() -> String
}