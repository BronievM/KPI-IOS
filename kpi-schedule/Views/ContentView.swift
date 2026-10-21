//
//  ContentView.swift
//  kpi-schedule
//
//  Created by Maksym Broniev on 21.09.2026.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                weekPicker
                content
            }
            .navigationTitle("Schedule")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Picker("Filter", selection: $viewModel.filterOption) {
                        ForEach(FilterOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .onAppear { viewModel.load() }
        .onReceive(timer) { _ in viewModel.refreshNow() }
    }

    private var weekPicker: some View {
        VStack(spacing: 4) {
            Picker("Week", selection: $viewModel.selectedWeek) {
                Text("1 Week").tag(WeekType.first)
                Text("2 Week").tag(WeekType.second)
            }
            .pickerStyle(.segmented)

            Text("Current week: \(viewModel.currentWeek == .first ? "1" : "2")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        if let error = viewModel.errorMessage {
            Text(error)
                .foregroundColor(.red)
                .padding()
            Spacer()
        } else if viewModel.sections.isEmpty {
            Text("There are no items in the schedule")
                .foregroundColor(.secondary)
                .padding()
            Spacer()
        } else {
            List {
                ForEach(viewModel.sections) { section in
                    Section(header: sectionHeader(section)) {
                        ForEach(section.lessons, id: \.id) { lesson in
                            let isCurrent = (lesson.id == viewModel.currentLessonID)
                            LessonRowView(lesson: lesson, isCurrent: isCurrent) {
                                viewModel.open(lesson)
                            }
                            .listRowBackground(rowBackground(isCurrent: isCurrent))
                        }
                    }
                }
            }
            .listStyle(.grouped)
        }
    }

    private func sectionHeader(_ section: DaySection) -> some View {
        HStack(spacing: 8) {
            Text(section.title)
                .font(.title2)
                .fontWeight(.bold)
            if section.isToday {
                Text("Today")
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
