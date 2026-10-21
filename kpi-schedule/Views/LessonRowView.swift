//
//  LessonRowView.swift
//  kpi-schedule
//
//  Created by Maksym on 20.10.2026.
//

import SwiftUI

struct LessonRowView: View {
    let lesson: Lesson
    let isCurrent: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
            Text(lesson.type.rawValue).font(.headline)
            Spacer()
            if let time = lesson.startTime {
                Text(time.rangeText).font(.subheadline).monospacedDigit().foregroundColor(.secondary)
            }            
            if isCurrent {
                Text("Now").font(.caption).fontWeight(.bold).padding(.horizontal, 8).padding(.vertical, 2).background(Capsule().fill(Color.accentColor)).foregroundColor(.white)
            }
            }
            Text(lesson.subjectName).font(.title3).fontWeight(.bold)
            Text("Teacher: \(lesson.teacher)").font(.subheadline).foregroundColor(.secondary)
            Text(lesson.getLocation()).font(.caption).foregroundColor(.gray)

            if lesson.link != nil { Image(systemName: "link").foregroundColor(.accentColor) }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)       
    }
}
