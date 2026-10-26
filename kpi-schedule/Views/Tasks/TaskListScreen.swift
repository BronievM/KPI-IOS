//
//  TaskListScreen.swift
//  kpi-schedule
//
//  Created by Maksym on 25.10.2026.
//

import SwiftUI

/// Головний екран списку завдань із загальним прогресом, фільтрами та пошуком
struct TaskListScreen: View {
    @ObservedObject var viewModel: TaskListViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Стан згорнутих секцій (UI-логіка, тому зберігається у View)
    @State private var collapsed: Set<String> = []
    /// ID завдання для підтвердження видалення при свайпі
    @State private var pendingDelete: UUID?

    private var animation: Animation? { reduceMotion ? nil : .snappy(duration: 0.3) }

    var body: some View {
        VStack(spacing: 0) {
            // «+» поруч із заголовком
            ScreenHeader(title: "Завдання") {
                Button(action: viewModel.addTapped) {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Створити завдання")
            }
            header
            content
        }
        // заголовок власний; назва потрібна для кнопки «Назад»
        .navigationTitle("Завдання")
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.selection, trigger: viewModel.overall.done)
        .confirmationDialog("Видалити завдання?",
                            isPresented: Binding(get: { pendingDelete != nil },
                                                 set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible,
                            presenting: pendingDelete) { id in
            Button("Видалити", role: .destructive) { viewModel.delete(id) }
            Button("Скасувати", role: .cancel) {}
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            SearchField(text: $viewModel.searchText, prompt: "Пошук завдань")

            OverallProgressView(progress: viewModel.overall)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "Усі", isSelected: viewModel.selectedSubject == nil) {
                        withAnimation(animation) { viewModel.selectedSubject = nil }
                    }
                    ForEach(viewModel.subjects, id: \.self) { subject in
                        // Повторний тап по активному фільтру скидає його
                        FilterChip(title: subject, isSelected: viewModel.selectedSubject == subject) {
                            withAnimation(animation) { viewModel.toggleSubject(subject) }
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            Toggle("Лише невиконані", isOn: $viewModel.onlyUnfinished.animation(animation))
                .font(.subheadline)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.overall.total == 0 {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "checklist")
                    .font(.largeTitle)
                    .symbolEffect(.pulse, options: .repeating)
                Text("Завдань поки немає")
                Button("Створити завдання", action: viewModel.addTapped)
                Spacer()
            }
            .foregroundColor(.secondary)
            .transition(.opacity)
        } else if viewModel.sections.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "magnifyingglass").font(.largeTitle)
                Text("За цим фільтром завдань немає")
                Spacer()
            }
            .foregroundColor(.secondary)
            .transition(.opacity)
        } else {
            List {
                ForEach(viewModel.sections) { section in
                    let isCollapsed = collapsed.contains(section.subject)
                    Section(header: SubjectHeaderView(section: section, isCollapsed: isCollapsed) {
                        withAnimation(animation) { toggleCollapsed(section.subject) }
                    }) {
                        if !isCollapsed {
                            ForEach(section.rows) { row in
                                Button { viewModel.select(row.id) } label: {
                                    TaskRowView(row: row)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .leading) {
                                    Button {
                                        withAnimation(animation) { viewModel.toggleDone(row.id) }
                                    } label: {
                                        Label(row.isDone ? "Скасувати" : "Виконати", systemImage: "checkmark")
                                    }
                                    .tint(.green)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) { pendingDelete = row.id } label: {
                                        Label("Видалити", systemImage: "trash")
                                    }
                                }
                                .contextMenu {
                                    Button {
                                        withAnimation(animation) { viewModel.toggleDone(row.id) }
                                    } label: {
                                        Label(row.isDone ? "Скасувати виконання" : "Виконати",
                                              systemImage: row.isDone ? "arrow.uturn.backward" : "checkmark.circle")
                                    }
                                    Button { viewModel.edit(row.id) } label: {
                                        Label("Змінити", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) { pendingDelete = row.id } label: {
                                        Label("Видалити", systemImage: "trash")
                                    }
                                } preview: {
                                    TaskPreviewCard(row: row)
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollDismissesKeyboard(.interactively)
            .animation(animation, value: viewModel.sections)
            .transition(.opacity)
        }
    }

    private func toggleCollapsed(_ subject: String) {
        if collapsed.contains(subject) { collapsed.remove(subject) } else { collapsed.insert(subject) }
    }
}
