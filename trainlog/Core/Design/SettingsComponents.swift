//
//  SettingsComponents.swift
//  TrainLog
//

import SwiftUI
import UIKit

// MARK: - Стиль инпута (как в «Сменить пароль»): скруглённый фон и обводка

extension View {
    /// Фон tertiarySystemFill, скругление 10 pt, тонкая обводка. Использовать для TextField вместо .textFieldStyle(.roundedBorder).
    func formInputStyle() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppColors.tertiarySystemFill, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(AppColors.separator.opacity(0.5), lineWidth: 0.5)
            )
    }

    /// Универсальный подтверждающий диалог (кастомный единый стиль для действий с подтверждением).
    func appConfirmationDialog(
        title: String,
        message: String,
        isPresented: Binding<Bool>,
        confirmTitle: String,
        confirmRole: ButtonRole? = nil,
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) -> some View {
        modifier(
            AppConfirmationDialogModifier(
                title: title,
                message: message,
                isPresented: isPresented,
                confirmTitle: confirmTitle,
                confirmRole: confirmRole,
                onConfirm: onConfirm,
                onCancel: onCancel
            )
        )
    }

    /// Единый диалог архивирования/возврата из архива.
    func archiveToggleConfirmationDialog(
        isPresented: Binding<Bool>,
        isArchived: Bool,
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) -> some View {
        appConfirmationDialog(
            title: isArchived ? "Вернуть из архива?" : "В архив?",
            message: isArchived ? "Вернуть клиента в активные?" : "Клиент перестал заниматься — переместить в архив?",
            isPresented: isPresented,
            confirmTitle: isArchived ? "Вернуть" : "В архив",
            confirmRole: isArchived ? nil : .destructive,
            onConfirm: onConfirm,
            onCancel: onCancel
        )
    }
}

private struct AppConfirmationDialogModifier: ViewModifier {
    let title: String
    let message: String
    @Binding var isPresented: Bool
    let confirmTitle: String
    let confirmRole: ButtonRole?
    let onConfirm: () -> Void
    let onCancel: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .disabled(isPresented)
            .onChange(of: isPresented) { _, newValue in
                if newValue {
                    AppConfirmationDialogPresenter.shared.present(
                        title: title,
                        message: message,
                        confirmTitle: confirmTitle,
                        confirmRole: confirmRole,
                        isPresented: $isPresented,
                        onConfirm: onConfirm,
                        onCancel: onCancel
                    )
                } else {
                    AppConfirmationDialogPresenter.shared.dismiss()
                }
            }
            .onAppear {
                if isPresented {
                    AppConfirmationDialogPresenter.shared.present(
                        title: title,
                        message: message,
                        confirmTitle: confirmTitle,
                        confirmRole: confirmRole,
                        isPresented: $isPresented,
                        onConfirm: onConfirm,
                        onCancel: onCancel
                    )
                }
            }
    }
}

/// Карточка настроек: светлая подложка, скругления, внутренние отступы.
struct SettingsCard<Content: View>: View {
    var title: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.rowSpacing) {
            if let title, !title.isEmpty {
                Text(title)
                    .font(.headline)
            }
            content()
        }
        .padding(AppDesign.cardPadding)
        .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
        .padding(.horizontal, AppDesign.cardPadding)
        .padding(.top, AppDesign.blockSpacing)
    }
}

/// Сегментный выбор с «не задано» через отдельное состояние (удобно для Optional).
struct SegmentedPicker<T: Hashable, Label: StringProtocol>: View {
    let title: String
    @Binding var selection: T
    let options: [(T, Label)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Picker(title, selection: $selection) {
                ForEach(0..<options.count, id: \.self) { i in
                    Text(String(options[i].1)).tag(options[i].0)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

// MARK: - Телефон: только цифры, 8 → +7, валидация 11 цифр

enum PhoneFormatter {
    /// Форматирует ввод: только цифры; первая 8 заменяется на 7; если первая не 7/8 — подставляем 7; макс. 11 цифр. Отображение: +7 и до 10 цифр после.
    static func format(_ string: String) -> String {
        var digits = string.filter { $0.isNumber }
        if digits.first == "8" {
            digits = "7" + digits.dropFirst()
        }
        if !digits.isEmpty && digits.first != "7" {
            digits = "7" + digits
        }
        digits = String(digits.prefix(11))
        if digits.isEmpty { return "" }
        return "+7" + digits.dropFirst()
    }

    /// Только цифры номера (для сохранения/звонка), до 11 символов.
    static func digitsOnly(_ string: String) -> String {
        String(string.filter { $0.isNumber }.prefix(11))
    }

    /// Валидный российский номер: ровно 11 цифр, первая 7.
    static func isValid(_ string: String) -> Bool {
        let d = string.filter { $0.isNumber }
        return d.count == 11 && d.first == "7"
    }

    /// Отображение номера в виде +7 990 123-45-67 (для UI).
    static func displayString(_ string: String) -> String {
        var digits = string.filter { $0.isNumber }
        if digits.first == "8" {
            digits = "7" + digits.dropFirst()
        }
        if !digits.isEmpty && digits.first != "7" {
            digits = "7" + digits
        }
        digits = String(digits.prefix(11))
        guard digits.count == 11, digits.first == "7" else {
            return string.isEmpty ? "" : string
        }
        let a = Array(digits)
        let p1 = a[1..<4].map { String($0) }.joined()
        let p2 = a[4..<7].map { String($0) }.joined()
        let p3 = a[7..<9].map { String($0) }.joined()
        let p4 = a[9..<11].map { String($0) }.joined()
        return "+7 \(p1) \(p2)-\(p3)-\(p4)"
    }

    /// Формат при вводе: +7 999 123-45-67 (работает и для неполного номера).
    static func formatForDisplay(_ string: String) -> String {
        var digits = string.filter { $0.isNumber }
        if digits.first == "8" {
            digits = "7" + digits.dropFirst()
        }
        if !digits.isEmpty && digits.first != "7" {
            digits = "7" + digits
        }
        digits = String(digits.prefix(11))
        guard !digits.isEmpty, digits.first == "7" else { return string.isEmpty ? "" : string }
        let rest = Array(digits.dropFirst())
        var result = "+7"
        if !rest.isEmpty { result += " " }
        for (i, c) in rest.enumerated() {
            if i == 3 { result += " " }
            else if i == 6 { result += "-" }
            else if i == 8 { result += "-" }
            result += String(c)
        }
        return result
    }
}

// MARK: - Единая форма профиля/подопечного (общие блоки)
// Используются в: CreateProfileView, EditProfileView, EditTraineeSheet, CreateManagedTraineeSheet (AddTraineeView).
// Изменения здесь автоматически применяются ко всем экранам создания/редактирования.
// MARK: - Компактная форма (одна карточка на секцию, строки с полями)

/// Одна строка формы: иконка + подпись слева, контент справа. Для секций, где несколько полей в одной карточке.
struct FormRow<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .center, spacing: AppDesign.rowSpacing) {
            AppTablerIcon(icon)
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .center)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(minWidth: 100, alignment: .leading)
                .layoutPriority(0)
            content()
                .layoutPriority(1)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Разделитель между строками внутри секции формы (визуально под контентом, не под иконкой).
struct FormSectionDivider: View {
    private static let labelArea: CGFloat = 28 + AppDesign.rowSpacing + 100
    var body: some View {
        Divider()
            .padding(.leading, Self.labelArea)
    }
}

// MARK: - Переиспользуемые строки формы (как в EditProfileView)

/// Строка формы: иконка + подпись + TextField. Один стиль для всех экранов с формами.
struct FormRowTextField: View {
    let icon: String
    let title: String
    let placeholder: String
    @Binding var text: String
    var textContentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .sentences
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        FormRow(icon: icon, title: title) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .textContentType(textContentType)
                .textInputAutocapitalization(autocapitalization)
                .keyboardType(keyboardType)
                .multilineTextAlignment(.trailing)
                .formInputStyle()
        }
    }
}

/// Строка формы: иконка + подпись + поле телефона (формат +7 999 123-45-67 при вводе).
struct FormRowPhone: View {
    let icon: String
    let title: String
    @Binding var text: String

    var body: some View {
        FormRow(icon: icon, title: title) {
            TextField("+7 900 123-45-67", text: Binding(
                get: { PhoneFormatter.formatForDisplay(text) },
                set: { text = PhoneFormatter.format($0) }
            ))
                .textFieldStyle(.plain)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .formInputStyle()
        }
    }
}

/// Строка формы: дата рождения — по тапу открывается пикер, крестик сбрасывает. Контент строки; sheet показывается снаружи.
struct FormRowDateOfBirth: View {
    @Binding var selection: Date?
    var onTap: () -> Void

    private static var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = .ru
        f.dateStyle = .medium
        return f
    }

    var body: some View {
        FormRow(icon: "calendar-default", title: "Дата рождения") {
            HStack(spacing: 6) {
                Button(action: onTap) {
                    Text(selection.map { Self.dateFormatter.string(from: $0) } ?? "Указать дату")
                        .foregroundStyle(selection != nil ? .primary : .secondary)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .buttonStyle(.plain)
                if selection != nil {
                    Button {
                        selection = nil
                    } label: {
                        AppTablerIcon("multiple-cross-cancel-circle")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Карточка «Заметки»: многострочное поле. Один стиль для профиля, подопечного и др. (питание и т.д.).
struct FormNotesCard: View {
    @Binding var notes: String
    var title: String = "Заметки"
    var placeholder: String = "Противопоказания, важная информация"

    var body: some View {
        SettingsCard(title: title) {
            TextField(placeholder, text: $notes, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(3...5)
                .textInputAutocapitalization(.sentences)
                .formInputStyle()
        }
    }
}

/// Полноэкранный date picker sheet (календарь, ru_RU). Для использования с FormRowDateOfBirth.
struct FormDatePickerSheet: View {
    @Binding var selection: Date?
    @Binding var isPresented: Bool
    var title: String = "Дата рождения"

    var body: some View {
        NavigationStack {
            DatePicker("", selection: Binding(
                get: { selection ?? Date() },
                set: { selection = $0 }
            ), displayedComponents: .date)
            .datePickerStyle(.graphical)
            .environment(\.locale, .ru)
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Очистить") {
                        selection = nil
                        isPresented = false
                    }
                    .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        isPresented = false
                    } label: {
                        Text("Готово")
                            .fontWeight(.regular)
                    }
                        .foregroundStyle(.primary)
                }
            }
        }
    }
}

// MARK: - Блок заметок (профиль и карточка подопечного)

/// Блок заметок: заголовок + многострочный текст. Одинаковый вид в профиле пользователя и в карточке подопечного.
struct NotesBlockView: View {
    let notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: AppDesign.rowSpacing) {
                AppTablerIcon("file-default")
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .center)
                Text("Заметки")
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, AppDesign.cardPadding)
            .padding(.top, 12)
            .padding(.bottom, 8)
            Divider()
                .padding(.leading, 40)
            Text(notes)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, AppDesign.cardPadding)
                .padding(.vertical, 12)
                .padding(.bottom, 16)
        }
        .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
        .padding(.horizontal, AppDesign.cardPadding)
        .padding(.top, AppDesign.blockSpacing)
    }
}

