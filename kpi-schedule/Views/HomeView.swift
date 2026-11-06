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
    private let onOpenSchedule: (Lesson) -> Void
    private let onOpenTasks: () -> Void

    init(schedule: ScheduleViewModel, tasks: TaskRepository, onOpenTask: @escaping (UUID) -> Void,         onOpenSchedule: @escaping (Lesson) -> Void = { _ in }, onOpenTasks: @escaping () -> Void = {}) {
        self.onOpenTask = onOpenTask
        self.onOpenSchedule = onOpenSchedule
        self.onOpenTasks = onOpenTasks
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
            .refreshable { await viewModel.reload() }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear { viewModel.refresh() }
        .onReceive(timer) { _ in viewModel.refresh() }
        .sheet(isPresented: $showProfile) { ProfileView(viewModel: schedule) }
    }

    // MARK: пара

    @ViewBuilder
    private var lessonCard: some View {
        if schedule.isLoading && !schedule.hasSchedule {
            card(title: "Розклад", symbol: "calendar", tint: .secondary) {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Завантажую розклад…").foregroundColor(.secondary)
                }
            }
        } else if let error = schedule.displayedError, !schedule.hasSchedule {
            card(title: "Розклад недоступний", symbol: "wifi.exclamationmark", tint: .orange) {
                Text(error).font(.subheadline).foregroundColor(.secondary)
                Button("Спробувати ще раз") { Task { await viewModel.reload() } }
                    .buttonStyle(.bordered)
            }
        } else {
            lessonStateCard
        }
    }

    @ViewBuilder
    private var lessonStateCard: some View {
        switch viewModel.lessonState {
        case .current(let lesson, let progress, let minutesLeft):
            card(title: "Зараз іде пара", symbol: "dot.radiowaves.left.and.right", tint: .accentColor) {
                lessonInfoButton(lesson)
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
                lessonInfoButton(lesson)
                joinButton(lesson)
            }
        case .none:
            card(title: "Пар поки немає", symbol: "cup.and.saucer.fill", tint: .secondary) {
                Text("Вихідний або вікно").font(.title3.weight(.semibold))
            }
        }
    }

    /// Тап по парі відкриває її в розкладі (кнопка «Назад» поверне на «Головну»)
    private func lessonInfoButton(_ lesson: Lesson) -> some View {
        Button { onOpenSchedule(lesson) } label: {
            HStack(alignment: .center, spacing: 8) {
                lessonInfo(lesson)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
            if !lesson.dates.isEmpty {
                Text("Спец. заняття").font(.caption.weight(.semibold)).foregroundColor(.accentColor)
            }
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
            Button(action: onOpenTasks) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("\(viewModel.progress.done) з \(viewModel.progress.total) виконано")
                            .font(.subheadline)
                            .contentTransition(.numericText())
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                    ProgressBarView(progress: viewModel.progress.fraction)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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

/// Профіль
struct ProfileView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        GroupPickerView(viewModel: viewModel)
                    } label: {
                        LabeledContent("Група", value: viewModel.selectedGroup)
                    }
                } header: {
                    Text("Навчальна група")
                } footer: {
                    if viewModel.directoryError != nil {
                        Label("Не вдалося завантажити список груп. Підключіться до інтернету й спробуйте ще раз.", systemImage: "wifi.slash")
                    } else {
                        Text("Група визначає, який розклад показується на вкладках «Головна» і «Розклад».")
                    }
                }

                Section {
                    if viewModel.subjectOptions.isEmpty {
                        Text("Предмети з'являться після завантаження розкладу")
                            .foregroundColor(.secondary)
                    } else {
                        NavigationLink {
                            ElectivesView(viewModel: viewModel)
                        } label: {
                            LabeledContent(
                                "Мої предмети",
                                value: "\(viewModel.subjectOptions.filter { viewModel.isSubjectEnabled($0.name) }.count) з \(viewModel.subjectOptions.count)"
                            )
                        }
                    }
                } header: {
                    Text("Вибіркові")
                } footer: {
                    if viewModel.displayedError != nil {
                        Label("Не вдалося оновити розклад. Показано збережений — підключіться до інтернету.", systemImage: "wifi.slash")
                    } else {
                        Text("Познач предмети, які ти відвідуєш. Решта не показуватимуться в розкладі.")
                    }
                }
            }
            .refreshable { await viewModel.reload() }
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
