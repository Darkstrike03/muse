import 'package:flutter/material.dart';

import 'muse_colors.dart';

/// Font family names registered in pubspec.yaml.
abstract final class MuseFonts {
  static const String display = 'CinzelDecorative';
  static const String body = 'Inter';
}

/// Typography system.
///
/// Cinzel Decorative is reserved for the wordmark, hero titles, and major
/// section headings. Inter carries all functional UI. Cinzel is never used
/// for dense or small text.
abstract final class MuseTextTheme {
  static TextTheme get light => TextTheme(
        // Display / hero — Cinzel.
        displayLarge: const TextStyle(
          fontFamily: MuseFonts.display,
          fontSize: 48,
          height: 1.1,
          fontWeight: FontWeight.w700,
          color: MuseColors.textPrimary,
        ),
        displayMedium: const TextStyle(
          fontFamily: MuseFonts.display,
          fontSize: 40,
          height: 1.15,
          fontWeight: FontWeight.w700,
          color: MuseColors.textPrimary,
        ),
        displaySmall: const TextStyle(
          fontFamily: MuseFonts.display,
          fontSize: 32,
          height: 1.2,
          fontWeight: FontWeight.w400,
          color: MuseColors.textPrimary,
        ),
        headlineLarge: const TextStyle(
          fontFamily: MuseFonts.display,
          fontSize: 28,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: MuseColors.textPrimary,
        ),
        headlineMedium: const TextStyle(
          fontFamily: MuseFonts.display,
          fontSize: 24,
          height: 1.3,
          fontWeight: FontWeight.w400,
          color: MuseColors.textPrimary,
        ),
        headlineSmall: const TextStyle(
          fontFamily: MuseFonts.display,
          fontSize: 20,
          height: 1.3,
          fontWeight: FontWeight.w400,
          color: MuseColors.textPrimary,
        ),
        titleLarge: const TextStyle(
          fontFamily: MuseFonts.display,
          fontSize: 18,
          height: 1.3,
          fontWeight: FontWeight.w400,
          color: MuseColors.textPrimary,
        ),
        // Body / UI — Inter.
        titleMedium: const TextStyle(
          fontFamily: MuseFonts.body,
          fontSize: 16,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: MuseColors.textPrimary,
        ),
        titleSmall: const TextStyle(
          fontFamily: MuseFonts.body,
          fontSize: 14,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: MuseColors.textPrimary,
        ),
        bodyLarge: const TextStyle(
          fontFamily: MuseFonts.body,
          fontSize: 16,
          height: 1.45,
          fontWeight: FontWeight.w400,
          color: MuseColors.textPrimary,
        ),
        bodyMedium: const TextStyle(
          fontFamily: MuseFonts.body,
          fontSize: 14,
          height: 1.45,
          fontWeight: FontWeight.w400,
          color: MuseColors.textPrimary,
        ),
        bodySmall: const TextStyle(
          fontFamily: MuseFonts.body,
          fontSize: 12,
          height: 1.4,
          fontWeight: FontWeight.w400,
          color: MuseColors.textSecondary,
        ),
        labelLarge: const TextStyle(
          fontFamily: MuseFonts.body,
          fontSize: 15,
          height: 1.2,
          fontWeight: FontWeight.w600,
          color: MuseColors.textPrimary,
        ),
        labelMedium: const TextStyle(
          fontFamily: MuseFonts.body,
          fontSize: 13,
          height: 1.2,
          fontWeight: FontWeight.w600,
          color: MuseColors.textPrimary,
        ),
        labelSmall: const TextStyle(
          fontFamily: MuseFonts.body,
          fontSize: 11,
          height: 1.2,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
          color: MuseColors.textSecondary,
        ),
      );
}