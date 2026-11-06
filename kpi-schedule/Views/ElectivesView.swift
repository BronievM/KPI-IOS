//
//  ElectivesView.swift
//  kpi-schedule
//
//  Created by Maksym on 06.11.2026.
//

import SwiftUI

/// «Мої предмети» - студент відмічає, які предмети відвідує (вибіркові та нормативні)
/// Розклад і «Головна» показують лише відмічені

struct ElectivesView: View {
    @ObservedObject var viewModel: ScheduleViewModel

    var body: some View {
        List {
            let likely = viewModel.subjectOptions.filter { $0.likelyElective }
            let regular = viewModel.subjectOptions.filter { !$0.likelyElective }

            if !likely.isEmpty {
                Section("Імовірно вибіркові") {
                    rows(likely)
                }
            }

            if !regular.isEmpty {
                Section {
                    rows(regular)
                } header: {
                    Text("Нормативні")
                } footer: {
                    Text("Нормативні предмети, найімовірніше, обов'язкові, але ти можеш прибрати будь-який. Відмічені показуються в розкладі та на головній. Вибір зберігається на цьому пристрої окремо для кожної групи.")
                }
            }
        }
        .navigationTitle("Мої предмети")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Вибрати всі") { viewModel.enableAllSubjects() }
                    Button("Зняти всі") {
                        for option in viewModel.subjectOptions {
                            viewModel.setSubject(option.name, enabled: false)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    @ViewBuilder
    private func rows(_ options: [ElectiveOption]) -> some View {
        ForEach(options) { option in
            let isEnabled = viewModel.isSubjectEnabled(option.name)
            Button {
                viewModel.setSubject(option.name, enabled: !isEnabled)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundColor(isEnabled ? .accentColor : .secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(option.name).foregroundColor(.primary)
                        if !option.teachers.isEmpty {
                            Text(option.teachers.joined(separator: ", "))
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isEnabled ? .isSelected : [])
        }
    }
}
