// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get welcome_back => 'С возвращением в Go Habit';

  @override
  String get dont_have_account => 'Нет аккаунта? Зарегистрироваться';

  @override
  String get registration => 'Регистрация';

  @override
  String get register => 'Зарегистрироваться';

  @override
  String get sign_in => 'Войти';

  @override
  String get create_account => 'Создайте аккаунт в Go Habit';

  @override
  String get already_have_account => 'Уже есть аккаунт? Войти';

  @override
  String welcomeMessage(String email) {
    return 'Добро пожаловать, $email!';
  }

  @override
  String get app_description_title => 'Приложение Go Habit поможет вам:';

  @override
  String get habit_tracking_feature =>
      'Отслеживайте ваши привычки и серию их выполнения!';

  @override
  String get daily_habits_feature =>
      'Создавайте и отслеживайте ежедневные привычки для достижения целей';

  @override
  String get analytics_feature => 'Анализ прогресса в виде графиков и кубиков!';

  @override
  String get visualization_feature =>
      'Визуализируйте свой прогресс и получайте мотивацию';

  @override
  String get reminders_feature => 'Получать напоминания и мотивационные фразы!';

  @override
  String get notifications_feature =>
      'Настраивайте уведомления, чтобы не забывать о своих привычках';

  @override
  String get widgets_feature =>
      'Виджеты для ваших привычек прямо на главном экране!';

  @override
  String get customWidgets_feature =>
      'Настраивайте виджеты, которые хотите видеть на главном экране';

  @override
  String get start_tracking_button => 'Начать отслеживание привычек';

  @override
  String get password_label => 'Пароль';

  @override
  String get password_required => 'Пожалуйста, введите пароль';

  @override
  String get password_length => 'Пароль должен содержать минимум 6 символов';

  @override
  String get confirm_password_label => 'Подтвердите пароль';

  @override
  String get confirm_password_required => 'Пожалуйста, подтвердите пароль';

  @override
  String get passwords_dont_match => 'Пароли не совпадают';

  @override
  String get email_label => 'Email';

  @override
  String get email_required => 'Пожалуйста, введите email';

  @override
  String get email_invalid => 'Пожалуйста, введите корректный email';

  @override
  String get auth_sign_in_subtitle =>
      'Войдите, чтобы продолжить свои серии привычек';

  @override
  String get auth_sign_up_subtitle => 'Всё, что нужно, — email и пароль';

  @override
  String get auth_forgot_password => 'Забыли пароль?';

  @override
  String get auth_no_account => 'Нет аккаунта?';

  @override
  String get auth_create_account_action => 'Зарегистрироваться';

  @override
  String get auth_have_account => 'Уже есть аккаунт?';

  @override
  String get email_hint => 'name@example.com';

  @override
  String get password_show => 'Показать пароль';

  @override
  String get password_hide => 'Скрыть пароль';

  @override
  String get password_letters_digits => 'Пароль должен содержать буквы и цифры';

  @override
  String get password_req_length => 'Не менее 6 символов';

  @override
  String get password_req_letters_digits => 'Буквы и цифры';

  @override
  String get auth_check_email_title => 'Проверьте почту';

  @override
  String auth_confirm_email_message(String email) {
    return 'Мы отправили письмо со ссылкой для подтверждения на $email. Перейдите по ссылке, а затем войдите в аккаунт.';
  }

  @override
  String get auth_check_email_hint =>
      'Нет письма? Проверьте папку «Спам». Если аккаунт с этим адресом уже есть, просто войдите или восстановите пароль.';

  @override
  String get auth_resend_email => 'Отправить письмо ещё раз';

  @override
  String auth_resend_in(int seconds) {
    return 'Отправить ещё раз через $seconds с';
  }

  @override
  String get auth_email_resent => 'Письмо отправлено ещё раз';

  @override
  String get auth_back_to_sign_in => 'Вернуться ко входу';

  @override
  String get auth_reset_title => 'Восстановление пароля';

  @override
  String get auth_reset_subtitle =>
      'Укажите email аккаунта — мы пришлём ссылку для сброса пароля';

  @override
  String get auth_reset_send => 'Отправить ссылку';

  @override
  String auth_reset_sent_message(String email) {
    return 'Если аккаунт с адресом $email существует, мы отправили на него ссылку для сброса пароля.';
  }

  @override
  String get auth_reset_sent_hint =>
      'Откройте письмо на этом устройстве — ссылка откроется в приложении. Она действует ограниченное время.';

  @override
  String get auth_new_password_title => 'Смена пароля';

  @override
  String get auth_new_password_subtitle =>
      'Придумайте новый пароль для своего аккаунта';

  @override
  String get auth_new_password_label => 'Новый пароль';

  @override
  String get auth_new_password_save => 'Сохранить пароль';

  @override
  String get auth_password_updated => 'Пароль обновлён';

  @override
  String get auth_later => 'Позже';

  @override
  String get auth_error_invalid_credentials =>
      'Неверный email или пароль. Проверьте данные или восстановите пароль.';

  @override
  String get auth_error_email_not_confirmed =>
      'Email ещё не подтверждён. Перейдите по ссылке из письма, которое пришло после регистрации.';

  @override
  String get auth_error_user_exists =>
      'Аккаунт с этим email уже существует. Войдите или восстановите пароль.';

  @override
  String get auth_error_weak_password =>
      'Пароль слишком простой. Нужно не менее 6 символов, буквы и цифры.';

  @override
  String get auth_error_same_password =>
      'Новый пароль должен отличаться от текущего.';

  @override
  String get auth_error_invalid_email =>
      'Этот email не подходит. Проверьте адрес.';

  @override
  String get auth_error_signup_disabled =>
      'Регистрация сейчас недоступна. Попробуйте позже.';

  @override
  String get auth_error_rate_limited =>
      'Слишком много попыток. Подождите несколько минут и попробуйте снова.';

  @override
  String get auth_error_network =>
      'Не удалось связаться с сервером. Проверьте интернет и попробуйте снова.';

  @override
  String get auth_error_link_invalid =>
      'Ссылка недействительна или устарела. Запросите новую.';

  @override
  String get auth_error_session_expired =>
      'Время на смену пароля истекло. Запросите новую ссылку.';

  @override
  String get auth_error_unknown => 'Что-то пошло не так. Попробуйте ещё раз.';

  @override
  String get communities_title => 'Сообщества';

  @override
  String get communities_tab_catalog => 'Каталог';

  @override
  String get communities_tab_mine => 'Мои';

  @override
  String get communities_intro =>
      'Вступайте в сообщества и участвуйте в недельном рейтинге с привычкой по шаблону — или просто будьте участником. Ваши заметки и остальные привычки остаются личными.';

  @override
  String get communities_search_hint => 'Поиск привычки';

  @override
  String get communities_filter_all => 'Все';

  @override
  String communities_members(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count участников',
      few: '$count участника',
      one: '$count участник',
    );
    return '$_temp0';
  }

  @override
  String get communities_no_members_yet => 'Пока нет участников';

  @override
  String get communities_joined_badge => 'Вы участник';

  @override
  String get communities_empty_search =>
      'Ничего не нашлось. Попробуйте другой запрос или категорию.';

  @override
  String get communities_empty_mine =>
      'Вы пока не состоите ни в одном сообществе.';

  @override
  String get communities_browse_catalog => 'Открыть каталог';

  @override
  String get communities_offline_banner =>
      'Нет соединения — показаны сохранённые данные. Вступать в сообщества и смотреть рейтинг можно только онлайн.';

  @override
  String get communities_load_failed => 'Не удалось загрузить сообщества.';

  @override
  String get communities_retry => 'Повторить';

  @override
  String unit_pages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count страниц',
      few: '$count страницы',
      one: '$count страница',
    );
    return '$_temp0';
  }

  @override
  String unit_minutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count минут',
      few: '$count минуты',
      one: '$count минута',
    );
    return '$_temp0';
  }

  @override
  String unit_steps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count шагов',
      few: '$count шага',
      one: '$count шаг',
    );
    return '$_temp0';
  }

  @override
  String unit_glasses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count стаканов',
      few: '$count стакана',
      one: '$count стакан',
    );
    return '$_temp0';
  }

  @override
  String unit_hours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count часов',
      few: '$count часа',
      one: '$count час',
    );
    return '$_temp0';
  }

  @override
  String community_recommended_target(String target) {
    return 'Рекомендуемая цель: $target за раз';
  }

  @override
  String get community_join => 'Вступить';

  @override
  String get community_leave => 'Покинуть сообщество';

  @override
  String get community_leave_title => 'Покинуть сообщество?';

  @override
  String get community_leave_message =>
      'Привычка для рейтинга останется в вашем списке вместе с историей. Вы исчезнете из рейтинга; если вернётесь, дни до повторного вступления засчитаны не будут.';

  @override
  String get community_leave_confirm => 'Покинуть';

  @override
  String community_member_since(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Вы участник с $dateString';
  }

  @override
  String get community_leaderboard_title => 'Рейтинг прошлой недели';

  @override
  String get community_retired => 'Сообщество закрыто для новых участников.';

  @override
  String get community_joined => 'Вы вступили в сообщество';

  @override
  String get community_left => 'Вы покинули сообщество. Привычка сохранена.';

  @override
  String get community_error_offline =>
      'Нет подключения к интернету. Попробуйте, когда появится сеть.';

  @override
  String get community_error_network =>
      'Не удалось связаться с сервером. Попробуйте ещё раз.';

  @override
  String get community_error_not_allowed =>
      'Сейчас это недоступно: сообщество закрыто.';

  @override
  String get community_error_unauthorized =>
      'Сессия истекла. Войдите в аккаунт заново.';

  @override
  String get community_error_unknown =>
      'Что-то пошло не так. Попробуйте ещё раз.';

  @override
  String get habits_schedule_label => 'Расписание';

  @override
  String get habits_schedule_option_daily => 'Каждый день';

  @override
  String get habits_schedule_option_weekly => 'Цель на неделю';

  @override
  String get habits_schedule_option_weekdays => 'По дням';

  @override
  String get habits_schedule_daily => 'Каждый день';

  @override
  String habits_schedule_times_per_week(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count раз в неделю',
      few: '$count раза в неделю',
      one: '$count раз в неделю',
    );
    return '$_temp0';
  }

  @override
  String habits_schedule_weekly_summary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count раз в неделю, в любые дни',
      few: '$count раза в неделю, в любые дни',
      one: '$count раз в неделю, в любой день',
    );
    return '$_temp0';
  }

  @override
  String get habits_weekly_target_label => 'Сколько раз в неделю';

  @override
  String get habits_weekdays_label => 'Дни недели';

  @override
  String get habits_weekdays_required => 'Выберите хотя бы один день';

  @override
  String get habits_weekday_1 => 'Пн';

  @override
  String get habits_weekday_2 => 'Вт';

  @override
  String get habits_weekday_3 => 'Ср';

  @override
  String get habits_weekday_4 => 'Чт';

  @override
  String get habits_weekday_5 => 'Пт';

  @override
  String get habits_weekday_6 => 'Сб';

  @override
  String get habits_weekday_7 => 'Вс';

  @override
  String habits_streak_weeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count недель подряд',
      few: '$count недели подряд',
      one: '$count неделя подряд',
    );
    return '$_temp0';
  }

  @override
  String habits_streak_occurrences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count раз подряд',
      few: '$count раза подряд',
      one: '$count раз подряд',
    );
    return '$_temp0';
  }

  @override
  String habits_week_target_progress(int done, int goal) {
    return '$done/$goal на этой неделе';
  }

  @override
  String habits_weekdays_progress(int done, int goal) {
    return '$done из $goal дн. на этой неделе';
  }

  @override
  String get habits_not_today => 'Сегодня не по расписанию';

  @override
  String get habits_section_week => 'Цели на неделю';

  @override
  String get habits_section_other_days => 'В другие дни';

  @override
  String habits_week_goals(int done, int total) {
    return 'Цели недели: $done из $total';
  }

  @override
  String get habits_schedule_change_title => 'Изменить тип расписания?';

  @override
  String get habits_schedule_change_message =>
      'Текущая серия начнётся заново: у разных расписаний разные правила серий. История отметок сохранится.';

  @override
  String get habits_schedule_change_confirm => 'Изменить расписание';

  @override
  String social_best_streak_days(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'дней подряд',
      few: 'дня подряд',
      one: 'день подряд',
    );
    return '$_temp0 — лучшая серия';
  }

  @override
  String social_best_streak_weeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'недель подряд',
      few: 'недели подряд',
      one: 'неделя подряд',
    );
    return '$_temp0 — лучшая серия';
  }

  @override
  String social_best_streak_occurrences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'раз подряд',
      few: 'раза подряд',
      one: 'раз подряд',
    );
    return '$_temp0 — лучшая серия';
  }

  @override
  String get habits_title => 'Привычки';

  @override
  String get habits_add => 'Добавить привычку';

  @override
  String habits_actions(String title) {
    return 'Действия с привычкой «$title»';
  }

  @override
  String get habits_category_label => 'Категория';

  @override
  String get habits_category_other => 'Другое';

  @override
  String get habits_delete => 'Удалить';

  @override
  String habits_delete_title(String title) {
    return 'Удалить «$title»?';
  }

  @override
  String get habits_delete_message =>
      'Привычка и вся история её отметок будут удалены на всех устройствах. Если хотите сделать перерыв, поставьте её на паузу — история сохранится.';

  @override
  String get habits_description_label => 'Описание (необязательно)';

  @override
  String get habits_discard => 'Не сохранять';

  @override
  String get habits_discard_message => 'Изменения не сохранены.';

  @override
  String get habits_discard_title => 'Выйти без сохранения?';

  @override
  String get habits_keep_editing => 'Продолжить';

  @override
  String get habits_done_today => 'выполнено сегодня';

  @override
  String get habits_not_done_today => 'не выполнено сегодня';

  @override
  String get habits_edit => 'Редактировать';

  @override
  String get habits_edit_title => 'Редактирование';

  @override
  String get habits_new_title => 'Новая привычка';

  @override
  String get habits_empty_title => 'Начните с первой привычки';

  @override
  String get habits_empty_body =>
      'Маленький ежедневный шаг — и через пару недель он станет частью дня.';

  @override
  String get habits_empty_catalog => 'Выбрать из каталога сообществ';

  @override
  String get habits_error_add =>
      'Не удалось добавить привычку. Попробуйте ещё раз.';

  @override
  String get habits_error_completion =>
      'Не удалось сохранить отметку. Попробуйте ещё раз.';

  @override
  String get habits_error_delete =>
      'Не удалось удалить привычку. Попробуйте ещё раз.';

  @override
  String get habits_error_generic =>
      'Не удалось сохранить изменения. Попробуйте ещё раз.';

  @override
  String get habits_error_load => 'Не удалось загрузить привычки.';

  @override
  String get habits_error_update =>
      'Не удалось сохранить привычку. Попробуйте ещё раз.';

  @override
  String get habits_icon_custom => 'Свой эмодзи';

  @override
  String get habits_icon_label => 'Иконка';

  @override
  String get habits_icon_single => 'Введите один эмодзи';

  @override
  String get habits_loading => 'Загрузка привычек';

  @override
  String get habits_name_label => 'Название';

  @override
  String get habits_name_required => 'Введите название';

  @override
  String habits_nothing_today(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'На сегодня ничего не запланировано: $count привычек на паузе.',
      few: 'На сегодня ничего не запланировано: $count привычки на паузе.',
      one: 'На сегодня ничего не запланировано: $count привычка на паузе.',
    );
    return '$_temp0';
  }

  @override
  String get habits_pause => 'Поставить на паузу';

  @override
  String get habits_paused_label => 'На паузе';

  @override
  String get habits_resume => 'Возобновить';

  @override
  String get habits_section_paused => 'На паузе';

  @override
  String get habits_section_today => 'На сегодня';

  @override
  String habits_streak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дней подряд',
      few: '$count дня подряд',
      one: '$count день подряд',
    );
    return '$_temp0';
  }

  @override
  String get habits_today_all_done => 'Всё на сегодня выполнено 🎉';

  @override
  String get habits_today_loading => 'Считаем прогресс…';

  @override
  String get habits_today_nothing => 'На сегодня ничего не запланировано';

  @override
  String habits_today_progress(int completed, int total) {
    return 'Выполнено $completed из $total';
  }

  @override
  String get social_accept => 'Принять';

  @override
  String get social_add_friend => 'Добавить в друзья';

  @override
  String get social_already_accepted => 'Заявку уже приняли — вы друзья';

  @override
  String get social_avatar_default => 'Пиксельный аватар по никнейму';

  @override
  String get social_avatar_label => 'Аватар';

  @override
  String get social_bio_label => 'О себе';

  @override
  String get social_block => 'Заблокировать';

  @override
  String get social_block_message =>
      'Дружба и заявки между вами будут удалены. Пользователь не сможет найти вас и отправить заявку и не узнает о блокировке.';

  @override
  String get social_block_title => 'Заблокировать пользователя?';

  @override
  String get social_blocked => 'Заблокированные';

  @override
  String get social_cancel_request => 'Отменить заявку';

  @override
  String get social_edit_profile => 'Редактировать профиль';

  @override
  String get social_error_blocked_by_me =>
      'Вы заблокировали этого пользователя. Сначала разблокируйте его.';

  @override
  String get social_error_invalid_profile =>
      'Сервер не принял данные профиля. Проверьте никнейм и описание.';

  @override
  String get social_error_network =>
      'Не удалось связаться с сервером. Попробуйте ещё раз.';

  @override
  String get social_error_not_allowed => 'Это действие недоступно.';

  @override
  String get social_error_not_found => 'Пользователь не найден.';

  @override
  String get social_error_offline =>
      'Нет подключения к интернету. Друзья и профиль меняются только онлайн.';

  @override
  String get social_error_unauthorized =>
      'Сессия истекла. Войдите в аккаунт заново.';

  @override
  String get social_error_unknown => 'Что-то пошло не так. Попробуйте ещё раз.';

  @override
  String get social_friend_removed => 'Пользователь удалён из друзей';

  @override
  String get social_friends_badge => 'Друзья';

  @override
  String social_friends_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count друзей',
      few: '$count друга',
      one: '$count друг',
      zero: 'Друзья',
    );
    return '$_temp0';
  }

  @override
  String get social_friends_title => 'Друзья';

  @override
  String get social_incoming => 'Входящие заявки';

  @override
  String social_incoming_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count новых заявок',
      few: '$count новые заявки',
      one: '$count новая заявка',
    );
    return '$_temp0';
  }

  @override
  String get social_more_actions => 'Ещё';

  @override
  String get social_my_communities => 'Мои сообщества';

  @override
  String get social_nickname_available => 'Никнейм свободен';

  @override
  String get social_nickname_callout =>
      'Задайте никнейм, чтобы друзья могли вас найти.';

  @override
  String get social_nickname_characters =>
      'Только латинские буквы, цифры и «_»';

  @override
  String get social_nickname_checking => 'Проверяем…';

  @override
  String get social_nickname_hint =>
      '3–20 символов: латинские буквы, цифры и «_», первая — буква. Регистр не важен для уникальности.';

  @override
  String get social_nickname_label => 'Никнейм';

  @override
  String get social_nickname_required => 'Введите никнейм';

  @override
  String get social_nickname_reserved => 'Этот никнейм зарезервирован';

  @override
  String get social_nickname_start_letter =>
      'Никнейм должен начинаться с буквы';

  @override
  String get social_nickname_taken => 'Этот никнейм уже занят';

  @override
  String social_nickname_too_long(int max) {
    return 'Не больше $max символов';
  }

  @override
  String social_nickname_too_short(int min) {
    return 'Не меньше $min символов';
  }

  @override
  String get social_nickname_unchecked =>
      'Не удалось проверить — проверим при сохранении';

  @override
  String get social_no_friends =>
      'Пока нет друзей. Найдите друга по никнейму выше.';

  @override
  String get social_no_nickname => 'Никнейм не задан';

  @override
  String get social_no_requests => 'Заявок нет.';

  @override
  String get social_no_shared_communities => 'Общих сообществ пока нет.';

  @override
  String get social_now_friends => 'Теперь вы друзья';

  @override
  String get social_offline_banner =>
      'Нет соединения — показан сохранённый список.';

  @override
  String get social_outgoing => 'Отправленные заявки';

  @override
  String get social_privacy_always_private =>
      'Email, заметки, названия привычек и история отметок никогда не показываются другим.';

  @override
  String get social_privacy_communities => 'Мои сообщества';

  @override
  String get social_privacy_communities_hint =>
      'Кто видит, в каких сообществах вы состоите (другие видят только общие с ними).';

  @override
  String get social_privacy_intro =>
      'Никнейм, аватар и описание видны всем, кто вас найдёт. Остальное — по вашему выбору.';

  @override
  String get social_privacy_stats => 'Статистика и имя в рейтингах';

  @override
  String get social_privacy_stats_hint =>
      'Кто видит ваши активные привычки, регулярность за неделю и ваш никнейм в рейтингах сообществ. Скрыв её от всех, вы не появитесь в рейтинге друзей.';

  @override
  String get social_privacy_title => 'Конфиденциальность';

  @override
  String get social_profile_saved => 'Профиль сохранён';

  @override
  String get social_profile_title => 'Профиль';

  @override
  String get social_ranking_empty =>
      'Добавьте друзей, чтобы сравнивать прогресс.';

  @override
  String get social_ranking_rules =>
      'Рейтинг недели по всем активным привычкам: доля дней с отметкой среди запланированных — с понедельника по сегодня, не раньше создания привычки. Друзья, скрывшие статистику, не показываются.';

  @override
  String get social_reject => 'Отклонить';

  @override
  String get social_remove_friend => 'Удалить из друзей';

  @override
  String get social_remove_message =>
      'Вы сможете снова отправить заявку позже.';

  @override
  String get social_remove_title => 'Удалить из друзей?';

  @override
  String social_request_accepted_notice(String handle) {
    return '$handle принял(а) вашу заявку';
  }

  @override
  String get social_request_cancelled => 'Заявка отменена';

  @override
  String get social_request_rejected => 'Заявка отклонена';

  @override
  String get social_request_sent => 'Заявка отправлена';

  @override
  String get social_save => 'Сохранить';

  @override
  String social_search_empty(String query) {
    return 'Пользователь @$query не найден';
  }

  @override
  String get social_search_hint => 'Точный никнейм';

  @override
  String get social_search_label => 'Найти по никнейму';

  @override
  String get social_set_nickname => 'Задать никнейм';

  @override
  String get social_setup_subtitle =>
      'Никнейм нужен, чтобы друзья могли найти вас и чтобы вас было видно в рейтингах. Его можно сменить позже.';

  @override
  String get social_setup_title => 'Выберите никнейм';

  @override
  String get social_shared_communities => 'Общие сообщества';

  @override
  String get social_stat_active_habits => 'активных привычек';

  @override
  String get social_stat_best_streak => 'лучшая серия';

  @override
  String get social_stat_friends => 'друзей';

  @override
  String social_stat_week(int completed, int eligible) {
    return 'за неделю ($completed из $eligible дн.)';
  }

  @override
  String get social_stats_hidden => 'Пользователь скрыл статистику.';

  @override
  String get social_stats_title => 'Статистика';

  @override
  String get social_tab_friends => 'Друзья';

  @override
  String get social_tab_ranking => 'Рейтинг';

  @override
  String get social_tab_requests => 'Заявки';

  @override
  String get social_this_is_you => 'Это вы';

  @override
  String get social_unblock => 'Разблокировать';

  @override
  String get social_user_blocked => 'Пользователь заблокирован';

  @override
  String get social_user_unblocked => 'Пользователь разблокирован';

  @override
  String get social_view_public_profile => 'Как меня видят другие';

  @override
  String get social_visibility_everyone => 'Все';

  @override
  String get social_visibility_friends => 'Только друзья';

  @override
  String get social_visibility_nobody => 'Никто';

  @override
  String get social_waiting => 'Ожидает ответа';

  @override
  String get community_rules_title => 'Как считается рейтинг';

  @override
  String get community_rules_body =>
      'В рейтинге участвует одна привычка, созданная по шаблону сообщества, со своим расписанием. Итоги подводятся за прошлую неделю, с понедельника по воскресенье. Считается регулярность по вашему расписанию: ежедневная привычка — все дни недели, «по дням» — только выбранные дни, «цель на неделю» — сама цель (отметки сверх неё баллов не добавляют). Дни до вступления и до создания привычки не учитываются, а цель на неделю при вступлении в середине недели уменьшается пропорционально. При равных процентах выше тот, у кого больше выполнено, затем — у кого больше успешных недель подряд. Текущая неделя показывается отдельно и попадает в рейтинг, только когда закончится. Другие участники видят только имя профиля (или «Участник»), процент и числа.';

  @override
  String community_ranked_habit(String title) {
    return 'В рейтинге: «$title»';
  }

  @override
  String get community_not_ranked =>
      'Вы пока не участвуете в рейтинге. Создайте привычку по шаблону, когда захотите.';

  @override
  String get community_ranked_habit_missing =>
      'Привычка для рейтинга удалена или ещё не загрузилась на это устройство.';

  @override
  String get community_create_ranked_habit => 'Создать привычку для рейтинга';

  @override
  String community_week_progress(int completed, int eligible) {
    return 'На этой неделе: $completed из $eligible дн.';
  }

  @override
  String get community_week_progress_none =>
      'На этой неделе засчитываемых дней пока нет.';

  @override
  String get community_habit_paused =>
      'Привычка на паузе — она не участвует в рейтинге.';

  @override
  String get community_leaderboard_empty =>
      'За прошлую неделю результатов пока нет: никто из участников ещё не был в рейтинге всю неделю или её часть.';

  @override
  String get community_leaderboard_offline =>
      'Рейтинг доступен только при подключении к интернету.';

  @override
  String get community_leaderboard_failed => 'Не удалось загрузить рейтинг.';

  @override
  String get community_member_fallback => 'Участник';

  @override
  String get community_you => 'Вы';

  @override
  String community_rank(int rank) {
    return 'Место $rank';
  }

  @override
  String community_my_rank(int rank, int total) {
    return 'Ваше место: $rank из $total';
  }

  @override
  String get community_not_ranked_yet =>
      'Ваши результаты появятся в рейтинге, когда закончится первая неделя с привычкой для рейтинга.';

  @override
  String get community_unsynced_hint =>
      'Часть отметок ещё не синхронизирована — рейтинг обновится после синхронизации.';

  @override
  String get join_sheet_title => 'Как участвовать';

  @override
  String get join_option_ranked => 'Создать привычку и участвовать в рейтинге';

  @override
  String get join_option_ranked_hint =>
      'Привычка появится в вашем списке; её отметки будут учитываться в рейтинге.';

  @override
  String get join_option_unranked => 'Вступить без участия в рейтинге';

  @override
  String get join_option_unranked_hint =>
      'Привычку для рейтинга можно создать позже.';

  @override
  String get community_joined_ranked =>
      'Привычка создана, вы участвуете в рейтинге';

  @override
  String get community_ranked_habit_created =>
      'Привычка создана и участвует в рейтинге';

  @override
  String get community_error_not_synced =>
      'Не удалось загрузить привычку на сервер — ничего не изменено. Проверьте интернет и попробуйте снова.';

  @override
  String get community_create_habit_title => 'Привычка для рейтинга';

  @override
  String get community_create_habit_action => 'Создать привычку';

  @override
  String get create_habit_name_label => 'Название';

  @override
  String get create_habit_target_label => 'Цель на одно выполнение';

  @override
  String get create_habit_hint =>
      'Цель сохраняется в описании привычки. Расписание предложено шаблоном — его можно изменить, шаблон от этого не меняется.';

  @override
  String create_habit_similar(String title) {
    return 'У вас уже есть похожая привычка «$title».';
  }

  @override
  String create_habit_description(String description, String target) {
    return '$description Цель: $target за раз.';
  }

  @override
  String get profile_title => 'Профиль';

  @override
  String get nav_home => 'Главная';

  @override
  String get nav_habits => 'Привычки';

  @override
  String get habit_mark_done => 'Отметить выполненной сегодня';

  @override
  String get habit_unmark_done => 'Отменить отметку за сегодня';

  @override
  String get theme_settings => 'Тема';

  @override
  String get archive => 'Архив';

  @override
  String get notifications => 'Уведомления';

  @override
  String get widgets => 'Виджеты';

  @override
  String get about_app => 'О приложении';

  @override
  String get rate_us => 'Оцените нас';

  @override
  String get share_app => 'Поделиться приложением';

  @override
  String get feedback => 'Обратная связь';

  @override
  String get privacy_policy => 'Политика конфиденциальности';

  @override
  String get sign_out => 'Выйти';

  @override
  String get sign_out_confirmation_title => 'Выход';

  @override
  String get sign_out_confirmation_message =>
      'Вы уверены, что хотите выйти из аккаунта?';

  @override
  String sign_out_unsynced_message(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count изменений ещё не синхронизированы и будут потеряны. Всё равно выйти?',
      few:
          '$count изменения ещё не синхронизированы и будут потеряны. Всё равно выйти?',
      one:
          '$count изменение ещё не синхронизировано и будет потеряно. Всё равно выйти?',
    );
    return '$_temp0';
  }

  @override
  String get sign_out_anyway => 'Всё равно выйти';

  @override
  String get cancel => 'Отмена';

  @override
  String get close => 'Закрыть';

  @override
  String app_version(int major, int minor, int patch) {
    return 'Версия $major.$minor.$patch';
  }

  @override
  String get about_app_description =>
      'Go Habit - это приложение, разработанное для формирования и поддержания полезных привычек. Отслеживайте свой прогресс, устанавливайте напоминания и визуализируйте свой путь.';

  @override
  String privacy_policy_last_updated(String date) {
    return 'Дата последнего обновления: $date';
  }

  @override
  String get privacy_policy_section1_title => '1. Сбор информации';

  @override
  String get privacy_policy_section1_content =>
      'Приложение Go Habit собирает следующую информацию:\n• Информацию об аккаунте (email)\n• Данные о привычках и активности\n• Информацию о устройстве (для диагностики)';

  @override
  String get privacy_policy_section2_title => '2. Использование информации';

  @override
  String get privacy_policy_section2_content =>
      'Мы используем собранную информацию для:\n• Предоставления основных функций приложения\n• Улучшения пользовательского опыта\n• Отправки уведомлений (только с вашего разрешения)';

  @override
  String get privacy_policy_section3_title => '3. Безопасность данных';

  @override
  String get privacy_policy_section3_content =>
      'Мы применяем современные меры безопасности для защиты ваших персональных данных. Все данные хранятся в зашифрованном виде и не передаются третьим лицам без вашего согласия.';

  @override
  String get privacy_policy_section4_title => '4. Файлы cookie';

  @override
  String get privacy_policy_section4_content =>
      'Наше приложение не использует файлы cookie в традиционном понимании. Однако мы сохраняем локальные данные на вашем устройстве для оптимальной работы приложения.';

  @override
  String get privacy_policy_section5_title => '5. Согласие';

  @override
  String get privacy_policy_section5_content =>
      'Используя приложение Go Habit, вы соглашаетесь с нашей политикой конфиденциальности. Если у вас есть вопросы, свяжитесь с нами по адресу support@gohabit.app';

  @override
  String privacy_policy_copyright(String year) {
    return '© $year Go Habit. Все права защищены.';
  }

  @override
  String community_recommended_schedule(String schedule) {
    return 'Рекомендуемое расписание: $schedule';
  }

  @override
  String community_leaderboard_period(String range) {
    return 'Неделя $range';
  }

  @override
  String community_percent(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String valueString = valueNumberFormat.format(value);

    return '$valueString %';
  }

  @override
  String community_actions(int completed, int expected) {
    return '$completed/$expected';
  }

  @override
  String community_actions_semantics(int completed, int expected) {
    return 'выполнено $completed из $expected по расписанию';
  }

  @override
  String community_success_weeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count успешных недель подряд',
      few: '$count успешные недели подряд',
      one: '$count успешная неделя подряд',
    );
    return '$_temp0';
  }

  @override
  String get community_status_paused =>
      'В конце прошлой недели привычка была на паузе — неделя не оценивалась.';

  @override
  String get community_status_no_actions =>
      'На прошлой неделе по вашему расписанию ничего не было запланировано.';

  @override
  String community_this_week(String progress) {
    return 'Эта неделя (идёт): $progress';
  }

  @override
  String community_progress_days(int completed, int expected) {
    return '$completed/$expected дн.';
  }

  @override
  String community_progress_target(int completed, int expected) {
    return '$completed/$expected цели недели';
  }

  @override
  String community_progress_weekdays(int completed, int expected) {
    return '$completed/$expected запланированных дн.';
  }

  @override
  String get theme_system => 'Системная';

  @override
  String get theme_light => 'Светлая';

  @override
  String get theme_dark => 'Тёмная';

  @override
  String get language_label => 'Язык';

  @override
  String get profile_section_stats => 'Статистика';

  @override
  String get profile_section_social => 'Друзья и приватность';

  @override
  String get profile_section_settings => 'Настройки';

  @override
  String get profile_section_about => 'Приложение';

  @override
  String get profile_show_welcome => 'Показать приветствие';

  @override
  String get profile_email_hint => 'Почта аккаунта видна только вам';

  @override
  String get notifications_empty => 'Нет новых уведомлений';

  @override
  String get notifications_habit_title => 'Время для привычки';

  @override
  String notifications_habit_body(String name) {
    return '$name — уделите этому несколько минут сегодня.';
  }

  @override
  String get notifications_progress_title => 'Как проходит день?';

  @override
  String notifications_progress_body(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'На сегодня осталось $count привычек.',
      few: 'На сегодня осталось $count привычки.',
      one: 'На сегодня осталась $count привычка.',
    );
    return '$_temp0';
  }

  @override
  String get notifications_progress_body_general =>
      'Загляните, что запланировано на сегодня.';

  @override
  String get notifications_streak_title => 'Серия под угрозой';

  @override
  String notifications_streak_body_one(String title) {
    return 'Отметьте «$title» сегодня, чтобы не прервать серию.';
  }

  @override
  String notifications_streak_body_many(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count привычек ещё не отмечены — их серии прервутся, если пропустить сегодня.',
      few:
          '$count привычки ещё не отмечены — их серии прервутся, если пропустить сегодня.',
      one:
          '$count привычка ещё не отмечена — её серия прервётся, если пропустить сегодня.',
    );
    return '$_temp0';
  }

  @override
  String get notifications_channel_habits => 'Напоминания о привычках';

  @override
  String get notifications_channel_habits_description =>
      'Напоминания в выбранное для привычки время';

  @override
  String get notifications_channel_progress => 'Итоги дня и серии';

  @override
  String get notifications_channel_progress_description =>
      'Необязательные напоминания об оставшихся привычках и сериях';

  @override
  String get notifications_empty_hint =>
      'Здесь появятся напоминания, которые вы увидели или открыли.';

  @override
  String get notifications_today => 'Сегодня';

  @override
  String get notifications_yesterday => 'Вчера';

  @override
  String get notifications_earlier => 'Ранее';

  @override
  String get notifications_just_now => 'только что';

  @override
  String notifications_minutes_ago(int count) {
    return '$count мин назад';
  }

  @override
  String notifications_hours_ago(int count) {
    return '$count ч назад';
  }

  @override
  String get notifications_mark_all_read => 'Отметить все прочитанными';

  @override
  String get notifications_clear_all => 'Очистить историю';

  @override
  String get notifications_clear_title => 'Очистить историю уведомлений?';

  @override
  String get notifications_clear_message =>
      'Записи будут удалены. Запланированные напоминания останутся.';

  @override
  String get notifications_clear_confirm => 'Очистить';

  @override
  String get notifications_delete => 'Удалить';

  @override
  String get notifications_unread => 'Не прочитано';

  @override
  String get notifications_category_habit => 'Привычка';

  @override
  String get notifications_category_progress => 'Итоги дня';

  @override
  String get notifications_category_streak => 'Серия';

  @override
  String get notifications_category_system => 'Системное';

  @override
  String get notifications_habit_missing => 'Эта привычка уже удалена.';

  @override
  String get notifications_load_failed => 'Не удалось загрузить уведомления.';

  @override
  String get notifications_settings_title => 'Настройки уведомлений';

  @override
  String get notifications_master => 'Уведомления Go Habit';

  @override
  String get notifications_master_hint =>
      'Выключите, чтобы отменить все напоминания приложения. Настройки сохранятся.';

  @override
  String get notifications_permission_request =>
      'Разрешите уведомления, чтобы напоминания приходили в выбранное время.';

  @override
  String get notifications_permission_denied =>
      'Уведомления запрещены в настройках системы — напоминания не будут показаны.';

  @override
  String get notifications_permission_unsupported =>
      'На этом устройстве уведомления недоступны.';

  @override
  String get notifications_allow => 'Разрешить';

  @override
  String get notifications_open_settings => 'Открыть настройки';

  @override
  String get notifications_habit_reminders => 'Напоминания о привычках';

  @override
  String get notifications_habit_reminders_hint =>
      'Время и дни напоминания настраиваются в форме каждой привычки.';

  @override
  String get notifications_progress_setting => 'Итоги дня';

  @override
  String get notifications_progress_setting_hint =>
      'Напомнить, если на сегодня остались привычки';

  @override
  String get notifications_streak_setting => 'Серия под угрозой';

  @override
  String get notifications_streak_setting_hint =>
      'Предупредить, если без сегодняшней отметки серия прервётся';

  @override
  String notifications_time(String time) {
    return 'Время: $time';
  }

  @override
  String get notifications_delivery_hint =>
      'Система может немного задержать уведомление, чтобы беречь заряд.';

  @override
  String get habits_reminder_label => 'Напоминание';

  @override
  String get habits_reminder_toggle => 'Напоминать';

  @override
  String get habits_reminder_days => 'Дни напоминания';

  @override
  String get habits_reminder_days_required => 'Выберите хотя бы один день';

  @override
  String get habits_reminder_weekly_hint =>
      'У цели на неделю нет фиксированных дней — выберите, когда напоминать.';

  @override
  String get habits_reminder_off_hint =>
      'Уведомления выключены — напоминание не придёт. Включить их можно в «Профиль → Уведомления».';

  @override
  String get profile_notifications => 'Уведомления';

  @override
  String get notifications_extra_reminders => 'Дополнительные напоминания';

  @override
  String get habits_choose_icon => 'Выбрать иконку';

  @override
  String get habits_reminder_time => 'Время напоминания';

  @override
  String get habits_reminder_off => 'Выключено';

  @override
  String get habits_reminder_every_day => 'каждый день';

  @override
  String get habits_reminder_independent_hint =>
      'Дни напоминания настраиваются отдельно от расписания.';
}
