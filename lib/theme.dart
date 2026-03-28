import 'package:flutter/material.dart';

ThemeData _baseTheme(ColorScheme colorScheme) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}

final ThemeData appThemeLight = _baseTheme(
  ColorScheme.fromSeed(
    seedColor: const Color(0xFF7A002B),
    brightness: Brightness.light,
  ).copyWith(
    primary: const Color(0xFF7A002B),
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFFFD9E2),
    onPrimaryContainer: const Color(0xFF3E0014),
    secondary: const Color(0xFFAC1634),
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFFFFDAD9),
    onSecondaryContainer: const Color(0xFF41000A),
    tertiary: const Color(0xFF5B002C),
    tertiaryContainer: const Color(0xFFFFD9E4),
    surface: const Color(0xFFFFF8F8),
    surfaceContainerHighest: const Color(0xFFF9EBEF),
    outlineVariant: const Color(0xFFE5D1D5),
    onSurfaceVariant: const Color(0xFF514347),
  ),
);

final ThemeData appThemeDark = _baseTheme(
  ColorScheme.fromSeed(
    seedColor: const Color(0xFF7A002B),
    brightness: Brightness.dark,
  ).copyWith(
    primary: const Color(0xFF7A002B),
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFF5B002C),
    onPrimaryContainer: const Color(0xFFFFD9E4),
    secondary: const Color(0xFFAC1634),
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFF900021),
    onSecondaryContainer: const Color(0xFFFFDAD9),
    tertiary: const Color(0xFFE77291),
    tertiaryContainer: const Color(0xFF5B002C),
    surface: const Color(0xFF000000), // Pure Black surface
    onSurface: const Color(0xFFECE0E1),
    surfaceContainerHighest: const Color(0xFF1E1416), // Dark Burgundy/Rustic Red tone for cards
    outlineVariant: const Color(0xFF333333),
    onSurfaceVariant: const Color(0xFFD1C1C4),
  ),
);
