import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru')
  ];

  /// No description provided for @welcome_back.
  ///
  /// In en, this message translates to:
  /// **'Welcome back to Go Habit'**
  String get welcome_back;

  /// No description provided for @dont_have_account.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign Up'**
  String get dont_have_account;

  /// No description provided for @registration.
  ///
  /// In en, this message translates to:
  /// **'Registration'**
  String get registration;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @sign_in.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get sign_in;

  /// No description provided for @create_account.
  ///
  /// In en, this message translates to:
  /// **'Create a Go Habit account'**
  String get create_account;

  /// No description provided for @already_have_account.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Log In'**
  String get already_have_account;

  /// Welcome message with email
  ///
  /// In en, this message translates to:
  /// **'Welcome, {email}!'**
  String welcomeMessage(String email);

  /// No description provided for @app_description_title.
  ///
  /// In en, this message translates to:
  /// **'Go Habit app will help you:'**
  String get app_description_title;

  /// No description provided for @habit_tracking_feature.
  ///
  /// In en, this message translates to:
  /// **'Track your habits and completion streaks!'**
  String get habit_tracking_feature;

  /// No description provided for @daily_habits_feature.
  ///
  /// In en, this message translates to:
  /// **'Create and track daily habits to achieve goals'**
  String get daily_habits_feature;

  /// No description provided for @analytics_feature.
  ///
  /// In en, this message translates to:
  /// **'Progress analysis with charts and cubes!'**
  String get analytics_feature;

  /// No description provided for @visualization_feature.
  ///
  /// In en, this message translates to:
  /// **'Visualize your progress and stay motivated'**
  String get visualization_feature;

  /// No description provided for @reminders_feature.
  ///
  /// In en, this message translates to:
  /// **'Get reminders and motivational phrases!'**
  String get reminders_feature;

  /// No description provided for @notifications_feature.
  ///
  /// In en, this message translates to:
  /// **'Customize notifications to remember your habits'**
  String get notifications_feature;

  /// No description provided for @widgets_feature.
  ///
  /// In en, this message translates to:
  /// **'Habit widgets right on your home screen!'**
  String get widgets_feature;

  /// No description provided for @customWidgets_feature.
  ///
  /// In en, this message translates to:
  /// **'Customize widgets you want to see on home screen'**
  String get customWidgets_feature;

  /// No description provided for @start_tracking_button.
  ///
  /// In en, this message translates to:
  /// **'Start habit tracking'**
  String get start_tracking_button;

  /// No description provided for @password_label.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password_label;

  /// No description provided for @password_required.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get password_required;

  /// No description provided for @password_length.
  ///
  /// In en, this message translates to:
  /// **'Password must contain at least 6 characters'**
  String get password_length;

  /// No description provided for @confirm_password_label.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirm_password_label;

  /// No description provided for @confirm_password_required.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get confirm_password_required;

  /// No description provided for @passwords_dont_match.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get passwords_dont_match;

  /// No description provided for @email_label.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email_label;

  /// No description provided for @email_required.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get email_required;

  /// No description provided for @email_invalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get email_invalid;

  /// No description provided for @auth_sign_in_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to keep your habit streaks going'**
  String get auth_sign_in_subtitle;

  /// No description provided for @auth_sign_up_subtitle.
  ///
  /// In en, this message translates to:
  /// **'All you need is an email and a password'**
  String get auth_sign_up_subtitle;

  /// No description provided for @auth_forgot_password.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get auth_forgot_password;

  /// No description provided for @auth_no_account.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get auth_no_account;

  /// No description provided for @auth_create_account_action.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get auth_create_account_action;

  /// No description provided for @auth_have_account.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get auth_have_account;

  /// No description provided for @email_hint.
  ///
  /// In en, this message translates to:
  /// **'name@example.com'**
  String get email_hint;

  /// No description provided for @password_show.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get password_show;

  /// No description provided for @password_hide.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get password_hide;

  /// No description provided for @password_letters_digits.
  ///
  /// In en, this message translates to:
  /// **'Password must contain letters and digits'**
  String get password_letters_digits;

  /// No description provided for @password_req_length.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get password_req_length;

  /// No description provided for @password_req_letters_digits.
  ///
  /// In en, this message translates to:
  /// **'Letters and digits'**
  String get password_req_letters_digits;

  /// No description provided for @auth_check_email_title.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get auth_check_email_title;

  /// No description provided for @auth_confirm_email_message.
  ///
  /// In en, this message translates to:
  /// **'We sent a confirmation link to {email}. Follow the link, then sign in.'**
  String auth_confirm_email_message(String email);

  /// No description provided for @auth_check_email_hint.
  ///
  /// In en, this message translates to:
  /// **'No email? Check your spam folder. If you already have an account with this address, just sign in or reset your password.'**
  String get auth_check_email_hint;

  /// No description provided for @auth_resend_email.
  ///
  /// In en, this message translates to:
  /// **'Resend email'**
  String get auth_resend_email;

  /// No description provided for @auth_resend_in.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds} s'**
  String auth_resend_in(int seconds);

  /// No description provided for @auth_email_resent.
  ///
  /// In en, this message translates to:
  /// **'Email sent again'**
  String get auth_email_resent;

  /// No description provided for @auth_back_to_sign_in.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get auth_back_to_sign_in;

  /// No description provided for @auth_reset_title.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get auth_reset_title;

  /// No description provided for @auth_reset_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your account email and we\'ll send you a reset link'**
  String get auth_reset_subtitle;

  /// No description provided for @auth_reset_send.
  ///
  /// In en, this message translates to:
  /// **'Send link'**
  String get auth_reset_send;

  /// No description provided for @auth_reset_sent_message.
  ///
  /// In en, this message translates to:
  /// **'If an account with {email} exists, we\'ve sent it a password reset link.'**
  String auth_reset_sent_message(String email);

  /// No description provided for @auth_reset_sent_hint.
  ///
  /// In en, this message translates to:
  /// **'Open the email on this device so the link opens in the app. The link expires after a while.'**
  String get auth_reset_sent_hint;

  /// No description provided for @auth_new_password_title.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get auth_new_password_title;

  /// No description provided for @auth_new_password_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password for your account'**
  String get auth_new_password_subtitle;

  /// No description provided for @auth_new_password_label.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get auth_new_password_label;

  /// No description provided for @auth_new_password_save.
  ///
  /// In en, this message translates to:
  /// **'Save password'**
  String get auth_new_password_save;

  /// No description provided for @auth_password_updated.
  ///
  /// In en, this message translates to:
  /// **'Password updated'**
  String get auth_password_updated;

  /// No description provided for @auth_later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get auth_later;

  /// No description provided for @auth_error_invalid_credentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password. Check your details or reset your password.'**
  String get auth_error_invalid_credentials;

  /// No description provided for @auth_error_email_not_confirmed.
  ///
  /// In en, this message translates to:
  /// **'Your email is not confirmed yet. Follow the link from the email we sent after sign-up.'**
  String get auth_error_email_not_confirmed;

  /// No description provided for @auth_error_user_exists.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists. Sign in or reset your password.'**
  String get auth_error_user_exists;

  /// No description provided for @auth_error_weak_password.
  ///
  /// In en, this message translates to:
  /// **'This password is too weak. Use at least 6 characters with letters and digits.'**
  String get auth_error_weak_password;

  /// No description provided for @auth_error_same_password.
  ///
  /// In en, this message translates to:
  /// **'The new password must differ from the current one.'**
  String get auth_error_same_password;

  /// No description provided for @auth_error_invalid_email.
  ///
  /// In en, this message translates to:
  /// **'This email can\'t be used. Check the address.'**
  String get auth_error_invalid_email;

  /// No description provided for @auth_error_signup_disabled.
  ///
  /// In en, this message translates to:
  /// **'Sign-up is currently unavailable. Try again later.'**
  String get auth_error_signup_disabled;

  /// No description provided for @auth_error_rate_limited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a few minutes and try again.'**
  String get auth_error_rate_limited;

  /// No description provided for @auth_error_network.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the server. Check your connection and try again.'**
  String get auth_error_network;

  /// No description provided for @auth_error_link_invalid.
  ///
  /// In en, this message translates to:
  /// **'This link is invalid or has expired. Request a new one.'**
  String get auth_error_link_invalid;

  /// No description provided for @auth_error_session_expired.
  ///
  /// In en, this message translates to:
  /// **'The time to change your password has run out. Request a new link.'**
  String get auth_error_session_expired;

  /// No description provided for @auth_error_unknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get auth_error_unknown;

  /// No description provided for @communities_title.
  ///
  /// In en, this message translates to:
  /// **'Communities'**
  String get communities_title;

  /// No description provided for @communities_tab_catalog.
  ///
  /// In en, this message translates to:
  /// **'Catalog'**
  String get communities_tab_catalog;

  /// No description provided for @communities_tab_mine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get communities_tab_mine;

  /// No description provided for @communities_intro.
  ///
  /// In en, this message translates to:
  /// **'Join communities and compete in the weekly ranking with a habit from the template — or just be a member. Your notes and other habits stay private.'**
  String get communities_intro;

  /// No description provided for @communities_search_hint.
  ///
  /// In en, this message translates to:
  /// **'Search habits'**
  String get communities_search_hint;

  /// No description provided for @communities_filter_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get communities_filter_all;

  /// No description provided for @communities_members.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} member} other{{count} members}}'**
  String communities_members(int count);

  /// No description provided for @communities_no_members_yet.
  ///
  /// In en, this message translates to:
  /// **'No members yet'**
  String get communities_no_members_yet;

  /// No description provided for @communities_joined_badge.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get communities_joined_badge;

  /// No description provided for @communities_empty_search.
  ///
  /// In en, this message translates to:
  /// **'Nothing found. Try another search or category.'**
  String get communities_empty_search;

  /// No description provided for @communities_empty_mine.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t joined any community yet.'**
  String get communities_empty_mine;

  /// No description provided for @communities_browse_catalog.
  ///
  /// In en, this message translates to:
  /// **'Browse the catalog'**
  String get communities_browse_catalog;

  /// No description provided for @communities_offline_banner.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline — showing saved data. Joining and rankings need a connection.'**
  String get communities_offline_banner;

  /// No description provided for @communities_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load communities.'**
  String get communities_load_failed;

  /// No description provided for @communities_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get communities_retry;

  /// No description provided for @unit_pages.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} page} other{{count} pages}}'**
  String unit_pages(int count);

  /// No description provided for @unit_minutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} minute} other{{count} minutes}}'**
  String unit_minutes(int count);

  /// No description provided for @unit_steps.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} step} other{{count} steps}}'**
  String unit_steps(int count);

  /// No description provided for @unit_glasses.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} glass} other{{count} glasses}}'**
  String unit_glasses(int count);

  /// No description provided for @unit_hours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} hour} other{{count} hours}}'**
  String unit_hours(int count);

  /// No description provided for @community_recommended_target.
  ///
  /// In en, this message translates to:
  /// **'Recommended target: {target} per session'**
  String community_recommended_target(String target);

  /// No description provided for @community_join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get community_join;

  /// No description provided for @community_leave.
  ///
  /// In en, this message translates to:
  /// **'Leave community'**
  String get community_leave;

  /// No description provided for @community_leave_title.
  ///
  /// In en, this message translates to:
  /// **'Leave this community?'**
  String get community_leave_title;

  /// No description provided for @community_leave_message.
  ///
  /// In en, this message translates to:
  /// **'Your ranked habit stays in your list with its history. You will disappear from the ranking; if you come back, days before rejoining won\'t count.'**
  String get community_leave_message;

  /// No description provided for @community_leave_confirm.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get community_leave_confirm;

  /// No description provided for @community_member_since.
  ///
  /// In en, this message translates to:
  /// **'Member since {date}'**
  String community_member_since(DateTime date);

  /// No description provided for @community_leaderboard_title.
  ///
  /// In en, this message translates to:
  /// **'Last week\'s ranking'**
  String get community_leaderboard_title;

  /// No description provided for @community_retired.
  ///
  /// In en, this message translates to:
  /// **'This community is closed to new members.'**
  String get community_retired;

  /// No description provided for @community_joined.
  ///
  /// In en, this message translates to:
  /// **'You joined the community'**
  String get community_joined;

  /// No description provided for @community_left.
  ///
  /// In en, this message translates to:
  /// **'You left the community. Your habit is kept.'**
  String get community_left;

  /// No description provided for @community_error_offline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Try again when you\'re connected.'**
  String get community_error_offline;

  /// No description provided for @community_error_network.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the server. Please try again.'**
  String get community_error_network;

  /// No description provided for @community_error_not_allowed.
  ///
  /// In en, this message translates to:
  /// **'Not available: the community is closed.'**
  String get community_error_not_allowed;

  /// No description provided for @community_error_unauthorized.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Please sign in again.'**
  String get community_error_unauthorized;

  /// No description provided for @community_error_unknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get community_error_unknown;

  /// No description provided for @habits_schedule_label.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get habits_schedule_label;

  /// No description provided for @habits_schedule_option_daily.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get habits_schedule_option_daily;

  /// No description provided for @habits_schedule_option_weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly goal'**
  String get habits_schedule_option_weekly;

  /// No description provided for @habits_schedule_option_weekdays.
  ///
  /// In en, this message translates to:
  /// **'On days'**
  String get habits_schedule_option_weekdays;

  /// No description provided for @habits_schedule_daily.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get habits_schedule_daily;

  /// No description provided for @habits_schedule_times_per_week.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{once a week} =2{twice a week} other{{count} times a week}}'**
  String habits_schedule_times_per_week(int count);

  /// No description provided for @habits_schedule_weekly_summary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Once a week, any day} =2{Twice a week, any days} other{{count} times a week, any days}}'**
  String habits_schedule_weekly_summary(int count);

  /// No description provided for @habits_weekly_target_label.
  ///
  /// In en, this message translates to:
  /// **'Times per week'**
  String get habits_weekly_target_label;

  /// No description provided for @habits_weekdays_label.
  ///
  /// In en, this message translates to:
  /// **'Weekdays'**
  String get habits_weekdays_label;

  /// No description provided for @habits_weekdays_required.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one day'**
  String get habits_weekdays_required;

  /// No description provided for @habits_weekday_1.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get habits_weekday_1;

  /// No description provided for @habits_weekday_2.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get habits_weekday_2;

  /// No description provided for @habits_weekday_3.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get habits_weekday_3;

  /// No description provided for @habits_weekday_4.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get habits_weekday_4;

  /// No description provided for @habits_weekday_5.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get habits_weekday_5;

  /// No description provided for @habits_weekday_6.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get habits_weekday_6;

  /// No description provided for @habits_weekday_7.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get habits_weekday_7;

  /// No description provided for @habits_streak_weeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count}-week streak} other{{count}-week streak}}'**
  String habits_streak_weeks(int count);

  /// No description provided for @habits_streak_occurrences.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} in a row} other{{count} in a row}}'**
  String habits_streak_occurrences(int count);

  /// No description provided for @habits_week_target_progress.
  ///
  /// In en, this message translates to:
  /// **'{done}/{goal} this week'**
  String habits_week_target_progress(int done, int goal);

  /// No description provided for @habits_weekdays_progress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {goal} days this week'**
  String habits_weekdays_progress(int done, int goal);

  /// No description provided for @habits_not_today.
  ///
  /// In en, this message translates to:
  /// **'Not scheduled today'**
  String get habits_not_today;

  /// No description provided for @habits_section_week.
  ///
  /// In en, this message translates to:
  /// **'Weekly goals'**
  String get habits_section_week;

  /// No description provided for @habits_section_other_days.
  ///
  /// In en, this message translates to:
  /// **'On other days'**
  String get habits_section_other_days;

  /// No description provided for @habits_week_goals.
  ///
  /// In en, this message translates to:
  /// **'Weekly goals: {done} of {total}'**
  String habits_week_goals(int done, int total);

  /// No description provided for @habits_schedule_change_title.
  ///
  /// In en, this message translates to:
  /// **'Change the schedule type?'**
  String get habits_schedule_change_title;

  /// No description provided for @habits_schedule_change_message.
  ///
  /// In en, this message translates to:
  /// **'Your current streak will start over: each schedule type counts streaks differently. Your completion history is kept.'**
  String get habits_schedule_change_message;

  /// No description provided for @habits_schedule_change_confirm.
  ///
  /// In en, this message translates to:
  /// **'Change schedule'**
  String get habits_schedule_change_confirm;

  /// No description provided for @social_best_streak_days.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{day} other{days}} in a row — best streak'**
  String social_best_streak_days(int count);

  /// No description provided for @social_best_streak_weeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{week} other{weeks}} in a row — best streak'**
  String social_best_streak_weeks(int count);

  /// No description provided for @social_best_streak_occurrences.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{time} other{times}} in a row — best streak'**
  String social_best_streak_occurrences(int count);

  /// No description provided for @habits_title.
  ///
  /// In en, this message translates to:
  /// **'Habits'**
  String get habits_title;

  /// No description provided for @habits_add.
  ///
  /// In en, this message translates to:
  /// **'Add habit'**
  String get habits_add;

  /// No description provided for @habits_actions.
  ///
  /// In en, this message translates to:
  /// **'Actions for “{title}”'**
  String habits_actions(String title);

  /// No description provided for @habits_category_label.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get habits_category_label;

  /// No description provided for @habits_category_other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get habits_category_other;

  /// No description provided for @habits_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get habits_delete;

  /// No description provided for @habits_delete_title.
  ///
  /// In en, this message translates to:
  /// **'Delete “{title}”?'**
  String habits_delete_title(String title);

  /// No description provided for @habits_delete_message.
  ///
  /// In en, this message translates to:
  /// **'The habit and its whole history will be deleted on all devices. To take a break instead, pause it — the history is kept.'**
  String get habits_delete_message;

  /// No description provided for @habits_description_label.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get habits_description_label;

  /// No description provided for @habits_discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get habits_discard;

  /// No description provided for @habits_discard_message.
  ///
  /// In en, this message translates to:
  /// **'Your changes haven\'t been saved.'**
  String get habits_discard_message;

  /// No description provided for @habits_discard_title.
  ///
  /// In en, this message translates to:
  /// **'Leave without saving?'**
  String get habits_discard_title;

  /// No description provided for @habits_keep_editing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get habits_keep_editing;

  /// No description provided for @habits_done_today.
  ///
  /// In en, this message translates to:
  /// **'done today'**
  String get habits_done_today;

  /// No description provided for @habits_not_done_today.
  ///
  /// In en, this message translates to:
  /// **'not done today'**
  String get habits_not_done_today;

  /// No description provided for @habits_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get habits_edit;

  /// No description provided for @habits_edit_title.
  ///
  /// In en, this message translates to:
  /// **'Edit habit'**
  String get habits_edit_title;

  /// No description provided for @habits_new_title.
  ///
  /// In en, this message translates to:
  /// **'New habit'**
  String get habits_new_title;

  /// No description provided for @habits_empty_title.
  ///
  /// In en, this message translates to:
  /// **'Start with your first habit'**
  String get habits_empty_title;

  /// No description provided for @habits_empty_body.
  ///
  /// In en, this message translates to:
  /// **'One small daily step — in a couple of weeks it becomes part of your day.'**
  String get habits_empty_body;

  /// No description provided for @habits_empty_catalog.
  ///
  /// In en, this message translates to:
  /// **'Pick one from the community catalog'**
  String get habits_empty_catalog;

  /// No description provided for @habits_error_add.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add the habit. Please try again.'**
  String get habits_error_add;

  /// No description provided for @habits_error_completion.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the mark. Please try again.'**
  String get habits_error_completion;

  /// No description provided for @habits_error_delete.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the habit. Please try again.'**
  String get habits_error_delete;

  /// No description provided for @habits_error_generic.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the change. Please try again.'**
  String get habits_error_generic;

  /// No description provided for @habits_error_load.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your habits.'**
  String get habits_error_load;

  /// No description provided for @habits_error_update.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the habit. Please try again.'**
  String get habits_error_update;

  /// No description provided for @habits_icon_custom.
  ///
  /// In en, this message translates to:
  /// **'Your own emoji'**
  String get habits_icon_custom;

  /// No description provided for @habits_icon_label.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get habits_icon_label;

  /// No description provided for @habits_icon_single.
  ///
  /// In en, this message translates to:
  /// **'Enter a single emoji'**
  String get habits_icon_single;

  /// No description provided for @habits_loading.
  ///
  /// In en, this message translates to:
  /// **'Loading habits'**
  String get habits_loading;

  /// No description provided for @habits_name_label.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get habits_name_label;

  /// No description provided for @habits_name_required.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get habits_name_required;

  /// No description provided for @habits_nothing_today.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Nothing scheduled today: {count} habit is paused.} other{Nothing scheduled today: {count} habits are paused.}}'**
  String habits_nothing_today(int count);

  /// No description provided for @habits_pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get habits_pause;

  /// No description provided for @habits_paused_label.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get habits_paused_label;

  /// No description provided for @habits_resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get habits_resume;

  /// No description provided for @habits_section_paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get habits_section_paused;

  /// No description provided for @habits_section_today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get habits_section_today;

  /// No description provided for @habits_streak.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count}-day streak} other{{count}-day streak}}'**
  String habits_streak(int count);

  /// No description provided for @habits_today_all_done.
  ///
  /// In en, this message translates to:
  /// **'All done for today 🎉'**
  String get habits_today_all_done;

  /// No description provided for @habits_today_loading.
  ///
  /// In en, this message translates to:
  /// **'Counting progress…'**
  String get habits_today_loading;

  /// No description provided for @habits_today_nothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled for today'**
  String get habits_today_nothing;

  /// No description provided for @habits_today_progress.
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total} done'**
  String habits_today_progress(int completed, int total);

  /// No description provided for @social_accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get social_accept;

  /// No description provided for @social_add_friend.
  ///
  /// In en, this message translates to:
  /// **'Add friend'**
  String get social_add_friend;

  /// No description provided for @social_already_accepted.
  ///
  /// In en, this message translates to:
  /// **'Already accepted — you\'re friends'**
  String get social_already_accepted;

  /// No description provided for @social_avatar_default.
  ///
  /// In en, this message translates to:
  /// **'Pixel avatar from the nickname'**
  String get social_avatar_default;

  /// No description provided for @social_avatar_label.
  ///
  /// In en, this message translates to:
  /// **'Avatar'**
  String get social_avatar_label;

  /// No description provided for @social_bio_label.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get social_bio_label;

  /// No description provided for @social_block.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get social_block;

  /// No description provided for @social_block_message.
  ///
  /// In en, this message translates to:
  /// **'Your friendship and requests will be removed. They won\'t be able to find you or send requests, and won\'t be told about the block.'**
  String get social_block_message;

  /// No description provided for @social_block_title.
  ///
  /// In en, this message translates to:
  /// **'Block this user?'**
  String get social_block_title;

  /// No description provided for @social_blocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get social_blocked;

  /// No description provided for @social_cancel_request.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get social_cancel_request;

  /// No description provided for @social_edit_profile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get social_edit_profile;

  /// No description provided for @social_error_blocked_by_me.
  ///
  /// In en, this message translates to:
  /// **'You blocked this user. Unblock them first.'**
  String get social_error_blocked_by_me;

  /// No description provided for @social_error_invalid_profile.
  ///
  /// In en, this message translates to:
  /// **'The server rejected the profile. Check the nickname and the description.'**
  String get social_error_invalid_profile;

  /// No description provided for @social_error_network.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the server. Please try again.'**
  String get social_error_network;

  /// No description provided for @social_error_not_allowed.
  ///
  /// In en, this message translates to:
  /// **'This action isn\'t available.'**
  String get social_error_not_allowed;

  /// No description provided for @social_error_not_found.
  ///
  /// In en, this message translates to:
  /// **'User not found.'**
  String get social_error_not_found;

  /// No description provided for @social_error_offline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Friends and profile changes need a connection.'**
  String get social_error_offline;

  /// No description provided for @social_error_unauthorized.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Please sign in again.'**
  String get social_error_unauthorized;

  /// No description provided for @social_error_unknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get social_error_unknown;

  /// No description provided for @social_friend_removed.
  ///
  /// In en, this message translates to:
  /// **'Removed from friends'**
  String get social_friend_removed;

  /// No description provided for @social_friends_badge.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get social_friends_badge;

  /// No description provided for @social_friends_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Friends} one{{count} friend} other{{count} friends}}'**
  String social_friends_count(int count);

  /// No description provided for @social_friends_title.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get social_friends_title;

  /// No description provided for @social_incoming.
  ///
  /// In en, this message translates to:
  /// **'Incoming requests'**
  String get social_incoming;

  /// No description provided for @social_incoming_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} new request} other{{count} new requests}}'**
  String social_incoming_count(int count);

  /// No description provided for @social_more_actions.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get social_more_actions;

  /// No description provided for @social_my_communities.
  ///
  /// In en, this message translates to:
  /// **'My communities'**
  String get social_my_communities;

  /// No description provided for @social_nickname_available.
  ///
  /// In en, this message translates to:
  /// **'Nickname is available'**
  String get social_nickname_available;

  /// No description provided for @social_nickname_callout.
  ///
  /// In en, this message translates to:
  /// **'Choose a nickname so friends can find you.'**
  String get social_nickname_callout;

  /// No description provided for @social_nickname_characters.
  ///
  /// In en, this message translates to:
  /// **'Only Latin letters, digits and “_”'**
  String get social_nickname_characters;

  /// No description provided for @social_nickname_checking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get social_nickname_checking;

  /// No description provided for @social_nickname_hint.
  ///
  /// In en, this message translates to:
  /// **'3–20 characters: Latin letters, digits and “_”, starting with a letter. Case doesn\'t matter for uniqueness.'**
  String get social_nickname_hint;

  /// No description provided for @social_nickname_label.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get social_nickname_label;

  /// No description provided for @social_nickname_required.
  ///
  /// In en, this message translates to:
  /// **'Enter a nickname'**
  String get social_nickname_required;

  /// No description provided for @social_nickname_reserved.
  ///
  /// In en, this message translates to:
  /// **'This nickname is reserved'**
  String get social_nickname_reserved;

  /// No description provided for @social_nickname_start_letter.
  ///
  /// In en, this message translates to:
  /// **'The nickname must start with a letter'**
  String get social_nickname_start_letter;

  /// No description provided for @social_nickname_taken.
  ///
  /// In en, this message translates to:
  /// **'This nickname is taken'**
  String get social_nickname_taken;

  /// No description provided for @social_nickname_too_long.
  ///
  /// In en, this message translates to:
  /// **'At most {max} characters'**
  String social_nickname_too_long(int max);

  /// No description provided for @social_nickname_too_short.
  ///
  /// In en, this message translates to:
  /// **'At least {min} characters'**
  String social_nickname_too_short(int min);

  /// No description provided for @social_nickname_unchecked.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check — it will be checked on save'**
  String get social_nickname_unchecked;

  /// No description provided for @social_no_friends.
  ///
  /// In en, this message translates to:
  /// **'No friends yet. Find someone by nickname above.'**
  String get social_no_friends;

  /// No description provided for @social_no_nickname.
  ///
  /// In en, this message translates to:
  /// **'No nickname yet'**
  String get social_no_nickname;

  /// No description provided for @social_no_requests.
  ///
  /// In en, this message translates to:
  /// **'No requests.'**
  String get social_no_requests;

  /// No description provided for @social_no_shared_communities.
  ///
  /// In en, this message translates to:
  /// **'No shared communities yet.'**
  String get social_no_shared_communities;

  /// No description provided for @social_now_friends.
  ///
  /// In en, this message translates to:
  /// **'You\'re friends now'**
  String get social_now_friends;

  /// No description provided for @social_offline_banner.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline — showing the saved list.'**
  String get social_offline_banner;

  /// No description provided for @social_outgoing.
  ///
  /// In en, this message translates to:
  /// **'Sent requests'**
  String get social_outgoing;

  /// No description provided for @social_privacy_always_private.
  ///
  /// In en, this message translates to:
  /// **'Your email, notes, habit names and history are never shown to others.'**
  String get social_privacy_always_private;

  /// No description provided for @social_privacy_communities.
  ///
  /// In en, this message translates to:
  /// **'My communities'**
  String get social_privacy_communities;

  /// No description provided for @social_privacy_communities_hint.
  ///
  /// In en, this message translates to:
  /// **'Who sees which communities you\'re in (others only see the ones you share).'**
  String get social_privacy_communities_hint;

  /// No description provided for @social_privacy_intro.
  ///
  /// In en, this message translates to:
  /// **'Your nickname, avatar and bio are visible to anyone who finds you. The rest is up to you.'**
  String get social_privacy_intro;

  /// No description provided for @social_privacy_stats.
  ///
  /// In en, this message translates to:
  /// **'Statistics and name in rankings'**
  String get social_privacy_stats;

  /// No description provided for @social_privacy_stats_hint.
  ///
  /// In en, this message translates to:
  /// **'Who sees your active habits, weekly regularity and your nickname in community rankings. Hiding it from everyone also leaves you out of friends\' rankings.'**
  String get social_privacy_stats_hint;

  /// No description provided for @social_privacy_title.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get social_privacy_title;

  /// No description provided for @social_profile_saved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get social_profile_saved;

  /// No description provided for @social_profile_title.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get social_profile_title;

  /// No description provided for @social_ranking_empty.
  ///
  /// In en, this message translates to:
  /// **'Add friends to compare progress.'**
  String get social_ranking_empty;

  /// No description provided for @social_ranking_rules.
  ///
  /// In en, this message translates to:
  /// **'This week\'s ranking across all active habits: the share of scheduled days with a mark, from Monday to today and not before a habit was created. Friends who hide their statistics aren\'t shown.'**
  String get social_ranking_rules;

  /// No description provided for @social_reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get social_reject;

  /// No description provided for @social_remove_friend.
  ///
  /// In en, this message translates to:
  /// **'Remove friend'**
  String get social_remove_friend;

  /// No description provided for @social_remove_message.
  ///
  /// In en, this message translates to:
  /// **'You can send a request again later.'**
  String get social_remove_message;

  /// No description provided for @social_remove_title.
  ///
  /// In en, this message translates to:
  /// **'Remove this friend?'**
  String get social_remove_title;

  /// No description provided for @social_request_accepted_notice.
  ///
  /// In en, this message translates to:
  /// **'{handle} accepted your request'**
  String social_request_accepted_notice(String handle);

  /// No description provided for @social_request_cancelled.
  ///
  /// In en, this message translates to:
  /// **'Request cancelled'**
  String get social_request_cancelled;

  /// No description provided for @social_request_rejected.
  ///
  /// In en, this message translates to:
  /// **'Request rejected'**
  String get social_request_rejected;

  /// No description provided for @social_request_sent.
  ///
  /// In en, this message translates to:
  /// **'Request sent'**
  String get social_request_sent;

  /// No description provided for @social_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get social_save;

  /// No description provided for @social_search_empty.
  ///
  /// In en, this message translates to:
  /// **'No user @{query}'**
  String social_search_empty(String query);

  /// No description provided for @social_search_hint.
  ///
  /// In en, this message translates to:
  /// **'Exact nickname'**
  String get social_search_hint;

  /// No description provided for @social_search_label.
  ///
  /// In en, this message translates to:
  /// **'Find by nickname'**
  String get social_search_label;

  /// No description provided for @social_set_nickname.
  ///
  /// In en, this message translates to:
  /// **'Set a nickname'**
  String get social_set_nickname;

  /// No description provided for @social_setup_subtitle.
  ///
  /// In en, this message translates to:
  /// **'A nickname lets friends find you and shows you in rankings. You can change it later.'**
  String get social_setup_subtitle;

  /// No description provided for @social_setup_title.
  ///
  /// In en, this message translates to:
  /// **'Choose a nickname'**
  String get social_setup_title;

  /// No description provided for @social_shared_communities.
  ///
  /// In en, this message translates to:
  /// **'Shared communities'**
  String get social_shared_communities;

  /// No description provided for @social_stat_active_habits.
  ///
  /// In en, this message translates to:
  /// **'active habits'**
  String get social_stat_active_habits;

  /// No description provided for @social_stat_best_streak.
  ///
  /// In en, this message translates to:
  /// **'best streak'**
  String get social_stat_best_streak;

  /// No description provided for @social_stat_friends.
  ///
  /// In en, this message translates to:
  /// **'friends'**
  String get social_stat_friends;

  /// No description provided for @social_stat_week.
  ///
  /// In en, this message translates to:
  /// **'this week ({completed} of {eligible} days)'**
  String social_stat_week(int completed, int eligible);

  /// No description provided for @social_stats_hidden.
  ///
  /// In en, this message translates to:
  /// **'This user hides their statistics.'**
  String get social_stats_hidden;

  /// No description provided for @social_stats_title.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get social_stats_title;

  /// No description provided for @social_tab_friends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get social_tab_friends;

  /// No description provided for @social_tab_ranking.
  ///
  /// In en, this message translates to:
  /// **'Ranking'**
  String get social_tab_ranking;

  /// No description provided for @social_tab_requests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get social_tab_requests;

  /// No description provided for @social_this_is_you.
  ///
  /// In en, this message translates to:
  /// **'That\'s you'**
  String get social_this_is_you;

  /// No description provided for @social_unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get social_unblock;

  /// No description provided for @social_user_blocked.
  ///
  /// In en, this message translates to:
  /// **'User blocked'**
  String get social_user_blocked;

  /// No description provided for @social_user_unblocked.
  ///
  /// In en, this message translates to:
  /// **'User unblocked'**
  String get social_user_unblocked;

  /// No description provided for @social_view_public_profile.
  ///
  /// In en, this message translates to:
  /// **'How others see me'**
  String get social_view_public_profile;

  /// No description provided for @social_visibility_everyone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get social_visibility_everyone;

  /// No description provided for @social_visibility_friends.
  ///
  /// In en, this message translates to:
  /// **'Friends only'**
  String get social_visibility_friends;

  /// No description provided for @social_visibility_nobody.
  ///
  /// In en, this message translates to:
  /// **'Nobody'**
  String get social_visibility_nobody;

  /// No description provided for @social_waiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for an answer'**
  String get social_waiting;

  /// No description provided for @community_rules_title.
  ///
  /// In en, this message translates to:
  /// **'How the ranking works'**
  String get community_rules_title;

  /// No description provided for @community_rules_body.
  ///
  /// In en, this message translates to:
  /// **'One habit created from the community\'s template, with its own schedule, takes part in the ranking. Results cover last week, Monday to Sunday. The ranking measures consistency with your schedule: a daily habit counts every day, selected weekdays count only those days, a weekly target counts the target (marks beyond it add nothing). Days before you joined or created the habit don\'t count, and a weekly target is prorated when you join mid-week. Ties go to more completed actions, then to more successful weeks in a row. The current week is shown separately and is ranked only once it is over. Others see only your profile name (or “Member”), your percentage and numbers.'**
  String get community_rules_body;

  /// No description provided for @community_ranked_habit.
  ///
  /// In en, this message translates to:
  /// **'Ranked habit: “{title}”'**
  String community_ranked_habit(String title);

  /// No description provided for @community_not_ranked.
  ///
  /// In en, this message translates to:
  /// **'You\'re not in the ranking yet. Create a habit from the template whenever you like.'**
  String get community_not_ranked;

  /// No description provided for @community_ranked_habit_missing.
  ///
  /// In en, this message translates to:
  /// **'Your ranked habit was deleted or hasn\'t reached this device yet.'**
  String get community_ranked_habit_missing;

  /// No description provided for @community_create_ranked_habit.
  ///
  /// In en, this message translates to:
  /// **'Create a ranked habit'**
  String get community_create_ranked_habit;

  /// No description provided for @community_week_progress.
  ///
  /// In en, this message translates to:
  /// **'This week: {completed} of {eligible} days'**
  String community_week_progress(int completed, int eligible);

  /// No description provided for @community_week_progress_none.
  ///
  /// In en, this message translates to:
  /// **'No counted days this week yet.'**
  String get community_week_progress_none;

  /// No description provided for @community_habit_paused.
  ///
  /// In en, this message translates to:
  /// **'The habit is paused — it isn\'t ranked.'**
  String get community_habit_paused;

  /// No description provided for @community_leaderboard_empty.
  ///
  /// In en, this message translates to:
  /// **'No results for last week yet: no member was ranked for all or part of it.'**
  String get community_leaderboard_empty;

  /// No description provided for @community_leaderboard_offline.
  ///
  /// In en, this message translates to:
  /// **'The ranking needs an internet connection.'**
  String get community_leaderboard_offline;

  /// No description provided for @community_leaderboard_failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the ranking.'**
  String get community_leaderboard_failed;

  /// No description provided for @community_member_fallback.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get community_member_fallback;

  /// No description provided for @community_you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get community_you;

  /// No description provided for @community_rank.
  ///
  /// In en, this message translates to:
  /// **'Rank {rank}'**
  String community_rank(int rank);

  /// No description provided for @community_my_rank.
  ///
  /// In en, this message translates to:
  /// **'Your rank: {rank} of {total}'**
  String community_my_rank(int rank, int total);

  /// No description provided for @community_not_ranked_yet.
  ///
  /// In en, this message translates to:
  /// **'Your results will appear in the ranking once your first week with a ranked habit is over.'**
  String get community_not_ranked_yet;

  /// No description provided for @community_unsynced_hint.
  ///
  /// In en, this message translates to:
  /// **'Some marks aren\'t synced yet — the ranking updates after sync.'**
  String get community_unsynced_hint;

  /// No description provided for @join_sheet_title.
  ///
  /// In en, this message translates to:
  /// **'How to take part'**
  String get join_sheet_title;

  /// No description provided for @join_option_ranked.
  ///
  /// In en, this message translates to:
  /// **'Create a habit and join the ranking'**
  String get join_option_ranked;

  /// No description provided for @join_option_ranked_hint.
  ///
  /// In en, this message translates to:
  /// **'The habit is added to your list; its marks count for the ranking.'**
  String get join_option_ranked_hint;

  /// No description provided for @join_option_unranked.
  ///
  /// In en, this message translates to:
  /// **'Join without the ranking'**
  String get join_option_unranked;

  /// No description provided for @join_option_unranked_hint.
  ///
  /// In en, this message translates to:
  /// **'You can create a ranked habit later.'**
  String get join_option_unranked_hint;

  /// No description provided for @community_joined_ranked.
  ///
  /// In en, this message translates to:
  /// **'Habit created, you\'re in the ranking'**
  String get community_joined_ranked;

  /// No description provided for @community_ranked_habit_created.
  ///
  /// In en, this message translates to:
  /// **'The habit was created and is ranked'**
  String get community_ranked_habit_created;

  /// No description provided for @community_error_not_synced.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t upload the habit — nothing was changed. Check your connection and try again.'**
  String get community_error_not_synced;

  /// No description provided for @community_create_habit_title.
  ///
  /// In en, this message translates to:
  /// **'Habit for the ranking'**
  String get community_create_habit_title;

  /// No description provided for @community_create_habit_action.
  ///
  /// In en, this message translates to:
  /// **'Create habit'**
  String get community_create_habit_action;

  /// No description provided for @create_habit_name_label.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get create_habit_name_label;

  /// No description provided for @create_habit_target_label.
  ///
  /// In en, this message translates to:
  /// **'Target per session'**
  String get create_habit_target_label;

  /// No description provided for @create_habit_hint.
  ///
  /// In en, this message translates to:
  /// **'The target is saved in the habit\'s description. The schedule is suggested by the template; changing it does not change the template.'**
  String get create_habit_hint;

  /// No description provided for @create_habit_similar.
  ///
  /// In en, this message translates to:
  /// **'You already have a similar habit: “{title}”.'**
  String create_habit_similar(String title);

  /// No description provided for @create_habit_description.
  ///
  /// In en, this message translates to:
  /// **'{description} Target: {target} per session.'**
  String create_habit_description(String description, String target);

  /// No description provided for @profile_title.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile_title;

  /// No description provided for @nav_home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get nav_home;

  /// No description provided for @nav_habits.
  ///
  /// In en, this message translates to:
  /// **'Habits'**
  String get nav_habits;

  /// No description provided for @habit_mark_done.
  ///
  /// In en, this message translates to:
  /// **'Mark as done for today'**
  String get habit_mark_done;

  /// No description provided for @habit_unmark_done.
  ///
  /// In en, this message translates to:
  /// **'Undo today\'s completion'**
  String get habit_unmark_done;

  /// No description provided for @theme_settings.
  ///
  /// In en, this message translates to:
  /// **'Dark theme'**
  String get theme_settings;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @widgets.
  ///
  /// In en, this message translates to:
  /// **'Widgets'**
  String get widgets;

  /// No description provided for @about_app.
  ///
  /// In en, this message translates to:
  /// **'About App'**
  String get about_app;

  /// No description provided for @rate_us.
  ///
  /// In en, this message translates to:
  /// **'Rate Us'**
  String get rate_us;

  /// No description provided for @share_app.
  ///
  /// In en, this message translates to:
  /// **'Share App'**
  String get share_app;

  /// No description provided for @feedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// No description provided for @privacy_policy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacy_policy;

  /// No description provided for @sign_out.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get sign_out;

  /// No description provided for @sign_out_confirmation_title.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get sign_out_confirmation_title;

  /// No description provided for @sign_out_confirmation_message.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get sign_out_confirmation_message;

  /// No description provided for @sign_out_unsynced_message.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 change has not been synced yet and will be lost. Sign out anyway?} other{{count} changes have not been synced yet and will be lost. Sign out anyway?}}'**
  String sign_out_unsynced_message(int count);

  /// No description provided for @sign_out_anyway.
  ///
  /// In en, this message translates to:
  /// **'Sign out anyway'**
  String get sign_out_anyway;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// App version with major, minor and patch numbers
  ///
  /// In en, this message translates to:
  /// **'Version {major}.{minor}.{patch}'**
  String app_version(int major, int minor, int patch);

  /// No description provided for @about_app_description.
  ///
  /// In en, this message translates to:
  /// **'Go Habit is an app designed to help you build and maintain good habits. Track your progress, set reminders, and visualize your journey.'**
  String get about_app_description;

  /// Last update date of the privacy policy
  ///
  /// In en, this message translates to:
  /// **'Last updated: {date}'**
  String privacy_policy_last_updated(String date);

  /// No description provided for @privacy_policy_section1_title.
  ///
  /// In en, this message translates to:
  /// **'1. Information Collection'**
  String get privacy_policy_section1_title;

  /// No description provided for @privacy_policy_section1_content.
  ///
  /// In en, this message translates to:
  /// **'Go Habit app collects the following information:\n• Account information (email)\n• Habit and activity data\n• Device information (for diagnostics)'**
  String get privacy_policy_section1_content;

  /// No description provided for @privacy_policy_section2_title.
  ///
  /// In en, this message translates to:
  /// **'2. Information Usage'**
  String get privacy_policy_section2_title;

  /// No description provided for @privacy_policy_section2_content.
  ///
  /// In en, this message translates to:
  /// **'We use the collected information for:\n• Providing core app functionality\n• Improving user experience\n• Sending notifications (only with your permission)'**
  String get privacy_policy_section2_content;

  /// No description provided for @privacy_policy_section3_title.
  ///
  /// In en, this message translates to:
  /// **'3. Data Security'**
  String get privacy_policy_section3_title;

  /// No description provided for @privacy_policy_section3_content.
  ///
  /// In en, this message translates to:
  /// **'We implement modern security measures to protect your personal data. All data is stored in encrypted form and is not shared with third parties without your consent.'**
  String get privacy_policy_section3_content;

  /// No description provided for @privacy_policy_section4_title.
  ///
  /// In en, this message translates to:
  /// **'4. Cookies'**
  String get privacy_policy_section4_title;

  /// No description provided for @privacy_policy_section4_content.
  ///
  /// In en, this message translates to:
  /// **'Our app does not use cookies in the traditional sense. However, we store local data on your device for optimal app performance.'**
  String get privacy_policy_section4_content;

  /// No description provided for @privacy_policy_section5_title.
  ///
  /// In en, this message translates to:
  /// **'5. Consent'**
  String get privacy_policy_section5_title;

  /// No description provided for @privacy_policy_section5_content.
  ///
  /// In en, this message translates to:
  /// **'By using the Go Habit app, you agree to our privacy policy. If you have any questions, please contact us at support@gohabit.app'**
  String get privacy_policy_section5_content;

  /// Copyright text with year
  ///
  /// In en, this message translates to:
  /// **'© {year} Go Habit. All rights reserved.'**
  String privacy_policy_copyright(String year);

  /// No description provided for @community_recommended_schedule.
  ///
  /// In en, this message translates to:
  /// **'Recommended schedule: {schedule}'**
  String community_recommended_schedule(String schedule);

  /// No description provided for @community_leaderboard_period.
  ///
  /// In en, this message translates to:
  /// **'Week of {range}'**
  String community_leaderboard_period(String range);

  /// No description provided for @community_percent.
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String community_percent(double value);

  /// No description provided for @community_actions.
  ///
  /// In en, this message translates to:
  /// **'{completed}/{expected}'**
  String community_actions(int completed, int expected);

  /// No description provided for @community_actions_semantics.
  ///
  /// In en, this message translates to:
  /// **'{completed} of {expected} scheduled done'**
  String community_actions_semantics(int completed, int expected);

  /// No description provided for @community_success_weeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} successful week in a row} other{{count} successful weeks in a row}}'**
  String community_success_weeks(int count);

  /// No description provided for @community_status_paused.
  ///
  /// In en, this message translates to:
  /// **'Your habit was paused at the end of last week, so the week was not scored.'**
  String get community_status_paused;

  /// No description provided for @community_status_no_actions.
  ///
  /// In en, this message translates to:
  /// **'Your schedule had nothing planned last week.'**
  String get community_status_no_actions;

  /// No description provided for @community_this_week.
  ///
  /// In en, this message translates to:
  /// **'This week (in progress): {progress}'**
  String community_this_week(String progress);

  /// No description provided for @community_progress_days.
  ///
  /// In en, this message translates to:
  /// **'{completed}/{expected} days'**
  String community_progress_days(int completed, int expected);

  /// No description provided for @community_progress_target.
  ///
  /// In en, this message translates to:
  /// **'{completed}/{expected} weekly target'**
  String community_progress_target(int completed, int expected);

  /// No description provided for @community_progress_weekdays.
  ///
  /// In en, this message translates to:
  /// **'{completed}/{expected} scheduled days'**
  String community_progress_weekdays(int completed, int expected);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
