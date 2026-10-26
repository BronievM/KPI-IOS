//
//  ContentView.swift
//  kpi-schedule
//
//  Created by Maksym on 21.10.2026.
//  Updated by Maksym on 25.10.2026.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Змінюється, коли користувач перемикає тиждень / фільтр / предмет
    private var contentKey: String {
        "\(viewModel.selectedWeek.rawValue)|\(viewModel.filterOption.rawValue)|\(viewModel.subjectFilter ?? "")"
    }

    private var animation: Animation? { reduceMotion ? nil : .easeInOut(duration: 0.25) }

    var body: some View {
        VStack(spacing: 0) {
            // вибір групи перенесено в «Профіль»
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
        if let error = viewModel.errorMessage {
            Text(error)
                .foregroundColor(.red)
                .padding()
            Spacer()
        } else if viewModel.sections.isEmpty {
            emptyState
        } else {
            List {
                ForEach(viewModel.sections) { section in
                    Section(header: sectionHeader(section)) {
                        ForEach(section.lessons, id: \.id) { lesson in
                            let isCurrent = (lesson.id == viewModel.currentLessonID)
                            LessonRowView(lesson: lesson, isCurrent: isCurrent, onTap: {
                                viewModel.open(lesson)
                            }, onFilterSubject: {
                                withAnimation(animation) { viewModel.filterBySubject(lesson.subjectName) }
                            })
                            .listRowBackground(rowBackground(isCurrent: isCurrent))
                            // без відступів і роздільників, щоб лінія часу не переривалась
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                    }
                }
            }
            .listStyle(.grouped)
        }
    }

    /// Порожній стан
    private var emptyState: some View {
        let isFiltered = viewModel.subjectFilter != nil || viewModel.filterOption != .all
        return VStack(spacing: 12) {
            Spacer()
            Image(systemName: isFiltered ? "magnifyingglass" : "cup.and.saucer.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor.opacity(0.55))
                .symbolEffect(.pulse, options: .repeating)
            Text(isFiltered ? "За цим фільтром пар немає" : "Вихідний або вікно")
                .font(.title3.weight(.semibold))
            Text(isFiltered ? "Змініть або скиньте фільтр" : "У цей тиждень пар немає, відпочиньте")
                .font(.subheadline)
                .foregroundColor(.secondary)
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

    private func rowBackground(isCurrent: Bool) -> Color? {
        isCurrent ? Color.accentColor.opacity(0.18) : nil
    }
}
