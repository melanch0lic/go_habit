// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get welcome_back => 'Welcome back to Go Habit';

  @override
  String get dont_have_account => 'Don\'t have an account? Sign Up';

  @override
  String get registration => 'Registration';

  @override
  String get register => 'Register';

  @override
  String get sign_in => 'Sign In';

  @override
  String get create_account => 'Create a Go Habit account';

  @override
  String get already_have_account => 'Already have an account? Log In';

  @override
  String welcomeMessage(String email) {
    return 'Welcome, $email!';
  }

  @override
  String get app_description_title => 'Go Habit app will help you:';

  @override
  String get habit_tracking_feature =>
      'Track your habits and completion streaks!';

  @override
  String get daily_habits_feature =>
      'Create and track daily habits to achieve goals';

  @override
  String get analytics_feature => 'Progress analysis with charts and cubes!';

  @override
  String get visualization_feature =>
      'Visualize your progress and stay motivated';

  @override
  String get reminders_feature => 'Get reminders and motivational phrases!';

  @override
  String get notifications_feature =>
      'Customize notifications to remember your habits';

  @override
  String get widgets_feature => 'Habit widgets right on your home screen!';

  @override
  String get customWidgets_feature =>
      'Customize widgets you want to see on home screen';

  @override
  String get start_tracking_button => 'Start habit tracking';

  @override
  String get password_label => 'Password';

  @override
  String get password_required => 'Please enter your password';

  @override
  String get password_length => 'Password must contain at least 6 characters';

  @override
  String get confirm_password_label => 'Confirm password';

  @override
  String get confirm_password_required => 'Please confirm your password';

  @override
  String get passwords_dont_match => 'Passwords don\'t match';

  @override
  String get email_label => 'Email';

  @override
  String get email_required => 'Please enter your email';

  @override
  String get email_invalid => 'Please enter a valid email';

  @override
  String get auth_sign_in_subtitle =>
      'Sign in to keep your habit streaks going';

  @override
  String get auth_sign_up_subtitle => 'All you need is an email and a password';

  @override
  String get auth_forgot_password => 'Forgot password?';

  @override
  String get auth_no_account => 'Don\'t have an account?';

  @override
  String get auth_create_account_action => 'Sign up';

  @override
  String get auth_have_account => 'Already have an account?';

  @override
  String get email_hint => 'name@example.com';

  @override
  String get password_show => 'Show password';

  @override
  String get password_hide => 'Hide password';

  @override
  String get password_letters_digits =>
      'Password must contain letters and digits';

  @override
  String get password_req_length => 'At least 6 characters';

  @override
  String get password_req_letters_digits => 'Letters and digits';

  @override
  String get auth_check_email_title => 'Check your email';

  @override
  String auth_confirm_email_message(String email) {
    return 'We sent a confirmation link to $email. Follow the link, then sign in.';
  }

  @override
  String get auth_check_email_hint =>
      'No email? Check your spam folder. If you already have an account with this address, just sign in or reset your password.';

  @override
  String get auth_resend_email => 'Resend email';

  @override
  String auth_resend_in(int seconds) {
    return 'Resend in $seconds s';
  }

  @override
  String get auth_email_resent => 'Email sent again';

  @override
  String get auth_back_to_sign_in => 'Back to sign in';

  @override
  String get auth_reset_title => 'Reset password';

  @override
  String get auth_reset_subtitle =>
      'Enter your account email and we\'ll send you a reset link';

  @override
  String get auth_reset_send => 'Send link';

  @override
  String auth_reset_sent_message(String email) {
    return 'If an account with $email exists, we\'ve sent it a password reset link.';
  }

  @override
  String get auth_reset_sent_hint =>
      'Open the email on this device so the link opens in the app. The link expires after a while.';

  @override
  String get auth_new_password_title => 'Change password';

  @override
  String get auth_new_password_subtitle =>
      'Choose a new password for your account';

  @override
  String get auth_new_password_label => 'New password';

  @override
  String get auth_new_password_save => 'Save password';

  @override
  String get auth_password_updated => 'Password updated';

  @override
  String get auth_later => 'Later';

  @override
  String get auth_error_invalid_credentials =>
      'Wrong email or password. Check your details or reset your password.';

  @override
  String get auth_error_email_not_confirmed =>
      'Your email is not confirmed yet. Follow the link from the email we sent after sign-up.';

  @override
  String get auth_error_user_exists =>
      'An account with this email already exists. Sign in or reset your password.';

  @override
  String get auth_error_weak_password =>
      'This password is too weak. Use at least 6 characters with letters and digits.';

  @override
  String get auth_error_same_password =>
      'The new password must differ from the current one.';

  @override
  String get auth_error_invalid_email =>
      'This email can\'t be used. Check the address.';

  @override
  String get auth_error_signup_disabled =>
      'Sign-up is currently unavailable. Try again later.';

  @override
  String get auth_error_rate_limited =>
      'Too many attempts. Wait a few minutes and try again.';

  @override
  String get auth_error_network =>
      'Couldn\'t reach the server. Check your connection and try again.';

  @override
  String get auth_error_link_invalid =>
      'This link is invalid or has expired. Request a new one.';

  @override
  String get auth_error_session_expired =>
      'The time to change your password has run out. Request a new link.';

  @override
  String get auth_error_unknown => 'Something went wrong. Please try again.';

  @override
  String get communities_title => 'Communities';

  @override
  String get communities_tab_catalog => 'Catalog';

  @override
  String get communities_tab_mine => 'Mine';

  @override
  String get communities_intro =>
      'Join communities and compete in the weekly ranking with a habit from the template — or just be a member. Your notes and other habits stay private.';

  @override
  String get communities_search_hint => 'Search habits';

  @override
  String get communities_filter_all => 'All';

  @override
  String communities_members(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '$count member',
    );
    return '$_temp0';
  }

  @override
  String get communities_no_members_yet => 'No members yet';

  @override
  String get communities_joined_badge => 'Joined';

  @override
  String get communities_empty_search =>
      'Nothing found. Try another search or category.';

  @override
  String get communities_empty_mine => 'You haven\'t joined any community yet.';

  @override
  String get communities_browse_catalog => 'Browse the catalog';

  @override
  String get communities_offline_banner =>
      'You\'re offline — showing saved data. Joining and rankings need a connection.';

  @override
  String get communities_load_failed => 'Couldn\'t load communities.';

  @override
  String get communities_retry => 'Retry';

  @override
  String unit_pages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '$count page',
    );
    return '$_temp0';
  }

  @override
  String unit_minutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '$count minute',
    );
    return '$_temp0';
  }

  @override
  String unit_steps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count steps',
      one: '$count step',
    );
    return '$_temp0';
  }

  @override
  String unit_glasses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count glasses',
      one: '$count glass',
    );
    return '$_temp0';
  }

  @override
  String unit_hours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '$count hour',
    );
    return '$_temp0';
  }

  @override
  String community_recommended_target(String target) {
    return 'Recommended target: $target per session';
  }

  @override
  String get community_join => 'Join';

  @override
  String get community_leave => 'Leave community';

  @override
  String get community_leave_title => 'Leave this community?';

  @override
  String get community_leave_message =>
      'Your ranked habit stays in your list with its history. You will disappear from the ranking; if you come back, days before rejoining won\'t count.';

  @override
  String get community_leave_confirm => 'Leave';

  @override
  String community_member_since(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Member since $dateString';
  }

  @override
  String get community_leaderboard_title => 'Last week\'s ranking';

  @override
  String get community_retired => 'This community is closed to new members.';

  @override
  String get community_joined => 'You joined the community';

  @override
  String get community_left => 'You left the community. Your habit is kept.';

  @override
  String get community_error_offline =>
      'You\'re offline. Try again when you\'re connected.';

  @override
  String get community_error_network =>
      'Couldn\'t reach the server. Please try again.';

  @override
  String get community_error_not_allowed =>
      'Not available: the community is closed.';

  @override
  String get community_error_unauthorized =>
      'Your session expired. Please sign in again.';

  @override
  String get community_error_unknown =>
      'Something went wrong. Please try again.';

  @override
  String get habits_schedule_label => 'Schedule';

  @override
  String get habits_schedule_option_daily => 'Every day';

  @override
  String get habits_schedule_option_weekly => 'Weekly goal';

  @override
  String get habits_schedule_option_weekdays => 'On days';

  @override
  String get habits_schedule_daily => 'Every day';

  @override
  String habits_schedule_times_per_week(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times a week',
      two: 'twice a week',
      one: 'once a week',
    );
    return '$_temp0';
  }

  @override
  String habits_schedule_weekly_summary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times a week, any days',
      two: 'Twice a week, any days',
      one: 'Once a week, any day',
    );
    return '$_temp0';
  }

  @override
  String get habits_weekly_target_label => 'Times per week';

  @override
  String get habits_weekdays_label => 'Weekdays';

  @override
  String get habits_weekdays_required => 'Choose at least one day';

  @override
  String get habits_weekday_1 => 'Mon';

  @override
  String get habits_weekday_2 => 'Tue';

  @override
  String get habits_weekday_3 => 'Wed';

  @override
  String get habits_weekday_4 => 'Thu';

  @override
  String get habits_weekday_5 => 'Fri';

  @override
  String get habits_weekday_6 => 'Sat';

  @override
  String get habits_weekday_7 => 'Sun';

  @override
  String habits_streak_weeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count-week streak',
      one: '$count-week streak',
    );
    return '$_temp0';
  }

  @override
  String habits_streak_occurrences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count in a row',
      one: '$count in a row',
    );
    return '$_temp0';
  }

  @override
  String habits_week_target_progress(int done, int goal) {
    return '$done/$goal this week';
  }

  @override
  String habits_weekdays_progress(int done, int goal) {
    return '$done of $goal days this week';
  }

  @override
  String get habits_not_today => 'Not scheduled today';

  @override
  String get habits_section_week => 'Weekly goals';

  @override
  String get habits_section_other_days => 'On other days';

  @override
  String habits_week_goals(int done, int total) {
    return 'Weekly goals: $done of $total';
  }

  @override
  String get habits_schedule_change_title => 'Change the schedule type?';

  @override
  String get habits_schedule_change_message =>
      'Your current streak will start over: each schedule type counts streaks differently. Your completion history is kept.';

  @override
  String get habits_schedule_change_confirm => 'Change schedule';

  @override
  String social_best_streak_days(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'days',
      one: 'day',
    );
    return '$_temp0 in a row — best streak';
  }

  @override
  String social_best_streak_weeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'weeks',
      one: 'week',
    );
    return '$_temp0 in a row — best streak';
  }

  @override
  String social_best_streak_occurrences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'times',
      one: 'time',
    );
    return '$_temp0 in a row — best streak';
  }

  @override
  String get habits_title => 'Habits';

  @override
  String get habits_add => 'Add habit';

  @override
  String habits_actions(String title) {
    return 'Actions for “$title”';
  }

  @override
  String get habits_category_label => 'Category';

  @override
  String get habits_category_other => 'Other';

  @override
  String get habits_delete => 'Delete';

  @override
  String habits_delete_title(String title) {
    return 'Delete “$title”?';
  }

  @override
  String get habits_delete_message =>
      'The habit and its whole history will be deleted on all devices. To take a break instead, pause it — the history is kept.';

  @override
  String get habits_description_label => 'Description (optional)';

  @override
  String get habits_discard => 'Discard';

  @override
  String get habits_discard_message => 'Your changes haven\'t been saved.';

  @override
  String get habits_discard_title => 'Leave without saving?';

  @override
  String get habits_keep_editing => 'Keep editing';

  @override
  String get habits_done_today => 'done today';

  @override
  String get habits_not_done_today => 'not done today';

  @override
  String get habits_edit => 'Edit';

  @override
  String get habits_edit_title => 'Edit habit';

  @override
  String get habits_new_title => 'New habit';

  @override
  String get habits_empty_title => 'Start with your first habit';

  @override
  String get habits_empty_body =>
      'One small daily step — in a couple of weeks it becomes part of your day.';

  @override
  String get habits_empty_catalog => 'Pick one from the community catalog';

  @override
  String get habits_error_add => 'Couldn\'t add the habit. Please try again.';

  @override
  String get habits_error_completion =>
      'Couldn\'t save the mark. Please try again.';

  @override
  String get habits_error_delete =>
      'Couldn\'t delete the habit. Please try again.';

  @override
  String get habits_error_generic =>
      'Couldn\'t save the change. Please try again.';

  @override
  String get habits_error_load => 'Couldn\'t load your habits.';

  @override
  String get habits_error_update =>
      'Couldn\'t save the habit. Please try again.';

  @override
  String get habits_icon_custom => 'Your own emoji';

  @override
  String get habits_icon_label => 'Icon';

  @override
  String get habits_icon_single => 'Enter a single emoji';

  @override
  String get habits_loading => 'Loading habits';

  @override
  String get habits_name_label => 'Name';

  @override
  String get habits_name_required => 'Enter a name';

  @override
  String habits_nothing_today(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nothing scheduled today: $count habits are paused.',
      one: 'Nothing scheduled today: $count habit is paused.',
    );
    return '$_temp0';
  }

  @override
  String get habits_pause => 'Pause';

  @override
  String get habits_paused_label => 'Paused';

  @override
  String get habits_resume => 'Resume';

  @override
  String get habits_section_paused => 'Paused';

  @override
  String get habits_section_today => 'Today';

  @override
  String habits_streak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count-day streak',
      one: '$count-day streak',
    );
    return '$_temp0';
  }

  @override
  String get habits_today_all_done => 'All done for today 🎉';

  @override
  String get habits_today_loading => 'Counting progress…';

  @override
  String get habits_today_nothing => 'Nothing scheduled for today';

  @override
  String habits_today_progress(int completed, int total) {
    return '$completed of $total done';
  }

  @override
  String get social_accept => 'Accept';

  @override
  String get social_add_friend => 'Add friend';

  @override
  String get social_already_accepted => 'Already accepted — you\'re friends';

  @override
  String get social_avatar_default => 'Pixel avatar from the nickname';

  @override
  String get social_avatar_label => 'Avatar';

  @override
  String get social_bio_label => 'About';

  @override
  String get social_block => 'Block';

  @override
  String get social_block_message =>
      'Your friendship and requests will be removed. They won\'t be able to find you or send requests, and won\'t be told about the block.';

  @override
  String get social_block_title => 'Block this user?';

  @override
  String get social_blocked => 'Blocked';

  @override
  String get social_cancel_request => 'Cancel request';

  @override
  String get social_edit_profile => 'Edit profile';

  @override
  String get social_error_blocked_by_me =>
      'You blocked this user. Unblock them first.';

  @override
  String get social_error_invalid_profile =>
      'The server rejected the profile. Check the nickname and the description.';

  @override
  String get social_error_network =>
      'Couldn\'t reach the server. Please try again.';

  @override
  String get social_error_not_allowed => 'This action isn\'t available.';

  @override
  String get social_error_not_found => 'User not found.';

  @override
  String get social_error_offline =>
      'You\'re offline. Friends and profile changes need a connection.';

  @override
  String get social_error_unauthorized =>
      'Your session expired. Please sign in again.';

  @override
  String get social_error_unknown => 'Something went wrong. Please try again.';

  @override
  String get social_friend_removed => 'Removed from friends';

  @override
  String get social_friends_badge => 'Friends';

  @override
  String social_friends_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count friends',
      one: '$count friend',
      zero: 'Friends',
    );
    return '$_temp0';
  }

  @override
  String get social_friends_title => 'Friends';

  @override
  String get social_incoming => 'Incoming requests';

  @override
  String social_incoming_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new requests',
      one: '$count new request',
    );
    return '$_temp0';
  }

  @override
  String get social_more_actions => 'More';

  @override
  String get social_my_communities => 'My communities';

  @override
  String get social_nickname_available => 'Nickname is available';

  @override
  String get social_nickname_callout =>
      'Choose a nickname so friends can find you.';

  @override
  String get social_nickname_characters => 'Only Latin letters, digits and “_”';

  @override
  String get social_nickname_checking => 'Checking…';

  @override
  String get social_nickname_hint =>
      '3–20 characters: Latin letters, digits and “_”, starting with a letter. Case doesn\'t matter for uniqueness.';

  @override
  String get social_nickname_label => 'Nickname';

  @override
  String get social_nickname_required => 'Enter a nickname';

  @override
  String get social_nickname_reserved => 'This nickname is reserved';

  @override
  String get social_nickname_start_letter =>
      'The nickname must start with a letter';

  @override
  String get social_nickname_taken => 'This nickname is taken';

  @override
  String social_nickname_too_long(int max) {
    return 'At most $max characters';
  }

  @override
  String social_nickname_too_short(int min) {
    return 'At least $min characters';
  }

  @override
  String get social_nickname_unchecked =>
      'Couldn\'t check — it will be checked on save';

  @override
  String get social_no_friends =>
      'No friends yet. Find someone by nickname above.';

  @override
  String get social_no_nickname => 'No nickname yet';

  @override
  String get social_no_requests => 'No requests.';

  @override
  String get social_no_shared_communities => 'No shared communities yet.';

  @override
  String get social_now_friends => 'You\'re friends now';

  @override
  String get social_offline_banner =>
      'You\'re offline — showing the saved list.';

  @override
  String get social_outgoing => 'Sent requests';

  @override
  String get social_privacy_always_private =>
      'Your email, notes, habit names and history are never shown to others.';

  @override
  String get social_privacy_communities => 'My communities';

  @override
  String get social_privacy_communities_hint =>
      'Who sees which communities you\'re in (others only see the ones you share).';

  @override
  String get social_privacy_intro =>
      'Your nickname, avatar and bio are visible to anyone who finds you. The rest is up to you.';

  @override
  String get social_privacy_stats => 'Statistics and name in rankings';

  @override
  String get social_privacy_stats_hint =>
      'Who sees your active habits, weekly regularity and your nickname in community rankings. Hiding it from everyone also leaves you out of friends\' rankings.';

  @override
  String get social_privacy_title => 'Privacy';

  @override
  String get social_profile_saved => 'Profile saved';

  @override
  String get social_profile_title => 'Profile';

  @override
  String get social_ranking_empty => 'Add friends to compare progress.';

  @override
  String get social_ranking_rules =>
      'This week\'s ranking across all active habits: the share of scheduled days with a mark, from Monday to today and not before a habit was created. Friends who hide their statistics aren\'t shown.';

  @override
  String get social_reject => 'Reject';

  @override
  String get social_remove_friend => 'Remove friend';

  @override
  String get social_remove_message => 'You can send a request again later.';

  @override
  String get social_remove_title => 'Remove this friend?';

  @override
  String social_request_accepted_notice(String handle) {
    return '$handle accepted your request';
  }

  @override
  String get social_request_cancelled => 'Request cancelled';

  @override
  String get social_request_rejected => 'Request rejected';

  @override
  String get social_request_sent => 'Request sent';

  @override
  String get social_save => 'Save';

  @override
  String social_search_empty(String query) {
    return 'No user @$query';
  }

  @override
  String get social_search_hint => 'Exact nickname';

  @override
  String get social_search_label => 'Find by nickname';

  @override
  String get social_set_nickname => 'Set a nickname';

  @override
  String get social_setup_subtitle =>
      'A nickname lets friends find you and shows you in rankings. You can change it later.';

  @override
  String get social_setup_title => 'Choose a nickname';

  @override
  String get social_shared_communities => 'Shared communities';

  @override
  String get social_stat_active_habits => 'active habits';

  @override
  String get social_stat_best_streak => 'best streak';

  @override
  String get social_stat_friends => 'friends';

  @override
  String social_stat_week(int completed, int eligible) {
    return 'this week ($completed of $eligible days)';
  }

  @override
  String get social_stats_hidden => 'This user hides their statistics.';

  @override
  String get social_stats_title => 'Statistics';

  @override
  String get social_tab_friends => 'Friends';

  @override
  String get social_tab_ranking => 'Ranking';

  @override
  String get social_tab_requests => 'Requests';

  @override
  String get social_this_is_you => 'That\'s you';

  @override
  String get social_unblock => 'Unblock';

  @override
  String get social_user_blocked => 'User blocked';

  @override
  String get social_user_unblocked => 'User unblocked';

  @override
  String get social_view_public_profile => 'How others see me';

  @override
  String get social_visibility_everyone => 'Everyone';

  @override
  String get social_visibility_friends => 'Friends only';

  @override
  String get social_visibility_nobody => 'Nobody';

  @override
  String get social_waiting => 'Waiting for an answer';

  @override
  String get community_rules_title => 'How the ranking works';

  @override
  String get community_rules_body =>
      'One habit created from the community\'s template, with its own schedule, takes part in the ranking. Results cover last week, Monday to Sunday. The ranking measures consistency with your schedule: a daily habit counts every day, selected weekdays count only those days, a weekly target counts the target (marks beyond it add nothing). Days before you joined or created the habit don\'t count, and a weekly target is prorated when you join mid-week. Ties go to more completed actions, then to more successful weeks in a row. The current week is shown separately and is ranked only once it is over. Others see only your profile name (or “Member”), your percentage and numbers.';

  @override
  String community_ranked_habit(String title) {
    return 'Ranked habit: “$title”';
  }

  @override
  String get community_not_ranked =>
      'You\'re not in the ranking yet. Create a habit from the template whenever you like.';

  @override
  String get community_ranked_habit_missing =>
      'Your ranked habit was deleted or hasn\'t reached this device yet.';

  @override
  String get community_create_ranked_habit => 'Create a ranked habit';

  @override
  String community_week_progress(int completed, int eligible) {
    return 'This week: $completed of $eligible days';
  }

  @override
  String get community_week_progress_none => 'No counted days this week yet.';

  @override
  String get community_habit_paused =>
      'The habit is paused — it isn\'t ranked.';

  @override
  String get community_leaderboard_empty =>
      'No results for last week yet: no member was ranked for all or part of it.';

  @override
  String get community_leaderboard_offline =>
      'The ranking needs an internet connection.';

  @override
  String get community_leaderboard_failed => 'Couldn\'t load the ranking.';

  @override
  String get community_member_fallback => 'Member';

  @override
  String get community_you => 'You';

  @override
  String community_rank(int rank) {
    return 'Rank $rank';
  }

  @override
  String community_my_rank(int rank, int total) {
    return 'Your rank: $rank of $total';
  }

  @override
  String get community_not_ranked_yet =>
      'Your results will appear in the ranking once your first week with a ranked habit is over.';

  @override
  String get community_unsynced_hint =>
      'Some marks aren\'t synced yet — the ranking updates after sync.';

  @override
  String get join_sheet_title => 'How to take part';

  @override
  String get join_option_ranked => 'Create a habit and join the ranking';

  @override
  String get join_option_ranked_hint =>
      'The habit is added to your list; its marks count for the ranking.';

  @override
  String get join_option_unranked => 'Join without the ranking';

  @override
  String get join_option_unranked_hint =>
      'You can create a ranked habit later.';

  @override
  String get community_joined_ranked => 'Habit created, you\'re in the ranking';

  @override
  String get community_ranked_habit_created =>
      'The habit was created and is ranked';

  @override
  String get community_error_not_synced =>
      'Couldn\'t upload the habit — nothing was changed. Check your connection and try again.';

  @override
  String get community_create_habit_title => 'Habit for the ranking';

  @override
  String get community_create_habit_action => 'Create habit';

  @override
  String get create_habit_name_label => 'Name';

  @override
  String get create_habit_target_label => 'Target per session';

  @override
  String get create_habit_hint =>
      'The target is saved in the habit\'s description. The schedule is suggested by the template; changing it does not change the template.';

  @override
  String create_habit_similar(String title) {
    return 'You already have a similar habit: “$title”.';
  }

  @override
  String create_habit_description(String description, String target) {
    return '$description Target: $target per session.';
  }

  @override
  String get profile_title => 'Profile';

  @override
  String get nav_home => 'Home';

  @override
  String get nav_habits => 'Habits';

  @override
  String get habit_mark_done => 'Mark as done for today';

  @override
  String get habit_unmark_done => 'Undo today\'s completion';

  @override
  String get theme_settings => 'Dark theme';

  @override
  String get archive => 'Archive';

  @override
  String get notifications => 'Notifications';

  @override
  String get widgets => 'Widgets';

  @override
  String get about_app => 'About App';

  @override
  String get rate_us => 'Rate Us';

  @override
  String get share_app => 'Share App';

  @override
  String get feedback => 'Feedback';

  @override
  String get privacy_policy => 'Privacy Policy';

  @override
  String get sign_out => 'Sign Out';

  @override
  String get sign_out_confirmation_title => 'Sign Out';

  @override
  String get sign_out_confirmation_message =>
      'Are you sure you want to sign out?';

  @override
  String sign_out_unsynced_message(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count changes have not been synced yet and will be lost. Sign out anyway?',
      one:
          '1 change has not been synced yet and will be lost. Sign out anyway?',
    );
    return '$_temp0';
  }

  @override
  String get sign_out_anyway => 'Sign out anyway';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String app_version(int major, int minor, int patch) {
    return 'Version $major.$minor.$patch';
  }

  @override
  String get about_app_description =>
      'Go Habit is an app designed to help you build and maintain good habits. Track your progress, set reminders, and visualize your journey.';

  @override
  String privacy_policy_last_updated(String date) {
    return 'Last updated: $date';
  }

  @override
  String get privacy_policy_section1_title => '1. Information Collection';

  @override
  String get privacy_policy_section1_content =>
      'Go Habit app collects the following information:\n• Account information (email)\n• Habit and activity data\n• Device information (for diagnostics)';

  @override
  String get privacy_policy_section2_title => '2. Information Usage';

  @override
  String get privacy_policy_section2_content =>
      'We use the collected information for:\n• Providing core app functionality\n• Improving user experience\n• Sending notifications (only with your permission)';

  @override
  String get privacy_policy_section3_title => '3. Data Security';

  @override
  String get privacy_policy_section3_content =>
      'We implement modern security measures to protect your personal data. All data is stored in encrypted form and is not shared with third parties without your consent.';

  @override
  String get privacy_policy_section4_title => '4. Cookies';

  @override
  String get privacy_policy_section4_content =>
      'Our app does not use cookies in the traditional sense. However, we store local data on your device for optimal app performance.';

  @override
  String get privacy_policy_section5_title => '5. Consent';

  @override
  String get privacy_policy_section5_content =>
      'By using the Go Habit app, you agree to our privacy policy. If you have any questions, please contact us at support@gohabit.app';

  @override
  String privacy_policy_copyright(String year) {
    return '© $year Go Habit. All rights reserved.';
  }

  @override
  String community_recommended_schedule(String schedule) {
    return 'Recommended schedule: $schedule';
  }

  @override
  String community_leaderboard_period(String range) {
    return 'Week of $range';
  }

  @override
  String community_percent(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String valueString = valueNumberFormat.format(value);

    return '$valueString%';
  }

  @override
  String community_actions(int completed, int expected) {
    return '$completed/$expected';
  }

  @override
  String community_actions_semantics(int completed, int expected) {
    return '$completed of $expected scheduled done';
  }

  @override
  String community_success_weeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count successful weeks in a row',
      one: '$count successful week in a row',
    );
    return '$_temp0';
  }

  @override
  String get community_status_paused =>
      'Your habit was paused at the end of last week, so the week was not scored.';

  @override
  String get community_status_no_actions =>
      'Your schedule had nothing planned last week.';

  @override
  String community_this_week(String progress) {
    return 'This week (in progress): $progress';
  }

  @override
  String community_progress_days(int completed, int expected) {
    return '$completed/$expected days';
  }

  @override
  String community_progress_target(int completed, int expected) {
    return '$completed/$expected weekly target';
  }

  @override
  String community_progress_weekdays(int completed, int expected) {
    return '$completed/$expected scheduled days';
  }
}
