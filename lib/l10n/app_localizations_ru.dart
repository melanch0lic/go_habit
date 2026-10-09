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
    return 'Рекомендуемая цель: $target в день';
  }

  @override
  String get community_schedule_daily => 'Каждый день';

  @override
  String get community_join => 'Вступить';

  @override
  String get community_leave => 'Покинуть сообщество';

  @override
  String get community_leave_title => 'Покинуть сообщество?';

  @override
  String get community_leave_message =>
      'Привычка для рейтинга останется в вашем списке вместе с историей. Если вернётесь, дни этой недели до повторного вступления засчитаны не будут.';

  @override
  String get community_leave_confirm => 'Покинуть';

  @override
  String community_member_since(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Вы участник с $dateString';
  }

  @override
  String get community_leaderboard_title => 'Рейтинг недели';

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
  String get community_rules_title => 'Как считается рейтинг';

  @override
  String get community_rules_body =>
      'В рейтинге участвует одна привычка, созданная по шаблону сообщества. Рейтинг недельный: с понедельника по сегодня. Считается регулярность — доля засчитываемых дней, в которые привычка отмечена. Дни до вступления и до создания привычки не учитываются, будущие дни тоже. Время и усилия не сравниваются. Другие участники видят только имя профиля (или «Участник»), процент и число дней.';

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
      'Пока ни у кого нет засчитываемых дней на этой неделе.';

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
  String community_days(int completed, int eligible) {
    return '$completed из $eligible дн.';
  }

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
      'Вы появитесь в рейтинге, когда у привычки для рейтинга будут засчитываемые дни.';

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
  String get create_habit_target_label => 'Цель в день';

  @override
  String get create_habit_hint =>
      'Цель сохраняется в описании привычки. Расписание — каждый день.';

  @override
  String create_habit_similar(String title) {
    return 'У вас уже есть похожая привычка «$title».';
  }

  @override
  String create_habit_description(String description, String target) {
    return '$description Цель: $target в день.';
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
  String get theme_settings => 'Темная тема';

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
}
