# TrainLog iOS — матрица экранов и состояний (живой документ)

Цель: единообразие каркаса, состояний и навигации. Иерархия: `AppDesign` / `AppColors` → правила в [`.cursor/rules/trainlog-ios.mdc`](../.cursor/rules/trainlog-ios.mdc) → skills mobile-ios-design / ios-application-dev.

## Якорные потоки

| Поток | Точки входа | Примечание |
|--------|-------------|------------|
| Тренер: главная → карточка | `CoachMainView` → `CoachHomeView` → `ClientCardView` | Навигация по `homeNavigationPath` |
| Тренер: статистика | `CoachHomeView` → `CoachStatisticsView` | Сеть, период, кэш API |
| Подопечный: главная | `TraineeMainView` → `TraineeHomeView` | Карточки `ContentCard` |
| Подопечный: прогресс | Таб «Прогресс» → `ProgressHubView` | Hero + `ContentCard` |
| Подопечный: замеры/графики | `MeasurementsAndChartsScreen` | Hero + сводка |
| Настройки | `AppSettingsView` | `SettingsCard` |
| Поддержка проекта | Настройки / главная → `SupportProjectView` | Inline error + retry |

## Каркас по ключевым экранам

| Экран / область | Каркас | Примечание |
|-----------------|--------|------------|
| `CoachHomeView` | `ContentCard` + строки | Скелетон при `isLoading` |
| `TraineeHomeView` | `ContentCard` | Скелетон при загрузке блока |
| `TraineeMainView` профиль | `ScrollView` + секции | Заголовок навбара «Профиль» |
| `ProgressHubView` | `HeroCard` + `ContentCard` | Анимация появления |
| `MeasurementsAndChartsScreen` | `HeroCard` + карточки | «О разделе» как в достижениях |
| `PersonalRecordsView` | `HeroCard` + лента | Info overlay |
| `CoachStatisticsView` | `ScrollView` / скелетон / `ContentUnavailableView` | Ошибка: inline + «Повторить» |
| `SupportProjectView` | Кастом hero + карточки + `SettingsCard` (счёт) | Эталон error/retry |
| `AppSettingsView` | `SettingsCard` | Стандарт настроек |
| `CalculatorsCatalogView` | intro + список / `ContentUnavailableView` + «Повторить» при ошибке загрузки | Разделить пустой каталог и сетевую ошибку |
| `CoachStatisticsView` | скелетон / контент / `ContentUnavailableView` + «Повторить» | Без дублирующего alert |

**ContentCard** — блоки на главных с заголовком + описанием и действиями внутри белой/серой карточки с акцентной рамкой.

**SettingsCard** — нейтральная подложка, часто списки настроек или вторичные блоки (счёт, группы полей).

**HeroCard** — верхний акцентный блок с градиентом (часто + `decoration: .glow`).

## Состояния (когда что)

| Состояние | Компонент | Когда |
|-----------|-----------|--------|
| Первая загрузка списка/экрана | Скелетон или `LoadingBlockView` | До первого успешного ответа |
| Повторная загрузка / фон | `LoadingOverlayView` | Поверх уже показанного контента |
| Пустые данные | `ContentUnavailableView` | Нет элементов, не ошибка |
| Ошибка сети / API | `ContentUnavailableView` + кнопка «Повторить» **или** карточка с текстом + «Повторить» | Начальная загрузка провалилась |
| Лёгкая обратная связь | `ToastCenter` | Успех, неблокирующая ошибка после действия |

## Ручной smoke (iPad + тёмная тема)

После заметных UI-изменений проверить:

1. **iPad** (split view ~50/50): главная тренера и подопечного, календарь/абонементы, форма добавления замера, статистика.
2. **Тёмная тема**: те же экраны — читаемость `secondaryLabel`, границы карточек.
3. **Dynamic Type** (крупная категория): `ProgressHubView`, `ClientCardView` (шапка), один калькулятор.
4. **VoiceOver**: главная подопечного, профиль (переключение профиля, редактирование), одна строка с иконкой без текста.
