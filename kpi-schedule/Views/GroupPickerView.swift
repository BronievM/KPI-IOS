//
//  GroupPickerView.swift
//  kpi-schedule
//
//  Created by Maksym on 06.11.2026.
//

import SwiftUI

/// Вибір групи серед усіх груп університету (пошук + розділи за факультетами)
struct GroupPickerView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var sections: [(faculty: String, groups: [CampusGroup])] {
        let found = GroupSearch.filter(viewModel.directory, query: query)
        let byFaculty = Dictionary(grouping: found, by: \.faculty)
        return byFaculty.keys.sorted().map { faculty in
            (faculty, (byFaculty[faculty] ?? []).sorted { $0.name < $1.name })
        }
    }

    var body: some View {
        List {
            if viewModel.isDirectoryLoading || viewModel.directoryError != nil {
                Section {
                    if viewModel.isDirectoryLoading {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Завантажую список груп…").foregroundColor(.secondary)
                        }
                    } else if let error = viewModel.directoryError {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Не вдалося завантажити список груп", systemImage: "wifi.exclamationmark")
                                .font(.subheadline.weight(.semibold))
                            Text(error).font(.footnote).foregroundColor(.secondary)
                            Button("Спробувати ще раз") {
                                Task { await viewModel.loadGroupDirectory(forceRefresh: true) }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            if sections.isEmpty {
                if !viewModel.directory.isEmpty {
                    Text("Нічого не знайдено").foregroundColor(.secondary)
                }
            } else {
                ForEach(sections, id: \.faculty) { section in
                    Section(section.faculty) {
                        ForEach(section.groups) { group in
                            row(group)
                        }
                    }
                }
            }
        }
        .navigationTitle("Група")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Назва групи або факультет")
        .autocorrectionDisabled()
        .textInputAutocapitalization(.characters)
        .task { await viewModel.loadGroupDirectory() }
        .refreshable { await viewModel.loadGroupDirectory(forceRefresh: true) }
    }

    private func row(_ group: CampusGroup) -> some View {
        Button {
            Task {
                await viewModel.chooseGroup(group)
            }
            dismiss()
        } label: {
            HStack {
                Text(group.name).foregroundColor(.primary)
                Spacer()
                if group.name == viewModel.selectedGroup {
                    Image(systemName: "checkmark").foregroundColor(.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
