# Бэкенд GoHabit (Supabase)

Весь бэкенд описан кодом в `supabase/` и воспроизводится на чистом проекте без ручных правок в Dashboard,
кроме настроек Auth на удалённом проекте (см. «Деплой»).

```
supabase/
  config.toml                         локальный стек и настройки Auth
  migrations/
    20261009120000_core_schema.sql    таблицы, ограничения, индексы, триггеры, справочник категорий
    20261009120100_rls_policies.sql   привилегии и RLS
  seed.sql                            dev-seed (намеренно пустой)
  tests/database/*.test.sql           pgTAP: структура, RLS, изоляция пользователей, каскады
```

## Схема

| Таблица | Назначение | Владелец | Удаление |
|---|---|---|---|
| `category` | справочник категорий (7 строк из миграции) | общий, только чтение | — |
| `profile` | профиль: никнейм (уникален без учёта регистра), аватар, описание, `public_id`, настройки приватности; создаётся триггером `on_auth_user_created` | `id = auth.users.id` | каскадом с `auth.users` |
| `habit` | определение привычки | `user_id → auth.users` | tombstone `deleted_at` (необратим) |
| `habit_completion` | выполнение привычки за календарный день | `user_id`, `(habit_id, user_id) → habit` | tombstone `deleted_at` (снимается при повторной отметке) |
| `habit_template` | каталог привычек = сообщества (16 строк из миграции) | общий, только чтение (`authenticated`) | не удаляется, `is_active = false` |
| `community_membership` | участие в сообществе; необязательная привычка для рейтинга, созданная по шаблону | `user_id`, `(habit_id, user_id) → habit` | клиент удаляет свою строку (выход); привычка остаётся |
| `friendship` | одна строка на пару: заявка (`pending`) или дружба (`accepted`) | только через функции | удаляется при отклонении, отмене, удалении из друзей, блокировке |
| `user_block` | блокировки | только через функции | клиент снимает блокировку |

Ключевые решения:

- **ID генерирует клиент** (UUIDv4 для привычек, детерминированный UUIDv5 от `habit_id/день` для выполнений) — записи создаются офлайн, а повторы и разные устройства сходятся к одной записи.
- **`UNIQUE (habit_id, completed_on)`** — одно выполнение на день; upsert по этому ключу идемпотентен.
- **Составной FK `(habit_id, user_id) → habit(id, user_id)`** — выполнение физически не может ссылаться на чужую привычку.
- **`updated_at` ставит сервер** (`clock_timestamp()`), значение от клиента игнорируется. Это курсор инкрементального pull.
- **`user_id` по умолчанию `auth.uid()`**, клиент его не отправляет; смена владельца запрещена триггером.
- **Tombstone привычки** каскадно помечает её выполнения; выполнение, записанное для уже удалённой привычки, сохраняется как tombstone.
- Стрики и статистика **не хранятся** — вычисляются в приложении из `habit_completion`, расписания привычки (`schedule_type`, `weekly_target`, `schedule_days`) и границы сброса `streak_reset_on`. Подробности — `docs/SCHEDULES.md`.
- Рейтинг сообществ не хранится: его считает `community_leaderboard` на сервере. Подробности — `docs/COMMUNITIES.md`.
- Профили, друзья, блокировки и приватность — `docs/SOCIAL.md`.

## Безопасность

- RLS включена на всех таблицах `public` (тест проверяет, что таблиц без RLS нет).
- `anon`: только `SELECT` из `category`.
- `authenticated`: `SELECT/INSERT/UPDATE` своих строк `habit`, `habit_completion`; `SELECT` и `UPDATE (display_name)` своего `profile`.
- `DELETE` клиентам не выдан: удаление — это tombstone, иначе его нельзя синхронизировать.
- Trigger-функции с `search_path = ''`; `handle_new_user` — `security definer`, `EXECUTE` отозван у клиентских ролей.
- В приложении только URL и publishable/anon-ключ. Ключ — идентификатор клиента, а не защита: авторизацию обеспечивают RLS и привилегии.

## Локальная разработка

Нужны: Flutter ≥ 3.35, Docker, Supabase CLI ≥ 2.75 (`brew install supabase/tap/supabase`).

```bash
# 1. Зависимости и кодогенерация
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# 2. Локальный Supabase (миграции применяются автоматически)
supabase start
supabase status -o env          # API_URL и PUBLISHABLE_KEY / ANON_KEY для .env

# 3. Конфиг приложения
cp .env.example .env            # вписать значения из шага 2

# 4. Пересоздать БД с нуля: миграции + seed.sql (только локально!)
supabase db reset

# 5. Тесты безопасности и схемы (pgTAP)
supabase test db

# 6. Статический анализ схемы
supabase db lint

# 7. Flutter
flutter analyze
flutter test                    # golden-тесты (test/widget) отрисованы на macOS
```

Эмулятор Android обращается к хосту по `10.0.2.2`, а не `127.0.0.1` — используйте `SUPABASE_URL=http://10.0.2.2:54321`.

Типы БД не генерируются: `supabase gen types` поддерживает TypeScript/Go/Swift, не Dart. Контракт с клиентом
задаётся в `lib/core/sync/sync_remote_api.dart` (`RemoteHabit.columns`, `RemoteCompletion.columns`).

## Деплой на новый удалённый проект

> Не выполняйте `db push` в проект, который вы не создавали для этого: сначала убедитесь в `project-ref`.

```bash
supabase login
supabase link --project-ref <project-ref>   # запросит пароль БД, он не сохраняется в репозитории
supabase db push --dry-run                  # показать, какие миграции будут применены
supabase db push                            # применить
supabase migration list                     # сверить локальные и удалённые миграции
supabase config push                        # перенести настройки [auth] из config.toml (покажет diff и спросит)
```

После `config push` проверьте в Dashboard → Authentication:

- **Site URL / Redirect URLs** — сейчас в `config.toml` локальные значения; для продакшена укажите свои.
- **Email confirmations** — локально выключены (`enable_confirmations = false`). Если включить, после регистрации
  после регистрации приложение покажет экран «Проверьте почту»; войти можно после перехода по ссылке.
- **Password requirements** — `letters_digits`, соответствует подсказке в форме регистрации.

**Если `db push` падает с `failed to connect … db.<ref>.supabase.co … socket is not connected`** — прямой адрес базы
доступен только по IPv6, а сеть его не поддерживает. Используйте pooler (IPv4), строка есть в Dashboard → Connect;
спецсимволы пароля нужно percent-encode (`@` → `%40`):

```bash
supabase db push --db-url "postgresql://postgres.<project-ref>:<password>@aws-0-<region>.pooler.supabase.com:5432/postgres"
```

Проверка без пароля, через публичный REST API: `category` отдаёт 7 строк, а `habit` для `anon` отвечает `42501`:

```bash
curl -s "https://<project-ref>.supabase.co/rest/v1/category?select=id" -H "apikey: <publishable-key>"
curl -s "https://<project-ref>.supabase.co/rest/v1/habit?select=id"    -H "apikey: <publishable-key>"
```

`seed.sql` в удалённый проект не попадает (`db push` без `--include-seed`), справочник категорий приходит миграцией.

## Ссылки из писем (подтверждение email, сброс пароля)

Приложение просит Supabase вернуть пользователя по адресу `gohabit://auth-callback` (`authCallbackUrl` в
`authentication_repository_impl.dart`). Схема зарегистрирована в `ios/Runner/Info.plist` и
`android/app/src/main/AndroidManifest.xml`; ссылку обрабатывает `supabase_flutter` (PKCE), а router открывает экран
нового пароля при событии `passwordRecovery`.

Чтобы это работало на удалённом проекте, добавьте адрес в Dashboard → Authentication → URL Configuration →
**Redirect URLs**: `gohabit://auth-callback`. Пока его нет, Supabase игнорирует `redirectTo` и ведёт на Site URL: письмо
подтверждения всё равно подтвердит адрес (после чего пользователь входит вручную), а сброс пароля из приложения
завершить не получится.

Ссылка работает только на том устройстве, где её запросили (PKCE хранит verifier локально), и ограничена по времени.
Просроченная или чужая ссылка показывается на экране входа как «Ссылка недействительна или устарела».

Лимит писем (`over_email_send_rate_limit`) на встроенном SMTP Supabase очень маленький — для продакшена подключите свой
SMTP (Dashboard → Authentication → SMTP Settings). Приложение показывает понятное сообщение и даёт повторить отправку не
чаще раза в минуту.

## Изменение схемы

1. `supabase migration new <name>` → SQL в новом файле; уже применённые миграции не редактируются.
2. Тест в `supabase/tests/database/`, затем `supabase db reset && supabase test db`.
3. Если меняется контракт с клиентом — обновить `RemoteHabit`/`RemoteCompletion` и `FakeSyncRemoteApi` в тестах.
4. Если меняется локальная схема Drift — повысить `schemaVersion`, написать миграцию и обновить снимки
   (команды в `test/core/database/migration_test.dart`).
