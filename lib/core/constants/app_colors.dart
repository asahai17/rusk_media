import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color background = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF12121A);
  static const Color shimmerBase = Color(0xFF1A1A2E);
  static const Color shimmerHighlight = Color(0xFF2D2D55);
  static const Color primary = Color(0xFFE63946);
  static const Color accent = Color(0xFFFF6B6B);
  static const Color onBackground = Color(0xFFFFFFFF);
  static const Color onBackgroundSecondary = Color(0xFFBBBBBB);
  static const Color progressTrack = Color(0x4DFFFFFF);
  static const Color progressFill = Color(0xFFFFFFFF);
  static const Color heartRed = Color(0xFFFF3B5C);
  static const Color paywallOverlay = Color(0xCC000000);
  static const Color shimmerButton = Color(0xFFE63946);
  static const Color shimmerButtonHighlight = Color(0xFFFF9A9E);

  static const LinearGradient episodeGradients = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0xCC000000)],
  );

  static const List<List<Color>> episodePosterGradients = [
    [Color(0xFF1A0A2E), Color(0xFF4A1A6E)],
    [Color(0xFF0A1A2E), Color(0xFF1A4A6E)],
    [Color(0xFF0A2E1A), Color(0xFF1A6E4A)],
    [Color(0xFF2E1A0A), Color(0xFF6E4A1A)],
    [Color(0xFF2E0A1A), Color(0xFF6E1A4A)],
    [Color(0xFF1A2E0A), Color(0xFF4A6E1A)],
    [Color(0xFF2E2A0A), Color(0xFF6E601A)],
  ];

  // Int values for domain layer (pure Dart, no flutter imports)
  static const List<List<int>> episodePosterGradientValues = [
    [0xFF1A0A2E, 0xFF4A1A6E],
    [0xFF0A1A2E, 0xFF1A4A6E],
    [0xFF0A2E1A, 0xFF1A6E4A],
    [0xFF2E1A0A, 0xFF6E4A1A],
    [0xFF2E0A1A, 0xFF6E1A4A],
    [0xFF1A2E0A, 0xFF4A6E1A],
    [0xFF2E2A0A, 0xFF6E601A],
  ];
}
