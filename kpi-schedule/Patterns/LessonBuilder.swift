//
//  LessonBuilder.swift
//  kpi-schedule
//
//  Created by Maksym on 21.10.2026.
//  Updated by Maksym on 25.10.2026.
//

import Foundation

/// PATTERN: Builder.
/// створення Lesson з багатьма опціональними полями без довгого init.
final class LessonBuilder {
    private var subjectName = ""
    private var teacher = ""
    private var type: LessonType = .lecture
    private var room: String?
    private var isOnline = false
    private var link: String?
    private var startTime: LessonTime?
    private var isElective = false

    @discardableResult func subject(_ value: String) -> Self { subjectName = value; return self }
    @discardableResult func teacher(_ value: String) -> Self { teacher = value; return self }
    @discardableResult func type(_ value: LessonType) -> Self { type = value; return self }
    @discardableResult func room(_ value: String?) -> Self { room = value; return self }
    @discardableResult func link(_ value: String?) -> Self { link = value; return self }
    @discardableResult func start(_ value: LessonTime?) -> Self { startTime = value; return self }
    @discardableResult func elective(_ value: Bool = true) -> Self { isElective = value; return self }

    /// Позначає пару онлайн; якщо передано link, зберігає його.
    @discardableResult func online(link: String? = nil) -> Self {
        isOnline = true
        if let link { self.link = link }
        return self
    }

    func build() -> Lesson {
        Lesson(subjectName: subjectName, teacher: teacher, type: type,
               room: room, isOnline: isOnline, link: link, startTime: startTime, isElective: isElective)
    }
}
