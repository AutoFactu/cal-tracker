import 'package:flutter/material.dart';

import '../ui/core/design_system.dart';

ThemeData buildTheme() {
  const textTheme = TextTheme(
    displayLarge: TextStyle(
      fontSize: 48,
      fontWeight: FontWeight.w700,
      height: 1.16,
      letterSpacing: 0,
      color: FreshColors.ink,
    ),
    headlineLarge: TextStyle(
      fontSize: 40,
      fontWeight: FontWeight.w700,
      height: 1.14,
      letterSpacing: 0,
      color: FreshColors.ink,
    ),
    headlineMedium: TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      height: 1.16,
      letterSpacing: 0,
      color: FreshColors.ink,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      height: 1.18,
      letterSpacing: 0,
      color: FreshColors.ink,
    ),
    titleMedium: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: 0,
      color: FreshColors.ink,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.35,
      letterSpacing: 0,
      color: FreshColors.inkSoft,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.35,
      letterSpacing: 0,
      color: FreshColors.inkSoft,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1,
      letterSpacing: 0,
      color: FreshColors.ink,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1,
      letterSpacing: 0,
      color: FreshColors.inkMuted,
    ),
  );

  return ThemeData(
    colorScheme: const ColorScheme.light(
      primary: FreshColors.lime,
      onPrimary: FreshColors.ink,
      primaryContainer: FreshColors.limeSoft,
      onPrimaryContainer: FreshColors.ink,
      secondary: FreshColors.water,
      onSecondary: FreshColors.ink,
      secondaryContainer: FreshColors.limeWash,
      onSecondaryContainer: FreshColors.ink,
      surface: FreshColors.surface,
      onSurface: FreshColors.ink,
      surfaceContainerHighest: FreshColors.surfaceSoft,
      error: FreshColors.coral,
      onError: FreshColors.surface,
      errorContainer: Color(0xffffe5e8),
      onErrorContainer: FreshColors.ink,
      outline: FreshColors.rule,
      outlineVariant: FreshColors.ruleSoft,
    ),
    scaffoldBackgroundColor: FreshColors.screen,
    fontFamily: 'SF Pro Text',
    fontFamilyFallback: const ['Roboto', 'Arial', 'sans-serif'],
    textTheme: textTheme,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      backgroundColor: FreshColors.screen,
      foregroundColor: FreshColors.ink,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.18,
        letterSpacing: 0,
        color: FreshColors.ink,
        fontFamily: 'SF Pro Display',
        fontFamilyFallback: ['Roboto', 'Arial', 'sans-serif'],
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: FreshColors.surface,
      labelStyle: const TextStyle(color: FreshColors.inkMuted),
      hintStyle: const TextStyle(color: FreshColors.inkMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: FreshColors.ruleSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: FreshColors.lime, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: FreshColors.coral),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: FreshColors.coral, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      color: FreshColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: FreshColors.lime,
        foregroundColor: FreshColors.ink,
        disabledBackgroundColor: FreshColors.surfaceMuted,
        disabledForegroundColor: FreshColors.inkMuted,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: FreshColors.ink,
        side: const BorderSide(color: FreshColors.rule),
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: FreshColors.ink,
        shape: const StadiumBorder(),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: FreshColors.ink,
        backgroundColor: FreshColors.surface,
        shape: const CircleBorder(),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: FreshColors.screen,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: FreshColors.screen,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
  );
}
