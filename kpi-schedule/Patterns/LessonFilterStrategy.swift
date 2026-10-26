//
//  LessonFilterStrategy.swift
//  kpi-schedule
//
//  Created by Maksym on 21.10.2026.
//  Updated by Maksym on 25.10.2026.
//

import Foundation

/// PATTERN: Strategy.
/// Змінює правило відбору пар у рантаймі без if/switch у ViewModel.
protocol LessonFilterStrategy {
    var title: String { get }
    func apply(to lessons: [Lesson]) -> [Lesson]
}

struct AllLessonsFilter: LessonFilterStrategy {
    let title = "Усі"
    func apply(to lessons: [Lesson]) -> [Lesson] { lessons }
}

struct LessonTypeFilter: LessonFilterStrategy {
    let type: LessonType
    var title: String { type.rawValue }
    func apply(to lessons: [Lesson]) -> [Lesson] { lessons.filter { $0.type == type } }
}

struct OnlineLessonsFilter: LessonFilterStrategy {
    let title = "Онлайн"
    func apply(to lessons: [Lesson]) -> [Lesson] { lessons.filter { $0.isOnline } }
}

struct SubjectFilter: LessonFilterStrategy {
    let subjectName: String
    var title: String { subjectName }
    func apply(to lessons: [Lesson]) -> [Lesson] {
        var result: [Lesson] = []
        for lesson in lessons {
            if lesson.subjectName == subjectName {
                result.append(lesson)
            }
        }
        return result
    }
}


/// Варіанти для Picker у UI; кожен відповідає своїй стратегії.
enum FilterOption: String, CaseIterable, Identifiable {
    case all = "Усі"
    case lectures = "Лекції"
    case practices = "Практики"
    case labs = "Лабораторні"
    case online = "Онлайн"
    
    var id: String { rawValue }
    
    var strategy: LessonFilterStrategy {
        switch self {
        case .all:       return AllLessonsFilter()
        case .lectures:  return LessonTypeFilter(type: .lecture)
        case .practices: return LessonTypeFilter(type: .practice)
        case .labs:      return LessonTypeFilter(type: .lab)
        case .online:    return OnlineLessonsFilter()
        }
    }
}
