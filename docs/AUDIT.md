# GoHabit — аудит архитектуры (Phase One)

Дата: 2026-10-09. Ветка: `main` @ `2eeb217`. Flutter 3.35.2, Supabase CLI 2.75.0, Docker недоступен.

Обозначения: **[факт]** — проверено в коде, **[вывод]** — реконструировано по косвенным признакам, **[?]** — открытый вопрос.

---

## 1. Архитектура и зависимости

```
main.dart
 ├─ dotenv.load()  (.env упакован как asset)
 ├─ Supabase.initialize(url, anonKey)
 ├─ HabitCardSettingsBloc(SharedPreferences)          ← глобальный MultiBlocProvider
 └─ App → AppScopeHolder (yx_scope DI)
     └─ LanguageScope → MaterialContext
         └─ ThemeScope → AuthScope → HabitCategoriesScope → HabitsScope → MaterialApp.router
                                                                         └─ RootPage (StatefulShellRoute)
                                                                             └─ HomeScope → HabitStatsScope → ветки

AppScopeContainer (lib/feature/initizialization/scopes/app_scope_container.dart)
 ├─ AppDatabase (Drift)  → HabitsDao / HabitCategoryDao / HabitCompletionDao / HabitStreakDao
 ├─ Supabase.instance.client (глобальный синглтон, не через DI)
 ├─ HabitsRepositoryImplementation(local, remote, AppConnect)
 ├─ HabitCategoryRepositoryImplementation(local, remote, AppConnect)
 ├─ HabitStatsRepositoryImplementation(local, remote, AppConnect)
 ├─ AuthenticationRepositoryImpl()  (сам берёт Supabase.instance)
 └─ QuoteRepositoryImplementation(Dio → zenquotes.io)
```

Слои: `feature/<x>/{bloc|domain/bloc, data/{data_sources,repositories,models}, domain/{repositories,models}, view, widget}`.
Соглашение соблюдается непоследовательно (модель `Habit` лежит в `data/models`, `HabitCompletion` — в `domain/models`).

**Важно [факт]:** `HabitsBloc`, `HabitCategoryBloc`, `AuthBloc` создаются над роутером, т.е. **до** аутентификации и живут всё время работы приложения. `HabitsBloc` в конструкторе сразу вызывает `getHabits()` → полный sync → `currentUser!`.

## 2. Инвентарь функций

| Функция | Статус | Где |
|---|---|---|
| Регистрация / вход (email+пароль) | ✅ работает | `feature/auth` |
| Восстановление сессии | ✅ через `currentUser` + `onAuthStateChange` | `AuthBloc` |
| Выход | ⚠️ не очищает локальную БД | `AuthBloc._onLogoutButtonPressed` |
| Восстановление пароля | ❌ только значение enum `AuthRoutes.forgotPassword`, экрана нет | `routes_enum.dart:10` |
| Создание привычки | ✅ | `HabitsBloc.AddHabit` |
| Редактирование | ⚠️ событие `UpdateHabit` есть, в UI не вызывается | — |
| Архивация (`is_active`) | ✅ переключатель | `ToggleActiveHabit` |
| Удаление | ✅ (с багами при офлайне) | `DeleteHabit` |
| Категории | ✅ только чтение, глобальный справочник с сервера + захардкоженный fallback | `HabitCategoryError` |
| Отметка выполнения за сегодня / отмена | ⚠️ через `habit.last_completed_time` + «дата-сентинел» `2023-03-31` | `FinishHabit`/`UnFinishHabit` |
| История выполнений (сетка 5×20) | ⚠️ только чтение с сервера, клиент записи не создаёт | `HabitStatsBloc`, `habit_stats_grid.dart` |
| Стрики | ❌ таблицы есть, логики нет (`saveStreak` → `UnimplementedError`) | `habit_stats` |
| Расписания / повторения | ❌ нет (все привычки ежедневные) | — |
| XP / уровни / достижения | ❌ нет (только тип моковой нотификации) | — |
| Уведомления | ❌ 4 захардкоженных мока | `notifications_screen.dart` |
| Профиль | ⚠️ только email из сессии, профиля в БД нет | `ProfileBloc` |
| Тема / язык / вид карточки | ✅ SharedPreferences, только локально | `theme_cubit`, `language_*`, `habit_card_settings_bloc` |
| Цитата дня | ✅ внешнее API zenquotes.io | `feature/home` |
| Поле `steps` | ❌ есть в схемах, нигде не устанавливается | — |

## 3. Локальная схема (Drift, `schemaVersion = 1`, миграций нет)

| Таблица | Колонки | Замечания |
|---|---|---|
| `habits` | `id TEXT PK`, `title`, `description?`, `last_time_completed?`, `created_at`, `updated_at`, `category_id → habit_categories.id`, `is_pending_sync`, `steps`, `is_active`, `sync_status TEXT ('add'/'update'/'delete'/'synced')`, `icon` | нет `user_id`; DateTime хранится как unix-секунды (локальное время) |
| `habit_categories` | `id TEXT PK`, `name`, `color (6–7)` | кэш справочника |
| `habit_completions` | `id INT autoincrement`, `habit_id → habits`, `date_complete DATETIME` | id смешивается с серверными `int` id; нет уникальности по дню |
| `habit_streaks` | `id INT autoincrement`, `habit_id`, `current_streak`, `last_update` | не используется |

## 4. Восстановленная удалённая схема (как её ожидает клиент) [вывод]

| Таблица | Колонки, на которые опирается код | Источник |
|---|---|---|
| `habit` | `id uuid/text` (генерирует клиент, UUIDv4), `user_id`, `title`, `description`, `last_completed_time`, `category_id`, `created_at`, `updated_at`, `is_active`, `steps`, `icon` | `Habit.toJson`, `SupabaseHabitDataSource` |
| `category` | `id text`, `name`, `color` — без `user_id`, читается целиком | `SupabaseHabitCategoryDataSource`, fallback-список: `art, education, health, money, selv-development, sport, work` |
| `habit_completion` | `id int` (serial), `habit_id`, `user_id`, `date_complete timestamptz` | `HabitCompletionModel.fromJson`, `fetchAllCompletions` |
| `habit_streak` | `id int`, `habit_id`, `user_id`, `current_streak`, `last_update` | `fetchStreak` (не вызывается из UI) |

**Ключевой вывод:** клиент **никогда** не пишет в `habit_completion` (`trackCompletion` нигде не вызывается), но экран истории читает из неё. Значит, на старом сервере был триггер на `habit.last_completed_time` → `habit_completion`. Закомментированный SQLite-триггер в `drift_database.dart` — его копия. С учётом сентинела `2023-03-31` при «отмене» такой триггер, скорее всего, **не удалял** сегодняшнюю запись (вставлял запись на 2023-03-31).

RLS, RPC, storage, realtime-публикации — в репозитории нет никаких следов; `supabase/` отсутствует.

## 5. Аутентификация и авторизация

- Supabase Auth, email+пароль. Сессия персистится SDK `supabase_flutter`.
- `SplashScreen` ждёт первый переход из `AuthInitial` и через 2.5 с делает `go()`; **глобального redirect в GoRouter нет** — после logout/истечения сессии пользователь остаётся на защищённых экранах, пока UI сам не уведёт (`settings_section.dart` после logout).
- Ошибки маппятся по `statusCode` в русские строки прямо в BLoC (нет локализации).
- `ProfileBloc` держит ссылку на `AuthBloc` и ходит в `Supabase.instance` напрямую.
- Авторизация данных на клиенте — `.eq('user_id', currentUser!.id)`. Без RLS на сервере это не защита: `getHabitById`, `updateHabit`, `deleteHabit` фильтруют только по `id`.
- `user_id` передаётся клиентом в теле запроса — сервер обязан его проверять/подставлять.

## 6. Текущая синхронизация (`HabitsRepositoryImplementation`)

- Запись: локально → если `connectivity != none` — сразу в Supabase → `markHabitAsSynced`; при ошибке → `markHabitAsPendingSync`.
- `_fullSync`: push pending → pull всё → сравнение `updated_at` (LWW) → «есть локально, нет на сервере и не pending ⇒ удалить локально» → снова push pending.
- Триггеры: конструктор `HabitsBloc` (`getHabits`) и каждое событие `onConnectivityChanged == true`.
- Категории: pull-only. Выполнения: pull-only, полная перезапись при каждом `getAllCompletions`. Стрики: не синхронизируются.

## 7. Критические баги и уязвимости

| # | Severity | Проблема | Место |
|---|---|---|---|
| C1 | 🔴 потеря данных | `Habit.fromDriftModel` не переносит `sync_status` → у всех локальных привычек `SyncStatus.synced`. Как следствие: `syncPendingOperations` **никогда ничего не отправляет** (`default: continue`), а `_fullSync` шаг 4 **удаляет локально все привычки, созданные офлайн** (они «есть локально, нет на сервере, не pending»). | `habit.dart:73`, `habit_repository_implementation.dart:184-199` |
| C2 | 🔴 утечка данных | Logout не очищает Drift; в БД нет `user_id`. Пользователь B видит привычки и историю пользователя A до синка, а pending-изменения A могут уйти на сервер **под аккаунтом B** (`user_id` подставляется из текущей сессии). | `AuthBloc`, `remote_habit_data_source.dart:48` |
| C3 | 🔴 безопасность | Нет миграций/RLS в репо; доступ к чужим записям ограничивается только клиентским `.eq('user_id')`. При пересоздании бэкенда «как было» — IDOR по `id`. | весь remote слой |
| C4 | 🔴 крэш | `currentUser!` в remote-источниках; `HabitsBloc` стартует до логина и на каждое изменение сети → `Null check operator` (ловится и превращается в `HabitsOperationFailure`). | remote datasources |
| C5 | 🟠 логика | Отмена выполнения пишет фиктивную дату `2023-03-31`; «сегодня» определяется как `difference().inDays == 0` (= «меньше 24 часов назад», а не «тот же календарный день»). Выполнение в 23:50 считается «сегодня» до 23:49 следующего дня. | `habits_bloc.dart:127`, `habit_card.dart:168`, `habit_home_card.dart:80` |
| C6 | 🟠 логика | Выполнение не создаёт запись истории локально → офлайн-отметки не видны в истории и теряются при следующем полном pull. | `habits_bloc.dart:111` |
| C7 | 🟠 sync | `markHabitAsSynced` → `updateHabit` всегда ставит `updated_at = now()` → локальная версия «всегда новее» → бесконечный пинг-понг push'ей и затирание чужих правок (LWW на клиентских часах). | `habits_dao.dart:43` |
| C8 | 🟠 sync | Применение серверной версии идёт через `_localDataSource.updateHabit`, который ставит `isPendingSync=true, sync_status='update'`. | `local_habit_data_source.dart:57` |
| C9 | 🟠 sync | Офлайн-удаление: привычка помечается `delete`, но остаётся в стриме UI; онлайн-удаление при ошибке сервера не ставит pending. Удаление привычки с выполнениями нарушит FK. | `habit_repository_implementation.dart:94` |
| C10 | 🟠 данные | `saveHabit` / `_toCompanion` теряют `steps`, `icon`, `created_at`, `last_completed_time` при сохранении серверных записей. `copyWith` теряет `lastCompletedTime` (`lastCompletedTime ?? lastCompletedTime`). | `local_habit_data_source.dart:26,126`, `habit.dart:63` |
| C11 | 🟡 | `isHabitCompletedOnDate` всегда `true` (сравнение `Future` с `null`) — подтверждено анализатором. | `habit_completion_dao.dart:56` |
| C12 | 🟡 | `getStreak` возвращает незавершённый `Future` из `try` — ошибки не ловятся. `fetchAllCompletions` — аналогично. | stats repo/datasource |
| C13 | 🟡 | `HabitStatsBloc.close()` и `HabitsBloc.close()` вызывают `repository.dispose()` у синглтона из DI — отписка от сети для всего приложения. | blocs |
| C14 | 🟡 | `connectivity != none` ≠ доступность Supabase; нет retry/backoff, нет защиты от параллельных `_fullSync` (каждое событие сети + каждый `getHabits`). | `app_connect.dart` |
| C15 | 🟡 | CI переписывает `analysis_options.yaml` и игнорирует `undefined_*` ошибки — анализ в CI фактически отключён. | `.github/workflows` |

## 8. Технический долг (по убыванию)

1. Модель выполнения через `last_completed_time` вместо явных событий выполнения (корень C5/C6, требует серверного триггера).
2. Отсутствие владельца данных в локальной БД и очистки при смене аккаунта.
3. Самописный sync без outbox/идемпотентности, с LWW на клиентских часах.
4. Нет `supabase/` (миграции, RLS, seed, тесты).
5. Нет Drift-миграций и тестов апгрейда (`schemaVersion = 1`, мёртвые таблицы).
6. Строки ошибок захардкожены в BLoC'ах; `Exception('...$e')` вместо типизированных ошибок.
7. Нет auth-redirect в роутере; `Supabase.instance` вне DI.
8. Мёртвый код: `habit_streaks`, `HabitStatsRepository.saveX`, `Config`/`Environment`, `UpdateHabit` без UI, закомментированные триггеры.
9. CI: «ослабленный» analyze, golden-тесты зависят от версии Flutter/платформы.

## 9. Состояние проверок (до изменений)

| Команда | Результат |
|---|---|
| `flutter analyze` | 165 issues: 0 errors, 12 warnings (5 в `*.mocks.dart`), 153 info |
| `flutter test` | 35 passed, **3 failed** — все golden (`habit_card_*.png`, дифф 2–22 %; вероятно, смена версии Flutter, не регрессия) |
| Supabase local / pgTAP | **не запускалось**: нет Docker |

---

## 10. План реализации

### Предлагаемая целевая схема (черновик, до подтверждения)

```
category          (id text PK, name, color, sort_order)                 — справочник, read-only для authenticated
habit             (id uuid PK [client], user_id → auth.users ON DELETE CASCADE,
                   category_id → category, title, description, icon, steps,
                   is_active, created_at, updated_at, deleted_at)       — soft delete (tombstone) для синка
habit_completion  (id uuid PK [client], user_id, habit_id → habit ON DELETE CASCADE,
                   completed_on date, created_at, updated_at, deleted_at,
                   UNIQUE (habit_id, completed_on))                     — идемпотентно: upsert по (habit_id, completed_on)
profile           (id = auth.users.id PK, display_name?, created_at, updated_at) — создаётся триггером on auth.users insert
```

- `habit_streak` на сервере **не создаётся**: стрик — производная от `habit_completion`, считается в Dart.
- `last_completed_time` удаляется из модели как источник истины (UI будет вычислять «выполнено сегодня» по выполнениям).
- `updated_at` выставляет сервер триггером; `user_id` по умолчанию `auth.uid()`, RLS `WITH CHECK (user_id = auth.uid())`, запрет смены владельца; `habit_completion` дополнительно проверяет, что `habit_id` принадлежит тому же пользователю.
- `completed_on date` — календарный день в часовом поясе пользователя (вычисляется на клиенте).

### Порядок работ

1. **Backend:** `supabase init`, миграции (схема, триггеры, RLS, grants), `seed.sql` с 7 категориями, pgTAP-тесты RLS. Без Docker — только статическая проверка; прогон — у вас/в CI.
2. **Drift v2:** добавить `owner_user_id`, `deleted_at`, `completed_on`, outbox-флаги на выполнения; миграция v1→v2 с сохранением данных (перенос `last_time_completed` в запись выполнения); тест апгрейда.
3. **Sync:** единый `SyncService` (push dirty → pull по `updated_at > cursor` → применение без пометки dirty), мьютекс, backoff, обработка 401/истёкшей сессии, очистка/изоляция данных при смене пользователя.
4. **Flutter:** исправить C1–C14, auth-redirect в GoRouter, типизированные ошибки, `Supabase` через DI.
5. **Тесты:** unit (стрики, «сегодня», маппинг), repository/sync (офлайн, ретраи, смена аккаунта), bloc_test, Drift-миграция; golden — перегенерировать после подтверждения.
6. **Docs/CI:** `docs/BACKEND.md`, `.env.example`, честный `flutter analyze` в CI.

---

## 11. Статус после реализации (2026-10-09)

| # | Статус | Как решено |
|---|---|---|
| C1 | ✅ | Самописный `sync_status` заменён на `is_pending_sync` + `local_version`; `SyncService` отправляет pending-строки и никогда не удаляет неотправленные данные. Тесты: `test/core/sync/` |
| C2 | ✅ | `sync_state.owner_user_id`; смена аккаунта очищает данные до синхронизации; выход: sync → подтверждение → signOut → очистка |
| C3 | ✅ | `supabase/migrations` с RLS и привилегиями; 48 pgTAP-проверок |
| C4 | ✅ | Нет `currentUser!`: синхронизация идёт только при активной сессии, ответы для прежней сессии отбрасываются |
| C5 | ✅ | `habit_completion` по календарным дням (`CalendarDay`); сентинел `2023-03-31` удалён |
| C6 | ✅ | Отметка пишет запись выполнения локально (офлайн) и синхронизирует её |
| C7, C8 | ✅ | `updated_at` ставит сервер; применение серверных строк не помечает их как изменённые |
| C9 | ✅ | Удаление — tombstone, сразу скрыт из UI, сервер каскадно помечает выполнения |
| C10 | ✅ | Все поля переносятся; `copyWith` исправлен |
| C11, C12 | ✅ | Код удалён вместе с серверными стриками и прямыми remote-вызовами из репозиториев |
| C13 | ✅ | `dispose()` у синглтон-репозиториев убран из BLoC'ов |
| C14 | ✅ | Мьютекс, debounce, backoff до 5 мин, таймаут 30 с; сеть проверяется, но ошибки запроса тоже обрабатываются |
| C15 | ✅ | CI использует `analysis_options.yaml` (с исключением сгенерированного кода), добавлен job `supabase test db` |

Не сделано (вне объёма, функциональность не существовала): восстановление пароля, расписания, XP/достижения,
реальные уведомления, отображение стриков в UI (функция `currentStreak` и `HabitStatsLoaded.streakOf` готовы).
