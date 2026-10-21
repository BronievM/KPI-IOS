# KPI Schedule App

Мобільний iOS-застосунок для перегляду розкладу в КПІ. Дозволяє обирати групу й тиждень (1/2), переглядати пари, розрізняти їх за типами, бачити викладачів, аудиторії та час, фільтрувати пари, бачити виділені поточний день і поточну пару та переходити на онлайн-пари по кліку.

- **Версія XCode:** 15.6
- **Мінімальна версія iOS:** 17.4
- **Теги для перевірки:** `practical-1`, `practical-2`

## Практична робота 2: архітектура та патерни

Застосунок переведено на **MVVM**, додано патерни Builder, Adapter, Strategy, розділено відповідальності та винесено залежності за протоколи (можна підмінити тестовою реалізацією).

Повна документація: **[docs/architecture.md](docs/architecture.md)** (обґрунтування архітектури, схема, патерни, SOLID, антипатерни, таблиця відповідності).

### Структура проєкту

```
kpi-schedule/
├── App/          kpi_scheduleApp, AppContainer (composition root)
├── Models/       Lesson, DailySchedule, LessonType, LessonTime, Weekday, ScheduleItem
├── Views/        ContentView, LessonRowView
├── ViewModels/   ScheduleViewModel
├── Services/     ScheduleRepository, JSONScheduleRepository,
│                 MockScheduleRepository, LinkOpening, ScheduleClock
└── Patterns/     LessonBuilder, LessonDTOAdapter, LessonFilterStrategy
kpi-scheduleTests/  ScheduleViewModelTests
```

### Коротко: патерн / принцип — компонент — призначення

| Патерн / принцип | Компонент | Призначення |
|---|---|---|
| MVVM | `ContentView` ↔ `ScheduleViewModel` ↔ `ScheduleRepository` | Розподіл обов'язків: інтерфейс лише показує дані, логіка обробляє стан, а сховище віддає інформацію. |
| Builder | `LessonBuilder` | Зручне створення складних об'єктів з купою необов'язкових параметрів по частинах. |
| Adapter | `LessonDTOAdapter` | Перетворює зовнішній формат даних на зручні внутрішні моделі застосунку. |
| Strategy | `LessonFilterStrategy` | Гнучке перемикання правил фільтрації без переписування коду екрана. |
| DIP + DI | `ScheduleViewModel`, `AppContainer` | Залежність від абстракцій (протоколів) і передача необхідних компонентів зовні через ініціалізатор. |
| Clock (DI) | `ScheduleClock` | Абстракція над поточним часом для коректного визначення пари й зручної підміни в тестах. |

Детальніше й повна таблиця (з SOLID) у [docs/architecture.md](docs/architecture.md).

## Практична робота 1 (тег `practical-1`)

Протоколи та enum (`ScheduleItem`, `LessonType`, `WeekType`), структури й класи (`Lesson` struct, `DailySchedule` class), опціонали (`room`, `link`) з безпечним розгортанням, колекції, інтерфейс на `NavigationView` + `List` з секціями по днях і клікабельними онлайн-парами.

## Інструкція з запуску

1. Клонуйте репозиторій і перейдіть на потрібний тег/гілку (`practical-2`).
2. Відкрийте `kpi-schedule.xcodeproj` у **Xcode 15.6**.
3. Оберіть симулятор (наприклад, iPhone 15) і натисніть **Run** (`Cmd + R`).
4. Тести: `Cmd + U`.
