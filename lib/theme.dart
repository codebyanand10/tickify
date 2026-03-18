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
    seedColor: const Color(0xFF4F46E5), // indigo (cleaner in light mode)
    brightness: Brightness.light,
  ).copyWith(
    primary: const Color(0xFF4F46E5),
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFE7E7FF),
    onPrimaryContainer: const Color(0xFF1B1B6B),
    secondary: const Color(0xFF0F766E), // deep teal
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFFCCFBF1),
    onSecondaryContainer: const Color(0xFF083C36),
    tertiary: const Color(0xFF7C3AED), // violet accent
    tertiaryContainer: const Color(0xFFF1E8FF),
    surface: const Color(0xFFF7F7FB), // soft off-white
    surfaceContainerHighest: const Color(0xFFEFEFF6), // card/nav surfaces
    outlineVariant: const Color(0xFFD7D8E5),
    onSurfaceVariant: const Color(0xFF53556A),
  ),
);

final ThemeData appThemeDark = _baseTheme(
  ColorScheme.fromSeed(
    seedColor: const Color(0xFF7C7DFF),
    brightness: Brightness.dark,
  ).copyWith(
    secondary: const Color(0xFF20D4C3),
    tertiary: const Color(0xFF9A8CFF),
  ),
);
