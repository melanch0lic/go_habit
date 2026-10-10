import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/theme/app_theme.dart';
import 'package:go_habit/l10n/app_localizations.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

/// Создает обертку MaterialApp с темой для тестирования виджетов
/// Использует тему, соответствующую теме приложения
Widget makeTestableWidget({
  required Widget child,
  bool useDarkTheme = true,
}) {
  return MaterialApp(
    locale: const Locale('ru'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    // The app's real light and dark themes, so goldens show what users see.
    theme: useDarkTheme ? AppTheme.defaultTheme.darkTheme : AppTheme.defaultTheme.lightTheme,
    home: Scaffold(
      body: Center(
        child: child,
      ),
    ),
  );
}

/// Настройка экранов для golden тестов
Future<void> setupGoldenTest(WidgetTester tester, {Size? size}) async {
  await loadAppFonts(); // Загрузка шрифтов для корректного отображения символов
  tester.binding.window.physicalSizeTestValue = size ?? const Size(400, 300);
  tester.binding.window.devicePixelRatioTestValue = 1.0;

  addTearDown(() {
    tester.binding.window.clearPhysicalSizeTestValue();
    tester.binding.window.clearDevicePixelRatioTestValue();
  });
}

/// Проверка соответствия виджета эталонному снимку
Future<void> expectGoldenMatch({
  required WidgetTester tester,
  required Finder finder,
  required String goldenPath,
}) async {
  // Ожидаем завершения анимаций
  await tester.pumpAndSettle(const Duration(milliseconds: 500));

  // Проверяем соответствие эталонному снимку
  await expectLater(
    finder,
    matchesGoldenFile(goldenPath),
  );
}
