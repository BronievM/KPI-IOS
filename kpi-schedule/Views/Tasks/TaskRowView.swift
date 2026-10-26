//
//  TaskRowView.swift
//  kpi-schedule
//
//  Created by Maksym on 25.10.2026.
//

import SwiftUI

struct TaskRowView: View {
    let row: TaskRowModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: row.isDone ? "checkmark.circle.fill" : "circle.fill")
                .font(.body)
                .foregroundColor(row.isDone ? .green : .red)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: row.isDone)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(.headline)
                    .strikethrough(row.isDone)
                    .foregroundColor(row.isDone ? .secondary : .primary)
                Text(row.deadlineText)
                    .font(.caption)
                    .foregroundColor(deadlineColor)
            }
            Spacer()
            if row.hasAttachments {
                Image(systemName: "paperclip").foregroundColor(.secondary)
            }
            if row.hasLink {
                Image(systemName: "link").foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(row.isDone ? "виконано" : "не виконано")
    }

    /// Сірий: звичайний; помаранчевий: ≤ 3 днів; червоний: сьогодні або прострочено
    private var deadlineColor: Color {
        if row.urgency == .overdue || row.isDueToday { return .red }
        return row.urgency == .soon ? .orange : .secondary
    }
}
