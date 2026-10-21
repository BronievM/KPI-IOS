//
//  LessonFilterStrategy.swift
//  kpi-schedule
//
//  Created by Maksym on 20.10.2026.
//

import Foundation

// Strategy pattern for filtering lessons based on different criteria. Each filter strategy implements the `LessonFilterStrategy` protocol, which defines a method to apply the filter to a list of lessons.
protocol LessonFilterStrategy {
    var title: String { get }
    func apply(to lessons: [Lesson]) -> [Lesson]
}

struct AllLessonsFilter: LessonFilterStrategy {
    let title = "All Lessons"
    
    func apply(to lessons: [Lesson]) -> [Lesson] {
        lessons
    }
}

struct LessonTypeFilter: LessonFilterStrategy {
    let type: LessonType
    var title: String { type.rawValue }
    func apply(to lessons: [Lesson]) -> [Lesson] {
        lessons.filter { $0.type == type }
    }
}

struct OnlineLessonsFilter: LessonFilterStrategy {
    let title = "Online"
    func apply(to lessons: [Lesson]) -> [Lesson] { lessons.filter { $0.isOnline } }
}

enum FilterOption: String, CaseIterable, Identifiable {
    case all, lecture, practice, labs, online
    var id: String { rawValue }

    var strategy: LessonFilterStrategy {
        switch self {
        case .all:
            return AllLessonsFilter()
        case .lecture:
            return LessonTypeFilter(type: .lecture)
        case .practice:
            return LessonTypeFilter(type: .practice)
        case .labs:
            return LessonTypeFilter(type: .lab)
        case .online:
            return OnlineLessonsFilter()
        }
    }
}
