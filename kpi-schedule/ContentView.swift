//
//  ContentView.swift
//  kpi-schedule
//
//  Created by Maksym Broniev on 21.09.2026.
//

import SwiftUI

struct ContentView: View {
    let weeklySchedule: [DailySchedule]
    
    @Environment(\.openURL) var openURL
    
    var body: some View {
        NavigationView {
            List {
                ForEach(weeklySchedule, id: \.dayOfWeek) { day in
                    Section(header: Text(day.dayOfWeek).font(.title2).fontWeight(.bold)) {
                        ForEach(day.lessons, id: \.id) { lesson in
                            LessonRowView(lesson: lesson, openURL: openURL)
                        }
                    }
                }
            }
            .listStyle(.grouped)
            .navigationTitle("Schedule for IO-4x")
        }
    }
}

struct LessonRowView: View {
    let lesson: Lesson
    let openURL: OpenURLAction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(lesson.type.rawValue).font(.headline)
            Text(lesson.subjectName).font(.title3).fontWeight(.bold)
            
            Text("Teacher: \(lesson.teacher)").font(.subheadline).foregroundColor(.secondary)
            Text(lesson.getLocation()).font(.caption).foregroundColor(.gray)
           
            if lesson.link != nil {
                Image(systemName: "link")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            if let link = lesson.link, let url = URL(string: link) {
                openURL(url)
            }
        }
    }
}
