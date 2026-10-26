//
//  LessonRowView.swift
//  kpi-schedule
//
//  Created by Maksym on 21.10.2026.
//  Updated by Maksym on 25.10.2026.
//

import SwiftUI
import UIKit

/// Картка пари з лінією часу зліва; крапка пульсує, поки йде пара
struct LessonRowView: View {
    let lesson: Lesson
    let isCurrent: Bool
    let onTap: () -> Void
    /// Дія «Фільтрувати за цим предметом» у контекстному меню (nil = пункту немає)
    var onFilterSubject: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            timeline
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(lesson.type.rawValue).font(.headline)
                    Spacer()
                    if let time = lesson.startTime {
                        Text(time.rangeText)
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                    if isCurrent {
                        Text("Зараз")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.accentColor))
                            .foregroundColor(.white)
                    }
                }
                Text(lesson.subjectName).font(.title3).fontWeight(.bold)
                Text("Викладач: \(lesson.teacher)").font(.subheadline).foregroundColor(.secondary)
                locationRow
            }
            .padding(.vertical, 12)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .contextMenu {
            if let link = lesson.link {
                Button { UIPasteboard.general.string = link } label: {
                    Label("Скопіювати лінк", systemImage: "link")
                }
            }
            Button { UIPasteboard.general.string = lesson.teacher } label: {
                Label("Скопіювати ім'я викладача", systemImage: "person")
            }
            if let onFilterSubject {
                Button(action: onFilterSubject) {
                    Label("Фільтрувати за цим предметом", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
    }

    // MARK: лінія часу

    private var timeline: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 2)
            Circle()
                .fill(isCurrent ? Color.accentColor : Color.secondary.opacity(0.6))
                .frame(width: 10, height: 10)
                .overlay(
                    // хвиля навколо крапки, коли пара йде зараз
                    Circle()
                        .stroke(Color.accentColor.opacity(0.6), lineWidth: 2)
                        .scaleEffect(pulse ? 2.4 : 1)
                        .opacity(isCurrent ? (pulse ? 0 : 0.8) : 0)
                )
                .padding(.top, 18)
        }
        .frame(width: 12)
        // initial: true, щоб спрацювало і при появі рядка
        .onChange(of: isCurrent, initial: true) { _, current in
            if current && !reduceMotion {
                withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) { pulse = true }
            } else {
                withAnimation(nil) { pulse = false }
            }
        }
    }

    // MARK: онлайн / аудиторія

    /// «Онлайн» або аудиторія, а поруч іконка лінка (якщо він є)
    private var locationRow: some View {
        HStack(spacing: 6) {
            Text(lesson.getLocation()).font(.caption).foregroundColor(.gray)
            if lesson.link != nil {
                Image(systemName: "link").font(.caption).foregroundColor(.accentColor)
            }
        }
    }
}
