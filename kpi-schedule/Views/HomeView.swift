//
//  HomeView.swift
//  kpi-schedule
//
//  Created by Maksym on 25.10.2026.
//

import SwiftUI

/// Головний екран (центральна вкладка)
struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @ObservedObject var schedule: ScheduleViewModel
    @State private var showProfile = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    private let onOpenTask: (UUID) -> Void

    init(schedule: ScheduleViewModel, tasks: TaskRepository, onOpenTask: @escaping (UUID) -> Void) {
        self.onOpenTask = onOpenTask
        _schedule = ObservedObject(wrappedValue: schedule)
        _viewModel = StateObject(wrappedValue: HomeViewModel(schedule: schedule, tasks: tasks))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Головна") {
                Button { showProfile = true } label: {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Профіль")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    lessonCard
                    deadlinesCard
                    progressCard
                }
                .padding()
                .animation(reduceMotion ? nil : .snappy, value: viewModel.deadlines.map(\.id))
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear { viewModel.refresh() }
        .onReceive(timer) { _ in viewModel.refresh() }
        .sheet(isPresented: $showProfile) { ProfileView(viewModel: schedule) }
    }

    // MARK: пара

    @ViewBuilder
    private var lessonCard: some View {
        switch viewModel.lessonState {
        case .current(let lesson, let progress, let minutesLeft):
            card(title: "Зараз іде пара", symbol: "dot.radiowaves.left.and.right", tint: .accentColor) {
                lessonInfo(lesson)
                VStack(alignment: .leading, spacing: 6) {
                    ProgressBarView(progress: progress)
                    Text("Залишилось \(HomeViewModel.durationText(minutesLeft))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                joinButton(lesson)
            }
        case .upcoming(let lesson, let when):
            card(title: "Наступна пара · \(when)", symbol: "clock.fill", tint: .accentColor) {
                lessonInfo(lesson)
                joinButton(lesson)
            }
        case .none:
            card(title: "Пар поки немає", symbol: "cup.and.saucer.fill", tint: .secondary) {
                Text("Вихідний або вікно").font(.title3.weight(.semibold))
            }
        }
    }

    private func lessonInfo(_ lesson: Lesson) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(lesson.type.rawValue).font(.subheadline.weight(.semibold))
                Spacer()
                if let time = lesson.startTime {
                    Text(time.rangeText).font(.subheadline).monospacedDigit().foregroundColor(.secondary)
                }
            }
            Text(lesson.subjectName).font(.title3.bold())
            Text("Викладач: \(lesson.teacher)").font(.subheadline).foregroundColor(.secondary)
            Text(lesson.getLocation()).font(.caption).foregroundColor(.secondary)
        }
    }

    /// Кнопка «Приєднатися» (лише якщо в парі є лінк)
    @ViewBuilder
    private func joinButton(_ lesson: Lesson) -> some View {
        if lesson.link != nil {
            Button { viewModel.open(lesson) } label: {
                Label("Приєднатися", systemImage: "video.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: дедлайни та прогрес

    private var deadlinesCard: some View {
        card(title: "Гарячі дедлайни", symbol: "flame.fill", tint: .orange) {
            if viewModel.deadlines.isEmpty {
                Label("Гарячих дедлайнів немає", systemImage: "checkmark.circle")
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.deadlines) { item in
                    Button { onOpenTask(item.id) } label: {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).font(.headline)
                                Text(item.subject).font(.caption).foregroundColor(.secondary).lineLimit(2)
                            }
                            Spacer(minLength: 8)
                            Text(item.text)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(color(for: item))
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var progressCard: some View {
        card(title: "Прогрес завдань", symbol: "checklist", tint: .green) {
            HStack {
                Text("\(viewModel.progress.done) з \(viewModel.progress.total) виконано")
                    .font(.subheadline)
                    .contentTransition(.numericText())
                Spacer()
            }
            ProgressBarView(progress: viewModel.progress.fraction)
        }
    }

    // MARK: допоміжне

    private func card<Content: View>(title: String, symbol: String, tint: Color,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundColor(tint)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func color(for item: HotDeadline) -> Color {
        if item.urgency == .overdue || item.isToday { return .red }
        return item.urgency == .soon ? .orange : .secondary
    }
}

/// Профіль: тут живе вибір групи
struct ProfileView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Група", selection: $viewModel.selectedGroup) {
                        ForEach(viewModel.groups, id: \.self) { group in
                            Text(group).tag(group)
                        }
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text("Навчальна група")
                } footer: {
                    Text("Група визначає, який розклад показується на вкладках «Головна» і «Розклад».")
                }
            }
            .navigationTitle("Профіль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}
