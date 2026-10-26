//
//  TaskListComponents.swift
//  kpi-schedule
//
//  Created by Maksym on 25.10.2026.
//

import SwiftUI

/// Віджет загального прогресу завдань
struct OverallProgressView: View {
    let progress: TaskProgress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isAllDone: Bool { progress.total > 0 && progress.done == progress.total }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Загальний прогрес")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(progress.done) з \(progress.total)")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                    .contentTransition(.numericText())
            }
            ProgressBarView(progress: progress.fraction)

            if isAllDone {
                Label("Усе виконано!", systemImage: "party.popper.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.green)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .snappy, value: progress)
        .accessibilityElement(children: .combine)
    }
}

/// Кнопка-фільтр за предметом
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.15)))
                .foregroundColor(isSelected ? .white : .primary)
                .scaleEffect(isSelected && !reduceMotion ? 1.04 : 1)
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Заголовок групи завдань із прогрес-баром та кнопкою розгортання
struct SubjectHeaderView: View {
    let section: SubjectSectionModel
    var isCollapsed: Bool = false
    var onToggle: (() -> Void)? = nil

    var body: some View {
        Button { onToggle?() } label: {
            // назва на всю ширину, прогрес під нею
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                        .frame(width: 12)
                    Text(section.subject)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                HStack(spacing: 8) {
                    ProgressBarView(progress: section.progress.fraction)
                        .frame(maxWidth: 160)
                    Text("\(section.progress.done)/\(section.progress.total)")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                        .contentTransition(.numericText())
                }
                .padding(.leading, 20)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .textCase(nil)
        .accessibilityElement(children: .combine)
        .accessibilityHint(isCollapsed ? "Розгорнути предмет" : "Згорнути предмет")
    }
}

/// Рядок пошуку (власний, бо `.searchable` не підходить до власного заголовка)
struct SearchField: View {
    @Binding var text: String
    let prompt: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField(prompt, text: $text)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Очистити пошук")
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// Превʼю завдання при довгому натисканні
struct TaskPreviewCard: View {
    let row: TaskRowModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: row.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(row.isDone ? .green : .secondary)
                Text(row.title).font(.title2.bold()).strikethrough(row.isDone)
            }
            Text(row.subject).font(.subheadline).foregroundColor(.secondary)
            Label(row.deadlineText, systemImage: "flame.fill")
                .font(.subheadline)
                .foregroundColor(row.urgency == .overdue || row.isDueToday ? .red : (row.urgency == .soon ? .orange : .secondary))
            if !row.note.isEmpty {
                Text(row.note).font(.footnote).lineLimit(6)
            }
            if row.hasLink || row.hasAttachments {
                HStack(spacing: 12) {
                    if row.hasLink { Label("Матеріали (URL)", systemImage: "link") }
                    if row.hasAttachments { Label("Файли", systemImage: "paperclip") }
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
        }
        .padding()
        .frame(width: 300, alignment: .leading)
    }
}
