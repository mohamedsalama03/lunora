import 'package:flutter/material.dart';

/// Aura Apparel's warm, editorial palette.
///
/// The legacy brand token names remain as aliases because feature screens still
/// consume them. New work should prefer the semantic Aura tokens at the top of
/// this class.
class AppColors {
  AppColors._();

  // --- Aura brand tokens ---
  static const Color auraBackground = Color(0xFFF8F5F0);
  static const Color auraText = Color(0xFF2E211B);
  static const Color auraPrimary = Color(0xFF4A3428);
  static const Color auraSecondary = Color(0xFFEADCC8);
  static const Color auraNeutral = Color(0xFFC8B59E);
  static const Color auraAccent = Color(0xFFB88746);
  static const Color auraMutedForeground = Color(0xFF6D5A4D);

  // Short semantic aliases used by the refreshed design layer.
  static const Color secondary = auraSecondary;
  static const Color neutral = auraNeutral;
  static const Color accent = auraAccent;

  // --- Legacy brand aliases ---
  static const Color roseGold = auraAccent;
  static const Color rosePink = auraNeutral;
  static const Color blush = auraSecondary;
  static const Color pearl = auraBackground;
  static const Color mauve = auraText;
  static const Color taupe = auraMutedForeground;

  // --- Primary palette ---
  static const Color primary = auraPrimary;
  static const Color primaryLight = auraAccent;
  static const Color primarySoft = auraNeutral;
  static const Color primaryUltraLight = auraSecondary;

  // --- Background and surfaces ---
  static const Color background = auraBackground;
  static const Color surface = Color(0xFFFCFAF6);
  static const Color divider = Color(0xFFE4DBCE);
  static const Color surfaceVariant = Color(0xFFF1E8DC);

  // --- Navigation ---
  static const Color navBarBg = surface;
  static const Color navBarSelectedBg = auraPrimary;
  static const Color navBarIcon = auraPrimary;
  static const Color navBarSelectedIcon = surface;

  // --- Accent and status ---
  static const Color badge = auraAccent;
  static const Color success = Color(0xFF66806B);
  static const Color warning = auraAccent;
  static const Color error = Color(0xFFA44F48);

  // --- Text ---
  static const Color textPrimary = auraText;
  static const Color textSecondary = auraMutedForeground;
  static const Color textHint = Color(0xFF9B8979);

  // --- Gradients ---
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [auraPrimary, auraPrimary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient blushGradient = LinearGradient(
    colors: [auraBackground, Color(0xFFF1E8DC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient roseGradient = primaryGradient;

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [auraBackground, auraBackground],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // --- Warm, low-contrast elevation ---
  static const Color shadowSoft = Color(0x1F2E211B);
  static const Color shadowCard = Color(0x142E211B);
  static const Color shadowFloat = Color(0x2E2E211B);
}
