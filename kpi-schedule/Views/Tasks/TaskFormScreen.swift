//
//  TaskFormScreen.swift
//  kpi-schedule
//
//  Created by Maksym on 25.10.2026.
//

import SwiftUI
import UniformTypeIdentifiers

/// Екран створення та редагування завдання (показується модально)
struct TaskFormScreen: View {
    @StateObject private var viewModel: TaskFormViewModel
    @FocusState private var focusedField: Field?
    @State private var showFileImporter = false

    private enum Field { case title, customSubject, link, note }

    init(viewModel: @autoclosure @escaping () -> TaskFormViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Завдання") {
                    TextField("Назва, напр. ЛАБ5", text: $viewModel.title)
                        .focused($focusedField, equals: .title)
                        .submitLabel(.next)
                        .onSubmit { focusedField = viewModel.isCustomSubject ? .customSubject : .link }

                    // довгі назви предметів переносяться на кілька рядків
                    Menu {
                        Picker("Предмет", selection: $viewModel.subjectSelection) {
                            ForEach(viewModel.availableSubjects, id: \.self) { subject in
                                Text(subject).tag(subject)
                            }
                            Text("Новий предмет…").tag(TaskFormViewModel.customOption)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Предмет").font(.caption).foregroundColor(.secondary)
                                Text(viewModel.isCustomSubject ? "Новий предмет…" : viewModel.subjectSelection)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                    }

                    if viewModel.isCustomSubject {
                        TextField("Назва предмета", text: $viewModel.customSubject)
                            .focused($focusedField, equals: .customSubject)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .link }
                    }
                }

                Section("Дедлайн") {
                    // швидкий вибір дедлайну
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(DeadlinePreset.allCases, id: \.self) { preset in
                                FilterChip(title: preset.title, isSelected: viewModel.selectedPreset == preset) {
                                    focusedField = nil
                                    withAnimation { viewModel.select(preset) }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))

                    if viewModel.hasDeadline {
                        DatePicker("Своя дата й час", selection: $viewModel.deadline)
                    }
                }

                Section("Матеріали") {
                    TextField("Матеріали (URL), необов'язково", text: $viewModel.link)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .link)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .note }

                    ForEach(viewModel.attachments) { attachment in
                        HStack {
                            Label(attachment.fileName, systemImage: "paperclip")
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button {
                                withAnimation { viewModel.removeAttachment(attachment) }
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Прибрати файл \(attachment.fileName)")
                        }
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                    }

                    Button {
                        focusedField = nil
                        showFileImporter = true
                    } label: {
                        Label("Прикріпити файл", systemImage: "paperclip.badge.ellipsis")
                    }
                }

                Section("Нотатка") {
                    TextField("Нотатка (необов'язково)", text: $viewModel.note, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($focusedField, equals: .note)
                }

                if let message = viewModel.validationMessage {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                    .transition(.opacity)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .animation(.easeInOut(duration: 0.2), value: viewModel.validationMessage)
            .fileImporter(isPresented: $showFileImporter,
                          allowedContentTypes: [.item],
                          allowsMultipleSelection: true) { result in
                viewModel.addAttachments(from: result)
            }
            .alert("Помилка",
                   isPresented: Binding(get: { viewModel.attachmentError != nil },
                                        set: { if !$0 { viewModel.attachmentError = nil } })) {
                Button("Гаразд", role: .cancel) {}
            } message: {
                Text(viewModel.attachmentError ?? "")
            }
            .navigationTitle(viewModel.isEditing ? "Редагування" : "Нове завдання")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати", action: viewModel.cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Зберегти", action: viewModel.save)
                        .disabled(!viewModel.canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") { focusedField = nil }
                }
            }
            .onAppear {
                if !viewModel.isEditing { focusedField = .title }
            }
        }
    }
}
