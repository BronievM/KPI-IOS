//
//  ContentView.swift
//  kpi-schedule
//
//  Created by Maksym on 21.10.2026.
//  Updated by Maksym on 06.11.2026.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Пара, для якої відкрито редактор лінка
    @State private var editingLesson: Lesson?

    /// Змінюється, коли користувач перемикає тиждень / фільтр / предмет
    private var contentKey: String {
        "\(viewModel.selectedWeek.rawValue)|\(viewModel.filterOption.rawValue)|\(viewModel.subjectFilter ?? "")"
    }

    private var animation: Animation? { reduceMotion ? nil : .easeInOut(duration: 0.25) }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Розклад") {
                Menu {
                    Picker("Фільтр", selection: $viewModel.filterOption) {
                        ForEach(FilterOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.filterOption.rawValue)
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .font(.body)
                }
            }
            weekPicker
            subjectBanner
            content
                .animation(animation, value: contentKey)
        }
        .onAppear { viewModel.load() }
        .onReceive(timer) { _ in viewModel.refreshNow() }
        .sheet(item: $editingLesson) { lesson in
            LessonLinkEditorView(
                lesson: lesson,
                onSave: { viewModel.setLink($0, for: lesson) },
                onRemove: { viewModel.removeLink(for: lesson) })
        }
    }

    private func retry() {
        Task { await viewModel.reload() }
    }

    /// Є лінк - відкриваємо. Немає - пропонуємо додати (лінки зберігаються локально)
    private func handleTap(_ lesson: Lesson) {
        if lesson.link != nil { viewModel.open(lesson) } else { editingLesson = lesson }
    }

    // MARK: тиждень

    private var weekPicker: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                weekButton(.first, title: "1 тиждень")
                weekButton(.second, title: "2 тиждень")
            }
            .padding(3)
            .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))

            Text("\(viewModel.selectedGroup) · поточний тиждень: \(viewModel.currentWeek == .first ? "1" : "2")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    /// Вибір тижня: поточний тиждень виділено акцентним кольором
    private func weekButton(_ week: WeekType, title: String) -> some View {
        let isSelected = viewModel.selectedWeek == week
        let isCurrent = viewModel.currentWeek == week
        return Button {
            withAnimation(animation) { viewModel.selectedWeek = week }
        } label: {
            HStack(spacing: 6) {
                if isCurrent { Circle().fill(Color.accentColor).frame(width: 6, height: 6) }
                Text(title)
            }
            .font(.subheadline.weight(isSelected ? .semibold : .regular))
            .foregroundColor(isCurrent ? .accentColor : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(isSelected ? Color(.systemBackground) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(isSelected ? 0.08 : 0), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isCurrent ? "Поточний тиждень" : "")
    }

    /// Показує, що розклад відфільтровано за предметом
    @ViewBuilder
    private var subjectBanner: some View {
        if let subject = viewModel.subjectFilter {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                Text(subject).lineLimit(1)
                Spacer()
                Button("Скинути") {
                    withAnimation(animation) { viewModel.clearSubjectFilter() }
                }
            }
            .font(.footnote)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.accentColor.opacity(0.12))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: вміст

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && !viewModel.hasSchedule {
            loadingState
        } else if let error = viewModel.displayedError, !viewModel.hasSchedule {
            errorState(error)
        } else if viewModel.sections.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                // оновлення не вдалося, але є збережений розклад
                if let error = viewModel.displayedError { staleBanner(error) }
                lessonList
            }
        }
    }

    private var lessonList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(viewModel.sections) { section in
                    Section(header: sectionHeader(section)) {
                        ForEach(section.lessons, id: \.id) { lesson in
                            lessonRow(lesson, in: section)
                        }
                    }
                }
            }
            .listStyle(.grouped)
            .refreshable { await viewModel.reload() }
            .animation(.easeInOut(duration: 0.4), value: viewModel.highlightedLessonID)
            .onAppear { scrollToFocused(proxy) }
            .onChange(of: viewModel.focusedLessonID) { _, _ in scrollToFocused(proxy) }
        }
    }

    @ViewBuilder
    private func lessonRow(_ lesson: Lesson, in section: DaySection) -> some View {
        let isCurrent = lesson.id == viewModel.currentLessonID
        let isHighlighted = lesson.id == viewModel.highlightedLessonID
        
        LessonRowView(lesson: lesson, isCurrent: isCurrent, onTap: {
            handleTap(lesson)
        }, onFilterSubject: {
            withAnimation(animation) { viewModel.filterBySubject(lesson.subjectName) }
        }, onEditLink: {
            editingLesson = lesson
        }, dateKey: section.dateKey)
        .listRowBackground(rowBackground(isCurrent: isCurrent, isHighlighted: isHighlighted))
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .listRowSeparator(.hidden)
    }
    
    /// Після переходу з «Головної» прокручуємо до потрібної пари
    private func scrollToFocused(_ proxy: ScrollViewProxy) {
        guard  viewModel.focusedLessonID != nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard let id = viewModel.focusedLessonID else {return}
            withAnimation(animation) { proxy.scrollTo(id, anchor: .center)
                viewModel.endFocus()
            }
        }
    }


    // MARK: стани екрана

    private var loadingState: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
            Text("Завантажую розклад…").font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Не вдалося завантажити розклад").font(.title3.weight(.semibold))
            Text(message).font(.subheadline).foregroundColor(.secondary)
            Button("Спробувати ще раз", action: retry)
                .buttonStyle(.borderedProminent)
            Spacer()
            Spacer()
        }
        .multilineTextAlignment(.center)
        .padding()
        .frame(maxWidth: .infinity)
    }

    private func staleBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
            Text("Показано збережений розклад. \(message)").lineLimit(2)
            Spacer(minLength: 4)
            Button("Повторити", action: retry)
        }
        .font(.footnote)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.15))
    }

    /// Порожній стан
    private var emptyState: some View {
        let isFiltered = viewModel.subjectFilter != nil || viewModel.filterOption != .all
        let hiddenAll = viewModel.allSubjectsHidden
        let icon = hiddenAll ? "eye.slash" : (isFiltered ? "magnifyingglass" : "cup.and.saucer.fill")
        let title = hiddenAll ? "Усі предмети вимкнено"
            : (isFiltered ? "За цим фільтром пар немає"
               : (viewModel.hasSchedule ? "Вихідний або вікно" : "Розклад порожній"))
        let subtitle = hiddenAll ? "Увімкніть потрібні: Головна → Профіль → Мої предмети"
            : (isFiltered ? "Змініть або скиньте фільтр"
               : (viewModel.hasSchedule ? "У цей тиждень пар немає, відпочиньте"
                  : "Сервер не повернув пар для групи \(viewModel.selectedGroup)"))
        return VStack(spacing: 12) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor.opacity(0.55))
                .symbolEffect(.pulse, options: .repeating)
            Text(title).font(.title3.weight(.semibold))
            Text(subtitle).font(.subheadline).foregroundColor(.secondary)
            if !isFiltered && !hiddenAll {
                Button("Оновити", action: retry).buttonStyle(.bordered)
            }
            Spacer()
            Spacer()
        }
        .multilineTextAlignment(.center)
        .padding()
        .frame(maxWidth: .infinity)
        .transition(.opacity)
    }

    private func sectionHeader(_ section: DaySection) -> some View {
        HStack(spacing: 8) {
            Text(Weekday(name: section.title)?.localizedName ?? section.title)
                .font(.title2)
                .fontWeight(.bold)
            if section.isToday {
                Text("Сьогодні")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor))
                    .foregroundColor(.white)
            }
        }
        .textCase(nil)
    }

    private func rowBackground(isCurrent: Bool, isHighlighted: Bool) -> Color? {
        if isHighlighted { return Color.accentColor.opacity(0.4) }
        return isCurrent ? Color.accentColor.opacity(0.18) : nil
    }
}
