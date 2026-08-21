import 'package:flutter/material.dart';

import 'muse_colors.dart';
import 'muse_text_theme.dart';

/// Global ThemeData for Muse.
///
/// Enforces the aesthetic constraints: no pure white/black, no cool grays,
/// no gradients, no drop shadows, no glassmorphism. All elevation is zero;
/// emphasis comes from thin gold linework and the warm surfaces instead.
abstract final class MuseTheme {
  static ThemeData get light {
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: MuseColors.gold,
      onPrimary: MuseColors.baseSurface,
      secondary: MuseColors.aegean,
      onSecondary: MuseColors.baseSurface,
      error: MuseColors.error,
      onError: MuseColors.baseSurface,
      surface: MuseColors.baseSurface,
      onSurface: MuseColors.textPrimary,
      surfaceContainerHighest: MuseColors.cardSurface,
      onSurfaceVariant: MuseColors.textSecondary,
      outline: MuseColors.gold.withValues(alpha: 0.45),
      outlineVariant: MuseColors.gold.withValues(alpha: 0.25),
      shadow: Colors.transparent,
      scrim: MuseColors.textPrimary,
      inverseSurface: MuseColors.textPrimary,
      onInverseSurface: MuseColors.baseSurface,
      inversePrimary: MuseColors.gold.withValues(alpha: 0.8),
      surfaceTint: Colors.transparent,
    );

    final baseText = MuseTextTheme.light;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: MuseColors.baseSurface,
      canvasColor: MuseColors.baseSurface,
      cardColor: MuseColors.cardSurface,
      dividerColor: scheme.outlineVariant,
      textTheme: baseText,
      fontFamily: MuseFonts.body,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: MuseColors.baseSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: MuseFonts.display,
          fontSize: 20,
          fontWeight: FontWeight.w400,
          color: MuseColors.textPrimary,
        ),
        iconTheme: IconThemeData(color: MuseColors.textPrimary, size: 22),
      ),
      iconTheme: const IconThemeData(color: MuseColors.textPrimary, size: 22),
      tabBarTheme: const TabBarThemeData(
        labelColor: MuseColors.gold,
        unselectedLabelColor: MuseColors.textSecondary,
        labelStyle: TextStyle(
          fontFamily: MuseFonts.body,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: MuseFonts.body,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
        indicatorColor: MuseColors.gold,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      cardTheme: const CardThemeData(
        color: MuseColors.cardSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: MuseColors.goldHairline, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: MuseColors.gold,
          foregroundColor: MuseColors.baseSurface,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          textStyle: baseText.labelLarge?.copyWith(
            fontFamily: MuseFonts.body,
            color: MuseColors.baseSurface,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MuseColors.gold,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          side: const BorderSide(color: MuseColors.gold, width: 1.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          textStyle: baseText.labelLarge?.copyWith(
            fontFamily: MuseFonts.body,
            color: MuseColors.gold,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: MuseColors.gold,
          textStyle: baseText.labelMedium?.copyWith(color: MuseColors.gold),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: MuseColors.gold,
        linearTrackColor: MuseColors.gold,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: MuseColors.gold,
        inactiveTrackColor: MuseColors.gold.withValues(alpha: 0.25),
        thumbColor: MuseColors.gold,
        overlayColor: MuseColors.gold.withValues(alpha: 0.12),
        trackHeight: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MuseColors.cardSurface,
        hintStyle: baseText.bodyMedium?.copyWith(color: MuseColors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: MuseColors.gold.withValues(alpha: 0.35)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: MuseColors.gold.withValues(alpha: 0.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: MuseColors.gold, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: MuseColors.textPrimary,
        contentTextStyle: baseText.bodyMedium?.copyWith(
          color: MuseColors.baseSurface,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: MuseColors.cardSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: MuseColors.textSecondary,
        textColor: MuseColors.textPrimary,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: MuseColors.cardSurface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
      ),
    );
  }
}