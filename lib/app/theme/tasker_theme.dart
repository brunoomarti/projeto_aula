import 'package:flutter/material.dart';

import 'tasker_colors.dart';

/// [ThemeData] alinhado ao Tasker web (sem `fromSeed`, que altera tons).
abstract final class TaskerTheme {
  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: TaskerColors.primary,
      onPrimary: Colors.white,
      surface: TaskerColors.appBackground,
      onSurface: TaskerColors.primaryText,
      secondary: TaskerColors.secondaryText,
      onSecondary: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: TaskerColors.appBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: TaskerColors.appBackground,
        foregroundColor: TaskerColors.primaryText,
        elevation: 0,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: TaskerColors.primaryText),
        bodyMedium: TextStyle(color: TaskerColors.secondaryText),
        bodySmall: TextStyle(color: TaskerColors.mutedText),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: TaskerColors.primary,
          foregroundColor: Colors.white,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TaskerColors.primary;
          }
          return null;
        }),
      ),
    );
  }
}
