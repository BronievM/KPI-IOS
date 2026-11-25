# Мережевий шар KPI Schedule App (практична 4)
 
## 1. Джерело даних
 
Розклад береться з API КПІ Campus. Власного сервера немає: завдання, лінки на пари та вибір предметів кожен користувач зберігає локально.
 
| | |
|---|---|
| Базова адреса | `https://api.campus.kpi.ua` |
| Авторизація | не потрібна |
| Формат | JSON |
 
| Endpoint | Параметри | Відповідь |
|---|---|---|
| `GET /schedule/groups` | немає | масив `[{id, name, faculty}]` або `{"data": [...]}` |
| `GET /schedule/lessons` | `groupId=<id>` | `{scheduleFirstWeek: [{day, pairs: [...]}], scheduleSecondWeek: [...]}` |
 
### Заголовки запиту
 
З 16.11.2026 API повертає 403 для запитів без заголовків вебклієнта, тому `APIClient` додає:
 
| Заголовок | Значення |
|---|---|
| `Accept` | `application/json, text/plain, */*` |
| `Accept-Language` | `uk-UA,uk;q=0.9,en-US;q=0.8,en;q=0.7` |
| `User-Agent` | браузерний (Firefox) |
| `Origin` | `https://schedule.kpi.ua` |
| `Referer` | `https://schedule.kpi.ua/` |
 
Таймаут запиту 15 с, ресурсу 30 с. Для запитів вимкнено HTTP/3 (`assumesHTTP3Capable = false`).
 
## 2. Компоненти
 
| Компонент | Відповідальність |
|---|---|
| `ScheduleAPIService` (протокол) | Контракт мережевого сервісу: `fetchGroups()`, `fetchSchedule(groupId:)` |
| `APIClient` | Єдине місце з `URLSession`: запит, перевірка статусу, декодування |
| `MockScheduleAPIService` | Підміна сервісу для режимів `-api-mode` і тестів |
| `NetworkError` | Типізовані помилки з текстом для користувача |
| `CampusPair`, `CampusDay`, `CampusScheduleResponse`, `CampusGroup` | `Codable`-моделі відповіді API |
| `CampusScheduleMapper` | `CampusPair` → `LessonDTO`; позначає ймовірні вибіркові предмети (`markElectives`) |
| `LessonDTOAdapter` | `LessonDTO` → `DailySchedule` / `Lesson` |
| `RemoteScheduleRepository` | Кеш на диску й оновлення з API через `ScheduleAPIService` |
| `ScheduleViewModel` | Стани екрана (`isLoading`, `refreshError`, `hasSchedule`) |
 
`URLSession` і `ScheduleAPIService` передаються через `init`, тому в тестах їх можна підмінити (URLProtocol-заглушка, `MockScheduleAPIService`).
 
## 3. Потік даних
 
```
ContentView / HomeView
        │ (стан, дії)
        ▼
ScheduleViewModel  (@MainActor, async/await)
        │ refreshSchedule(for:)
        ▼
RemoteScheduleRepository ──► APIClient ──► api.campus.kpi.ua
        │                        │
        │ запис JSON у кеш       └─ 2xx → Data → Decodable
        ▼
schedule-<id>.json (Documents)
        │ fetchWeeklySchedule(for:)
        ▼
CampusScheduleMapper → LessonDTOAdapter → [DailySchedule] → UI
```
 
1. ViewModel викликає `refreshSchedule(for:)` у репозиторію.
2. Репозиторій знаходить `id` групи в кеші груп і викликає `APIClient`.
3. Відповідь зберігається у файл кешу. UI читає розклад із кешу через `fetchWeeklySchedule(for:)`, мапер і адаптер.
4. Оновлення UI виконується на `@MainActor`, інтерфейс під час запиту не блокується.
## 4. Обробка помилок
 
Статус відповіді перевіряється **до** декодування: дані вважаються успішними лише для коду 2xx.
 
| Помилка | Коли виникає | Повідомлення користувачу |
|---|---|---|
| `transportError` | немає мережі, таймаут, обрив з'єднання | «Немає з'єднання з сервером. Перевірте інтернет і спробуйте ще раз.» |
| `invalidHTTPStatus(code)` | статус поза 200–299 | «Сервер відповів помилкою (код N). Спробуйте пізніше.» |
| `decodingError` | відповідь не збігається з моделлю | «Сервер повернув дані в неочікуваному форматі.» |
| `invalidURL` | не вдалося побудувати URL або знайти групу | «Неправильна адреса запиту.» |
 
Додатково:
- **Повтор при обриві.** Якщо з'єднання обірвалось (`-1005`, `networkConnectionLost`), `APIClient` один раз повторює запит.
- **Скасування.** `URLError.cancelled` перетворюється на `CancellationError`, а не на помилку для користувача.
- **Два формати груп.** `fetchGroups()` приймає і масив, і обгортку `{"data": [...]}`.
## 5. Кеш
 
| Що | Де | Коли оновлюється |
|---|---|---|
| Список груп | `Documents/groups-cache.json` | `refreshGroups()` |
| Розклад групи | `Documents/schedule-<id>.json` | `refreshSchedule(for:)` |
 
- Файли записуються атомарно.
- Перед першим успішним запитом у кеші груп лежить група за замовчуванням (ІО-42, `id: 4382`).
- Якщо оновлення не вдалося, але є кеш, показується збережений розклад із банером «Повторити».
- Якщо кешу немає, а запит невдалий, показується екран помилки з кнопкою «Спробувати ще раз».
## 6. Стани екрана розкладу
 
| Стан | Що бачить користувач |
|---|---|
| Завантаження | індикатор завантаження |
| Дані  | розклад по днях |
| Порожній результат | «Розклад порожній» |
| Помилка без кешу | повідомлення про помилку + «Спробувати ще раз» |
| Помилка з кешем | збережений розклад + банер «Повторити» |
 
Додатково працює pull-to-refresh.
 
## 7. Як перевірити стани
 
**Реальний запит:** звичайний запуск (потрібен інтернет).
 
**Керовані сценарії без залежності від API:** Xcode → Product → Scheme → Edit Scheme → Run → Arguments Passed On Launch → `-api-mode <режим>`.
 
| Режим | Що відтворює |
|---|---|
| `success` | успішна відповідь із тестовими даними |
| `empty` | порожня відповідь → «Розклад порожній» |
| `offline` | транспортна помилка → екран помилки + «Спробувати ще раз» |
| `http500` | HTTP 500 |
| `badjson` | помилка декодування |
| `flaky` | перший запит падає, повтор по кнопці успішний |
 
У цих режимах використовується окремий тимчасовий кеш, справжні дані не чіпаються. Без аргументу застосунок працює з реальним API.
 
## 8. Автотести
 
`kpi-scheduleTests/NetworkTests.swift`:
- `APIClient` з URLProtocol-заглушкою: успіх, статус до декодування, зламаний JSON, транспортна помилка;
- усі стани `ScheduleViewModel` через `MockScheduleAPIService`.
## 9. «Спец. пари» (поле `dates`)
 
Якщо в парі з API є список `dates`, вона йде лише в ці дати, а не щотижня. Дати приводяться до `yyyy-MM-dd` (`LessonDates.normalize`); якщо формат не розпізнається, повертається без змін. На екрані розкладу така пара показується тільки в день, що збігається з однією з дат вибраного тижня, з підписом «Спец. заняття · N з M» і наступними датами. «Головна» теж не пропонує її в інші дні.