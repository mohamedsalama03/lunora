import 'package:flutter/material.dart';

/// AILA Beauty Boutique — soft luxury beauty palette.
///
/// Brand tokens (mirrors the AILA design system):
///   rose-gold #B76E79 · rose-pink #D98A9A · blush #F8E7EA
///   pearl #FFF8F7 · mauve #5A2E36 · taupe #8B6F73
///
/// The legacy constant *names* are kept so the whole app re-skins by
/// repointing their values to the AILA palette.
class AppColors {
  AppColors._();

  // --- AILA brand tokens ---
  static const Color roseGold = Color(0xFFB76E79);
  static const Color rosePink = Color(0xFFD98A9A);
  static const Color blush = Color(0xFFF8E7EA);
  static const Color pearl = Color(0xFFFFF8F7);
  static const Color mauve = Color(0xFF5A2E36);
  static const Color taupe = Color(0xFF8B6F73);

  // --- Primary palette (rose-gold) ---
  static const Color primary = roseGold;
  static const Color primaryLight = rosePink;
  static const Color primarySoft = Color(0xFFE3A9B4);
  static const Color primaryUltraLight = blush;

  // --- Background ---
  static const Color background = pearl;
  static const Color surface = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFEADEE0);
  static const Color surfaceVariant = Color(0xFFFCEEF0);

  // --- NavBar ---
  static const Color navBarBg = Color(0xFFFFFFFF);
  static const Color navBarSelectedBg = blush;
  static const Color navBarIcon = taupe;
  static const Color navBarSelectedIcon = roseGold;

  // --- Accent & Status ---
  static const Color badge = Color(0xFFC75D6A);
  static const Color success = Color(0xFF7BA890);
  static const Color warning = Color(0xFFD9A55B);

  // --- Text ---
  static const Color textPrimary = mauve;
  static const Color textSecondary = taupe;
  static const Color textHint = Color(0xFFB49DA1);

  // --- Gradients ---
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [rosePink, roseGold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Soft blush gradient — pearl → blush → deeper blush.
  static const LinearGradient blushGradient = LinearGradient(
    colors: [Color(0xFFFFF8F7), Color(0xFFF8E7EA), Color(0xFFF2D2D8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Rose gradient — alias of [primaryGradient].
  static const LinearGradient roseGradient = primaryGradient;

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [pearl, Color(0xFFFCEEF0)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // --- Soft rose-toned shadows ---
  static const Color shadowSoft = Color(0x2EB76E79); // rgb(183,110,121)/0.18
  static const Color shadowCard = Color(0x1FB76E79); // rgb(183,110,121)/0.12
  static const Color shadowFloat = Color(0x405A2E36); // rgb(90,46,54)/0.25
}
