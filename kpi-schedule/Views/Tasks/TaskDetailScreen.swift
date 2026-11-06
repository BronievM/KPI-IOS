//
//  TaskDetailScreen.swift
//  kpi-schedule
//
//  Created by Maksym on 25.10.2026.
//

import SwiftUI
import QuickLook

/// Екран деталей завдання
struct TaskDetailScreen: View {
    @StateObject private var viewModel: TaskDetailViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale

    /// @autoclosure запобігає зайвому перестворенню ViewModel при оновленні батьківського View.
    private let backTitle: String?
    private let onBack: (() -> Void)?

    init(viewModel: @autoclosure @escaping () -> TaskDetailViewModel,
         backTitle: String? = nil, onBack: (() -> Void)? = nil) {
        self.backTitle = backTitle
        self.onBack = onBack
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        Group {
            if let task = viewModel.task {
                content(for: task)
            } else {
                Text("Завдання не знайдено").foregroundColor(.secondary)
            }
        }
        .navigationTitle("Завдання")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(onBack != nil)
        .toolbar {
            if let onBack {
                // замість стандартної «‹ Завдання»: веде на вкладку, звідки відкрили
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").fontWeight(.semibold)
                            Text(backTitle ?? "Назад")
                        }
                    }
                }
            }
            
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if let text = viewModel.shareText {
                    ShareLink(item: text)       // поділитися завданням
                }
                Button( action: viewModel.editTapped) {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Змінити")
                .disabled(viewModel.task == nil)
            }
        }
        // вібрація, лише коли завдання стало виконаним
        .sensoryFeedback(trigger: viewModel.task?.isDone) { (_: Bool?, isDone: Bool?) -> SensoryFeedback? in
            isDone == true ? SensoryFeedback.impact(weight: .medium) : nil
        }
        .quickLookPreview($viewModel.previewURL)
        .confirmationDialog("Видалити завдання?", isPresented: $viewModel.showDeleteConfirmation, titleVisibility: .visible) {
            Button("Видалити", role: .destructive, action: viewModel.deleteConfirmed)
            Button("Скасувати", role: .cancel) {}
        }
    }

    private func content(for task: StudyTask) -> some View {
        let animation: Animation? = reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.75)

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        // тап по кружечку перемикає виконання
                        Button {
                            withAnimation(animation) { viewModel.toggleDone() }
                        } label: {
                            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                .font(.title)
                                .foregroundColor(task.isDone ? .green : .secondary)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(task.isDone ? "Скасувати виконання" : "Позначити виконаним")

                        Text(task.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .strikethrough(task.isDone)
                    }

                    Button(action: viewModel.showInSchedule) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: "book").frame(width: 22)
                            Text(task.subject).multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right").font(.caption)
                        }
                        .font(.headline)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                if let info = viewModel.deadlineInfo {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(color(for: info.urgency))
                            .frame(width: 22)
                        // «Дедлайн: 23 жовтня о 03:57 · прострочено на 2 дні»
                        deadlineLine(task: task, info: info)
                    }
                    .font(.subheadline)
                }

                if let link = task.link {
                        Button(action: viewModel.openLink) {
                            VStack(spacing: 4) {
                                Label("Матеріали (URL)", systemImage: "link")
                                    .frame(maxWidth: .infinity)
                                
                                Text(link)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .frame(maxWidth: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/)
                            .padding()
                            .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 12 ))
                    }
                        .buttonStyle(.plain)
                }

                if !task.attachments.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Файли").font(.headline)
                        ForEach(task.attachments) { attachment in
                            Button { viewModel.open(attachment) } label: {
                                Label(attachment.fileName, systemImage: "paperclip")
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .transition(.opacity)
                }

                if !task.note.isEmpty {
                    Text(task.note)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    withAnimation(animation) { viewModel.toggleDone() }
                } label: {
                    Label(task.isDone ? "Скасувати виконання" : "Виконати",
                          systemImage: task.isDone ? "arrow.uturn.backward" : "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(task.isDone ? .primary : .white)
                        .background(task.isDone ? Color.secondary.opacity(0.2) : Color.green,
                                    in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .symbolEffect(.bounce, value: task.isDone)

                Button(role: .destructive, action: viewModel.deleteTapped) {
                    Label("Видалити завдання", systemImage: "trash")
                }
                .padding(.top, 8)
            }
            .padding()
            .animation(animation, value: task.isDone)
        }
    }

    private func deadlineLine(task: StudyTask, info: DeadlineInfo) -> Text {
        let label = Text("Дедлайн: ").fontWeight(.semibold)
        guard let deadline = task.deadline else { return label + Text(info.text) }
        let remaining = Text(info.text).foregroundColor(color(for: info.urgency))
        return label + Text(deadlineText(deadline) + ", ") + remaining
    }

    /// «23 жовтня»: рік показуємо, лише якщо він не поточний, час — лише якщо не 23:59
    private func deadlineText(_ date: Date) -> String {
        let calendar = Calendar.current
        var style = Date.FormatStyle().day().month(.wide)
        if !calendar.isDate(date, equalTo: Date(), toGranularity: .year) { style = style.year() }
        let time = calendar.dateComponents([.hour, .minute], from: date)
        if !(time.hour == 23 && time.minute == 59) { style = style.hour().minute() }
        return date.formatted(style.locale(locale))
    }

    private func color(for urgency: DeadlineUrgency) -> Color {
        switch urgency {
        case .overdue: return .red
        case .soon:    return .orange
        case .normal, .none: return .secondary
        }
    }
}
