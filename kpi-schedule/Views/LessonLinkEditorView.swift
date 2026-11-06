//
//  LessonLinkEditorView.swift
//  kpi-schedule
//
//  Created by Maksym on 06.11.2026.
//

import SwiftUI
import UIKit

extension Lesson: Identifiable {}

/// Додати / змінити / видалити лінк на пару
struct LessonLinkEditorView: View {
    let lesson: Lesson
    /// Повертає текст помилки або nil, якщо збережено
    let onSave: (String) -> String?
    let onRemove: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var error: String?

    init(lesson: Lesson, onSave: @escaping (String) -> String?, onRemove: @escaping () -> Void) {
        self.lesson = lesson
        self.onSave = onSave
        self.onRemove = onRemove
        _text = State(initialValue: lesson.link ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://…", text: $text)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        if let pasted = UIPasteboard.general.string { text = pasted }
                    } label: {
                        Label("Вставити з буфера", systemImage: "doc.on.clipboard")
                    }
                    if let error {
                        Text(error).font(.footnote).foregroundColor(.red)
                    }
                } header: {
                    Text(lesson.subjectName)
                } footer: {
                    Text("Лінк діє на всі пари «\(lesson.type.rawValue)» з цього предмета. Зберігається на цьому пристрої.")
                }

                if lesson.link != nil {
                    Section {
                        Button("Видалити лінк", role: .destructive) {
                            onRemove()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Лінк на пару")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Зберегти") {
                        if let message = onSave(text) {
                            error = message
                        } else {
                            dismiss()
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
