import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DeveloperComponentsCatalogView: View {
    @State private var nameSample: String = "Алексей"
    @State private var emailSample: String = "test@example.com"
    @State private var toggleSample: Bool = true
    @State private var segmentedTwo: Int = 0
    @State private var segmentedThree: Int = 1
    @State private var dateSample: Date = Date()
    @State private var dateOptionalSample: Date? = Calendar.current.date(byAdding: .year, value: -25, to: Date())
    @State private var showDatePickerSheetDemo: Bool = false
    @State private var showGraphicalHeightSheetDemo: Bool = false
    @State private var showDetentsDemo: Bool = false
    @State private var nutritionProteinSample: Double = 2
    @State private var nutritionFatSample: Double = 0.8
    @State private var nutritionCarbsSample: Double = 3

    var body: some View {
        ScrollView {
            VStack(spacing: AppDesign.blockSpacing) {
                SettingsCard(title: "Размеры (AppDesign)") {
                    VStack(alignment: .leading, spacing: 10) {
                        sizeRow("cardPadding", "\(AppDesign.cardPadding)")
                        sizeRow("rowSpacing", "\(AppDesign.rowSpacing)")
                        sizeRow("blockSpacing", "\(AppDesign.blockSpacing)")
                        sizeRow("sectionSpacing", "\(AppDesign.sectionSpacing)")
                        sizeRow("cornerRadius", "\(AppDesign.cornerRadius)")
                        sizeRow("primaryButtonHeight", "\(AppDesign.primaryButtonHeight)")
                        sizeRow("avatarCornerRadiusSmall", "\(AppDesign.avatarCornerRadiusSmall)")
                        sizeRow("avatarCornerRadiusLarge", "\(AppDesign.avatarCornerRadiusLarge)")
                        sizeRow("rectangularBlockMinHeight", "\(AppDesign.rectangularBlockMinHeight)")
                        sizeRow("rectangularBlockSpacing", "\(AppDesign.rectangularBlockSpacing)")
                        sizeRow("emptyStateIconSize", "\(AppDesign.emptyStateIconSize)")
                        sizeRow("emptyStateSpacing", "\(AppDesign.emptyStateSpacing)")
                        sizeRow("emptyStateVerticalPadding", "\(AppDesign.emptyStateVerticalPadding)")
                        sizeRow("loadingScale", "\(AppDesign.loadingScale)")
                    }
                    .padding(.vertical, 4)
                }

                SettingsCard(title: "Размеры (примеры)") {
                    VStack(alignment: .leading, spacing: 12) {
                        exampleBlock(title: "cardPadding = \(Int(AppDesign.cardPadding))") {
                            HStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: AppDesign.cornerRadius)
                                    .fill(AppColors.secondarySystemGroupedBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppDesign.cornerRadius)
                                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                                    )
                                    .overlay(alignment: .topLeading) {
                                        Text("контейнер")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .padding(8)
                                    }

                                RoundedRectangle(cornerRadius: AppDesign.cornerRadius)
                                    .fill(AppColors.tertiarySystemFill)
                                    .frame(width: 90)
                                    .overlay {
                                        Text("контент")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(AppDesign.cardPadding)
                                    .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
                            }
                            .frame(maxWidth: .infinity)
                        }

                        exampleBlock(title: "cornerRadius = \(Int(AppDesign.cornerRadius)) / avatarCornerRadius") {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: AppDesign.cornerRadius)
                                    .fill(AppColors.accent.opacity(0.18))
                                    .frame(width: 68, height: 44)
                                    .overlay(Text("\(Int(AppDesign.cornerRadius))").font(.caption2).foregroundStyle(.secondary))
                                RoundedRectangle(cornerRadius: AppDesign.avatarCornerRadiusSmall)
                                    .fill(AppColors.avatarColor(gender: .male).opacity(0.18))
                                    .frame(width: 44, height: 44)
                                    .overlay(Text("\(Int(AppDesign.avatarCornerRadiusSmall))").font(.caption2).foregroundStyle(.secondary))
                                RoundedRectangle(cornerRadius: AppDesign.avatarCornerRadiusLarge)
                                    .fill(AppColors.avatarColor(gender: .female).opacity(0.18))
                                    .frame(width: 80, height: 44)
                                    .overlay(Text("\(Int(AppDesign.avatarCornerRadiusLarge))").font(.caption2).foregroundStyle(.secondary))
                            }
                        }

                        exampleBlock(title: "primaryButtonHeight = \(Int(AppDesign.primaryButtonHeight))") {
                            Button { } label: { Text("Primary") }
                                .buttonStyle(PrimaryButtonStyle())
                        }
                    }
                    .padding(.vertical, 4)
                }

                SettingsCard(title: "Иконки (SF Symbols)") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("В приложении по умолчанию используем outline-версии. Варианты `.fill` — только для выделенного/активного состояния (например, выбранный таб) или когда нужен сильный акцент.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        iconGroup("Профиль / навигация (outline — используем)", icons: [
                            ("person.crop.circle", "Таб профиль"),
                            ("person.3", "Подопечные"),
                            ("figure.strengthtraining.traditional", "Тренер"),
                            ("note.text", "Дневник"),
                            ("square.grid.2x2", "UI Kit"),
                            ("chevron.right", "Переход"),
                            ("chevron.left", "Назад"),
                            ("chevron.up", "Свернуть"),
                            ("chevron.down", "Развернуть"),
                            ("pencil", "Редактировать"),
                            ("arrow.left.arrow.right", "Сменить профиль"),
                        ])
                        iconGroup("Действия (outline — используем)", icons: [
                            ("plus", "Добавить"),
                            ("plus.circle", "Добавить (круг)"),
                            ("minus.circle", "Убрать"),
                            ("trash", "Удалить"),
                            ("key", "Код"),
                            ("lock.rotation", "Пароль"),
                            ("rectangle.portrait.and.arrow.right", "Выйти"),
                        ])
                        iconGroup("Контент (outline — используем)", icons: [
                            ("ticket", "Абонементы"),
                            ("calendar", "Календарь / дата"),
                            ("calendar.badge.plus", "Добавить посещение"),
                            ("calendar.badge.exclamationmark", "Нет данных"),
                            ("ruler", "Замеры (таб)"),
                            ("chart.bar.xaxis", "График"),
                            ("chart.xyaxis.line", "Графики замеров"),
                            ("list.bullet", "Список"),
                            ("doc.on.clipboard", "Копировать"),
                            ("magnifyingglass", "Поиск"),
                            ("checkmark", "Отмечено"),
                            ("xmark.circle", "Закрыть"),
                        ])
                        iconGroup("Абонементы / события (outline — используем)", icons: [
                            ("snowflake", "Заморозка"),
                            ("snowflake.slash", "Разморозка"),
                            ("arrow.up.right.square", "Внешняя ссылка"),
                            ("figure.run", "Сплеш / онбординг"),
                            ("checkmark.circle", "Готово"),
                            ("exclamationmark.circle", "Ошибка"),
                        ])

                        iconGroup("Заливка (fill — только для активного/акцента)", icons: [
                            ("person.crop.circle.fill", "Профиль (selected)"),
                            ("person.3.fill", "Подопечные (selected)"),
                            ("ticket.fill", "Абонементы (акцент)"),
                            ("ruler.fill", "Замеры (акцент)"),
                            ("chart.bar.fill", "Статистика (акцент)"),
                            ("star.circle.fill", "Цели (акцент)"),
                            ("gearshape.fill", "Управление (акцент)"),
                            ("ellipsis.circle.fill", "Ещё (акцент)"),
                            ("plus.circle.fill", "Добавить (акцент)"),
                            ("minus.circle.fill", "Убрать (акцент)"),
                            ("xmark.circle.fill", "Закрыть (акцент)"),
                            ("checkmark.circle.fill", "Готово (акцент)"),
                            ("exclamationmark.circle.fill", "Ошибка (акцент)"),
                            ("key.fill", "Код (акцент)"),
                        ])
                    }
                    .padding(.vertical, 4)
                }

                SettingsCard(title: "Переключатели") {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Toggle")
                                .font(.subheadline.weight(.semibold))
                            Toggle("Напомнить о событии", isOn: $toggleSample)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Picker (.segmented) — 2 варианта")
                                .font(.subheadline.weight(.semibold))
                            Picker("", selection: $segmentedTwo) {
                                Text("Активные").tag(0)
                                Text("Завершённые").tag(1)
                            }
                            .pickerStyle(.segmented)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Picker (.segmented) — 3 варианта")
                                .font(.subheadline.weight(.semibold))
                            Picker("", selection: $segmentedThree) {
                                Text("1 мес").tag(0)
                                Text("3 мес").tag(1)
                                Text("6 мес").tag(2)
                            }
                            .pickerStyle(.segmented)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("DatePicker (compact)")
                                .font(.subheadline.weight(.semibold))
                            DatePicker("Дата", selection: $dateSample, displayedComponents: .date)
                                .labelsHidden()
                                .environment(\.locale, .ru)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("DatePicker (.graphical)")
                                .font(.subheadline.weight(.semibold))
                            DatePicker("", selection: $dateSample, displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .environment(\.locale, .ru)
                        }
                    }
                    .padding(.vertical, 4)
                }

                SettingsCard(title: "Ввод даты (вариации в приложении)") {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("FormRowDateOfBirth + FormDatePickerSheet")
                                .font(.subheadline.weight(.semibold))
                            Text("Строка показывает значение/плейсхолдер, по тапу открывает календарь в sheet (ru_RU).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            FormRowDateOfBirth(selection: $dateOptionalSample, onTap: { showDatePickerSheetDemo = true })
                        }

                        Button {
                            showGraphicalHeightSheetDemo = true
                        } label: {
                            HStack(spacing: 12) {
                                AppTablerIcon("calendar-filled")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28, alignment: .center)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Graphical DatePicker (фиксированная высота)")
                                        .foregroundStyle(.primary)
                                    Text("Используем, чтобы календарь не открывался на весь экран.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                AppTablerIcon("chevron-right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                    .padding(.vertical, 4)
                }

                SettingsCard(title: "Цвета (AppColors / EventColor)") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Отсортировано по оттенку (hue). Для системных/dynamic цветов показаны Light/Dark варианты.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        let tokens = colorTokensSortedByHue()
                        ForEach(tokens) { t in
                            colorRow(name: t.name, color: t.color, code: t.code)
                        }
                    }
                    .padding(.vertical, 4)
                }

                SettingsCard(title: "Щиты (правила)") {
                    VStack(alignment: .leading, spacing: 10) {
                        ruleRow(title: "Detents (высота)", text: "Стартуем компактно: `.presentationDetents([.medium, .large])`. Если контента мало — остаётся medium, если много и есть скролл — можно раскрыть до full (`.large`). Для спец-кейсов используем фиксированную высоту `.height(...)`.")
                        ruleRow(title: "Заголовок", text: "Всегда по центру: `.navigationBarTitleDisplayMode(.inline)`.")
                        ruleRow(title: "Кнопки", text: "Все кнопки действий — только в заголовке (toolbar). Текст кнопок не делаем жирным: `.fontWeight(.regular)`.")

                        Button {
                            showDetentsDemo = true
                        } label: {
                            HStack(spacing: 12) {
                                AppTablerIcon("log-out-right")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28, alignment: .center)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Открыть пример щита")
                                        .foregroundStyle(.primary)
                                    Text("Покажет detents и drag-indicator на практике.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                AppTablerIcon("chevron-right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                    .padding(.vertical, 4)
                }

                SettingsCard(title: "Карточки (SettingsCard)") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SettingsCard")
                            .font(.subheadline.weight(.semibold))
                        Text("Используем для блоков настроек/управления. Внутри — любые строки или кастомный контент.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                }

                SettingsCard(title: "Кнопки") {
                    VStack(spacing: 12) {
                        MainActionButton(title: "MainActionButton") { }

                        Button {
                        } label: {
                            Text("Primary")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button {
                        } label: {
                            Text("Pressable")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(AppDesign.cardPadding)
                                .background(
                                    AppColors.secondarySystemGroupedBackground,
                                    in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius)
                                )
                        }
                        .buttonStyle(PressableButtonStyle())

                        AddActionRow(title: "AddActionRow", appIcon: "plus-square")
                            .padding(.horizontal, AppDesign.cardPadding)
                            .padding(.vertical, 12)
                            .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
                    }
                }

                SettingsCard(title: "WideActionButtonToOneColumn (иконка или аватар + текст + шеврон)") {
                    VStack(spacing: 8) {
                        Button { } label: {
                            WideActionButtonToOneColumn(
                                leading: .avatar(
                                    icon: "file-default",
                                    iconColor: AppColors.avatarColor(gender: .female, defaultColor: AppColors.avatarIcon),
                                    background: AppColors.avatarBackground,
                                    cornerRadius: AppDesign.avatarCornerRadiusSmall,
                                    sideLength: 44
                                ),
                                title: "Крупный заголовок",
                                subtitle: "Для верхних блоков и списков профилей",
                                prominentTitle: true,
                                chevronColor: AppColors.secondaryLabel
                            )
                        }
                        .buttonStyle(PressableButtonStyle())

                        NavigationLink {
                            Text("Пример экрана")
                                .navigationTitle("Демо")
                        } label: {
                            WideActionButtonToOneColumn(
                                icon: "calendar-default",
                                title: "Компактный вариант",
                                subtitle: "Для списков внутри экранов",
                                iconColor: AppColors.secondaryLabel,
                                chevronColor: AppColors.secondaryLabel
                            )
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                    .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
                    .padding(.vertical, 4)
                }

                SettingsCard(title: "Инпуты") {
                    VStack(spacing: 12) {
                        FormRowTextField(icon: "writing-sign", title: "Имя", placeholder: "Введите имя", text: $nameSample)
                        FormRowTextField(icon: "envelope-default", title: "Email", placeholder: "Введите email", text: $emailSample)
                    }
                }

                SettingsCard(title: "Nutrition UI (переиспользуемые)") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("MacroTripleInputRow")
                            .font(.subheadline.weight(.semibold))
                        MacroTripleInputRow(
                            proteinPerKg: $nutritionProteinSample,
                            fatPerKg: $nutritionFatSample,
                            carbsPerKg: $nutritionCarbsSample
                        )

                        Divider()
                        Text("NutritionPreviewCard + MacroRatioDonutView")
                            .font(.subheadline.weight(.semibold))
                        NutritionPreviewCard(preview: nutritionPreviewSample)
                    }
                    .padding(.vertical, 4)
                }

                SettingsCard(title: "Тексты (стили / цвета)") {
                    VStack(alignment: .leading, spacing: 10) {
                        textLine("title2", font: .title2, color: .primary)
                        textLine("title3.weight(.semibold)", font: .title3.weight(.semibold), color: .primary)
                        textLine("headline", font: .headline, color: .primary)
                        textLine("subheadline", font: .subheadline, color: .secondary)
                        textLine("caption", font: .caption, color: .secondary)
                        textLine("caption2 (tertiaryLabel)", font: .caption2, color: AppColors.tertiaryLabel)
                        Divider()
                        textLine("accent", font: .callout.weight(.semibold), color: AppColors.accent)
                        textLine("destructive (red)", font: .callout.weight(.semibold), color: .red)
                    }
                    .padding(.vertical, 4)
                }

                SettingsCard(title: "Стикеры") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("OfflineSticker")
                            .font(.subheadline.weight(.semibold))
                        OfflineSticker()
                            .frame(height: 90)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }

                SettingsCard(title: "Абонементы") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("MembershipProgressInlineView")
                            .font(.subheadline.weight(.semibold))
                        Text("Показывает прогресс (дни/занятия) для активного абонемента.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        MembershipProgressInlineView(
                            membership: sampleMembershipByVisits,
                            tint: AppColors.accent
                        )
                    }
                }

                SettingsCard(title: "Блоки (строки/плитки)") {
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ActionBlockRow + actionBlockStyle()")
                                .font(.subheadline.weight(.semibold))
                            ActionBlockRow(icon: "user-default", title: "Пол", value: "Мужской")
                                .actionBlockStyle()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("CardRow")
                                .font(.subheadline.weight(.semibold))
                            CardRow(icon: "calendar-default", title: "Дата рождения", value: "12.03.1998", showsDisclosure: true)
                                .background(AppColors.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("RectangularBlockContent + rectangularBlockStyle()")
                                .font(.subheadline.weight(.semibold))
                            HStack(spacing: AppDesign.rectangularBlockSpacing) {
                                RectangularBlockContent(icon: "tag", title: "Абонементы", value: "2")
                                    .rectangularBlockStyle()
                                RectangularBlockContent(icon: "calendar-default", title: "Посещения", value: "12")
                                    .rectangularBlockStyle()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(.horizontal, AppDesign.cardPadding)
            .padding(.top, AppDesign.blockSpacing)
            .padding(.bottom, AppDesign.sectionSpacing)
        }
        .background(AdaptiveScreenBackground())
        .navigationTitle("UI Kit")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDatePickerSheetDemo) {
            FormDatePickerSheet(selection: $dateOptionalSample, isPresented: $showDatePickerSheetDemo, title: "Дата рождения")
                .presentationDetents(AppSheetDetents.calendar)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showGraphicalHeightSheetDemo) {
            NavigationStack {
                DatePicker("", selection: $dateSample, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .environment(\.locale, .ru)
                    .padding()
                    .navigationTitle("Выбор даты")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Отмена") { showGraphicalHeightSheetDemo = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button { showGraphicalHeightSheetDemo = false } label: {
                                Text("Готово")
                                    .font(.body)
                                    .fontWeight(.regular)
                            }
                            .foregroundStyle(.primary)
                        }
                    }
            }
            .presentationDetents([.height(420)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDetentsDemo) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppDesign.blockSpacing) {
                        SettingsCard(title: "Что такое detents") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Detents — это допустимые высоты sheet.")
                                    .font(.subheadline.weight(.semibold))
                                Text("`.medium` — средняя высота. Для календарей используем `.height(...)`, чтобы не растягивалось и не уходило на весь экран.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }

                        SettingsCard(title: "Правила (кратко)") {
                            VStack(alignment: .leading, spacing: 10) {
                                ruleRow(title: "По умолчанию", text: "`.presentationDetents([.medium, .large])` + `.presentationDragIndicator(.visible)`.")
                                ruleRow(title: "Календарь", text: "`.presentationDetents([.height(420)])` — выглядит аккуратно и предсказуемо.")
                                ruleRow(title: "Кнопки в toolbar", text: "Не делаем жирными: `.fontWeight(.regular)`.")
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal, AppDesign.cardPadding)
                    .padding(.top, AppDesign.blockSpacing)
                    .padding(.bottom, AppDesign.sectionSpacing)
                }
                .background(AdaptiveScreenBackground())
                .navigationTitle("Пример щита")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button { showDetentsDemo = false } label: {
                            Text("Закрыть")
                                .font(.body)
                                .fontWeight(.regular)
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .presentationDetents(AppSheetDetents.mediumOnly)
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Samples

    private var sampleMembershipByVisits: Membership {
        Membership(
            id: "sample",
            coachProfileId: "coach",
            traineeProfileId: "trainee",
            createdAt: Date(),
            kind: .byVisits,
            totalSessions: 12,
            usedSessions: 5,
            startDate: Calendar.current.date(byAdding: .day, value: -10, to: Date()),
            endDate: Calendar.current.date(byAdding: .day, value: 20, to: Date()),
            priceRub: nil
        )
    }

    private var nutritionPreviewSample: NutritionPreviewModel {
        NutritionPreviewModel(
            weightKg: 72,
            proteinPerKg: nutritionProteinSample,
            fatPerKg: nutritionFatSample,
            carbsPerKg: nutritionCarbsSample
        )
    }

    // MARK: - Helpers

    private func colorRow(name: String, color: Color, code: String? = nil) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(color)
                .frame(width: 44, height: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.callout)
                    .foregroundStyle(.primary)
                if let code, !code.isEmpty {
                    Text(code)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
    }

    private func ruleRow(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func exampleBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sizeRow(_ name: String, _ value: String) -> some View {
        HStack {
            Text(name)
                .font(.callout)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func iconGroup(_ groupTitle: String, icons: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(groupTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(icons.enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 6) {
                        AppTablerIcon(item.0)
                            .font(.title2)
                            .foregroundStyle(.primary)
                            .frame(width: 36, height: 36)
                        Text(item.1)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func textLine(_ title: String, font: Font, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("Пример текста")
                .font(font)
                .foregroundStyle(color)
        }
    }

    // MARK: - Colors catalog helpers

    private struct ColorToken: Identifiable {
        let id: String
        let name: String
        let color: Color
        let code: String
        let hue: Double
    }

    private func colorTokensSortedByHue() -> [ColorToken] {
        let base: [(String, Color, String?)] = [
            ("AppColors.accent", AppColors.accent, nil),
            ("AppColors.profileAccent", AppColors.profileAccent, nil),
            ("AppColors.genderMale", AppColors.genderMale, nil),
            ("AppColors.genderFemale", AppColors.genderFemale, nil),
            ("AppColors.visitsBySubscription", AppColors.visitsBySubscription, nil),
            ("AppColors.visitsOneTimePaid", AppColors.visitsOneTimePaid, nil),
            ("AppColors.visitsOneTimeDebt", AppColors.visitsOneTimeDebt, nil),
            ("AppColors.visitsCancelled", AppColors.visitsCancelled, nil),
        ] + EventColor.palette.map { ("EventColor.palette #\($0.hex)", $0.color, "#\($0.hex)") } + [
            ("AppColors.secondarySystemGroupedBackground", AppColors.secondarySystemGroupedBackground, nil),
            ("AppColors.tertiarySystemFill", AppColors.tertiarySystemFill, nil),
            ("AppColors.label", AppColors.label, nil),
            ("AppColors.secondaryLabel", AppColors.secondaryLabel, nil),
            ("AppColors.tertiaryLabel", AppColors.tertiaryLabel, nil),
        ]

        // Убираем дубли по фактическому цвету (после объединения токенов/палитры).
        var seenCodes: Set<String> = []
        let mapped: [ColorToken] = base.compactMap { name, color, explicitHex in
            let code = explicitHex ?? resolvedHexVariants(for: color)
            let hue = resolvedHue(for: color)
            guard seenCodes.insert(code).inserted else { return nil }
            return ColorToken(id: name, name: name, color: color, code: code, hue: hue)
        }
        return mapped
        .sorted { a, b in
            if a.hue != b.hue { return a.hue < b.hue }
            return a.name < b.name
        }
    }

    private func resolvedHue(for color: Color) -> Double {
#if canImport(UIKit)
        let ui = UIColor(color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            return Double(h)
        }
        // grayscale: hue is undefined, push to the end
        return 10_000
#else
        return 10_000
#endif
    }

    private func resolvedHexVariants(for color: Color) -> String {
#if canImport(UIKit)
        let light = hexString(UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)))
        let dark = hexString(UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)))
        if light == dark {
            return light
        }
        return "Light \(light)  •  Dark \(dark)"
#else
        return ""
#endif
    }

#if canImport(UIKit)
    private func hexString(_ uiColor: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return "—" }
        let ri = Int(round(r * 255))
        let gi = Int(round(g * 255))
        let bi = Int(round(b * 255))
        let ai = Int(round(a * 255))
        if ai == 255 {
            return String(format: "#%02X%02X%02X", ri, gi, bi)
        }
        return String(format: "#%02X%02X%02X%02X", ri, gi, bi, ai)
    }
#endif
}

