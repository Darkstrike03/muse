import 'package:flutter/material.dart';

/// Color palette for Muse — ancient Greek temple aesthetic.
///
/// Rules from the spec: no pure white/black anywhere, no cool grays,
/// no gradients, no drop shadows. Max 2-3 accent colors per screen.
abstract final class MuseColors {
  static const Color baseSurface = Color(0xFFF6F1E7); // marble
  static const Color cardSurface = Color(0xFFEDE6D6); // secondary surface
  static const Color darkSurface = Color(0xFF1F2D42); // navy night surface
  static const Color gold = Color(0xFF8A6A2F); // primary accent
  static const Color aegean = Color(0xFF1F3A5C); // secondary accent
  static const Color textPrimary = Color(0xFF2B2620); // warm charcoal
  static const Color textSecondary = Color(0xFF7A7266); // warm muted gray
  static const Color error = Color(0xFF8C2F2A); // warm brick, not cool red

  /// Gold at 40% alpha — the curated hairline for surface containers.
  static const Color goldHairline = Color(0x668A6A2F);
}