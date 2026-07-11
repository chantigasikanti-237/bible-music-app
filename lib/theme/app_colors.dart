// Design source: https://www.figma.com/design/Z0k5fIWxeA3CVIPPs3HU4J
// Figma variable collection: "Clay UI — Colors"
//
// Every constant below corresponds to a named Figma variable.
// To update a color: change it here AND in the Figma file to keep them in sync.

import 'package:flutter/material.dart';

abstract final class AppColors {
  // ─── Surface ──────────────────────────────────────────────────────────────
  // Figma: surface/background
  static const Color surfaceBackgroundDark = Color(0xFF1E2822);
  static const Color surfaceBackgroundLight = Color(0xFFFFFCF7);

  // Figma: surface/card
  static const Color surfaceCardDark = Color(0xFF18211D);
  static const Color surfaceCardLight = Color(0xFFFFFCF7);

  // Figma: surface/track  (progress bar background)
  static const Color surfaceTrackDark = Color(0xFF27352F);
  static const Color surfaceTrackLight = Color(0xFFE7DDD0);

  // Scaffold / page background (darker than card — not a Figma variable,
  // derived from the page background in each screen frame)
  static const Color scaffoldDark = Color(0xFF101714);
  static const Color scaffoldLight = Color(0xFFF6F1E7);

  // ─── Text ─────────────────────────────────────────────────────────────────
  // Figma: text/primary
  static const Color textPrimaryDark = Color(0xFFE5ECE7);
  static const Color textPrimaryLight = Color(0xFF1B211D);

  // Figma: text/secondary
  static const Color textSecondaryDark = Color(0xFFA8C4B4);
  static const Color textSecondaryLight = Color(0xFF4D5A52);

  // ─── Accent ───────────────────────────────────────────────────────────────
  // Figma: accent/sage-green  (primary brand color, dark-mode tint)
  static const Color accentSageGreen = Color(0xFF8FD8B5);

  // Figma: accent/forest-green  (primary brand color, light-mode tint + CTA)
  static const Color accentForestGreen = Color(0xFF17624D);

  // Resolved primary per brightness
  static const Color primaryDark = Color(0xFF85D0AE);
  static const Color primaryLight = Color(0xFF174C3C);

  // Filled button background
  static const Color filledButtonDark = Color(0xFF2A7C62);
  static const Color filledButtonLight = Color(0xFF19795E);

  // Outline / divider
  static const Color outlineDark = Color(0xFF33423C);
  static const Color outlineLight = Color(0xFFE5D8C3);

  // ─── Snackbar backgrounds ─────────────────────────────────────────────────
  // Figma: snack/success-bg
  static const Color snackSuccessBgDark = Color(0xFF1A4835);
  static const Color snackSuccessBgLight = Color(0xFF124030);

  // Figma: snack/error-bg
  static const Color snackErrorBgDark = Color(0xFF4A1E22);
  static const Color snackErrorBgLight = Color(0xFF6B1C22);

  // Figma: snack/info-bg
  static const Color snackInfoBgDark = Color(0xFF1E2C40);
  static const Color snackInfoBgLight = Color(0xFF173A30);

  // ─── Snackbar icon tints ──────────────────────────────────────────────────
  // Figma: snack/success-icon
  static const Color snackSuccessIcon = Color(0xFF6FD4A8);

  // Figma: snack/error-icon
  static const Color snackErrorIcon = Color(0xFFFFB4AB);

  // Figma: snack/info-icon
  static const Color snackInfoIcon = Color(0xFF90CAF9);

  // ─── Navigation bar ───────────────────────────────────────────────────────
  static const Color navShellGradientTopDark = Color(0xFF1A231F);
  static const Color navShellGradientBottomDark = Color(0xFF141B18);
  static const Color navShellGradientTopLight = Color(0xFFFFFEFC);
  static const Color navShellGradientBottomLight = Color(0xFFF3EEE3);

  static const Color navShellBorderDark = Color(0xFF32403A);
  static const Color navShellBorderLight = Color(0xFFE6D9C3);

  static const Color navSelectedDark = Color(0xFF8FD8B5);
  static const Color navSelectedLight = Color(0xFF0D5C48);

  static const Color navUnselectedDark = Color(0xFFA5B4AD);
  static const Color navUnselectedLight = Color(0xFF52625A);

  static const Color navIndicatorFillTopDark = Color(0xFF22312A);
  static const Color navIndicatorFillBottomDark = Color(0xFF1C2924);
  static const Color navIndicatorFillTopLight = Color(0xFFE2F0E9);
  static const Color navIndicatorFillBottomLight = Color(0xFFD4E7DE);

  static const Color navIndicatorDark = Color(0xFF22312A);
  static const Color navIndicatorLight = Color(0xFFDCEBE3);

  // ─── Input fields ─────────────────────────────────────────────────────────
  static const Color inputFillDark = Color(0xFF1E2824);
  static const Color inputFillLight = Color(0xFFFFFCF7);

  // ─── Secondary / warm tones ───────────────────────────────────────────────
  static const Color secondaryDark = Color(0xFFE1BC78);
  static const Color secondaryLight = Color(0xFFB98A47);

  // ─── Convenience: resolve by brightness ───────────────────────────────────

  static Color surface(bool isDark) =>
      isDark ? surfaceBackgroundDark : surfaceBackgroundLight;

  static Color card(bool isDark) =>
      isDark ? surfaceCardDark : surfaceCardLight;

  static Color scaffold(bool isDark) =>
      isDark ? scaffoldDark : scaffoldLight;

  static Color track(bool isDark) =>
      isDark ? surfaceTrackDark : surfaceTrackLight;

  static Color primary(bool isDark) =>
      isDark ? primaryDark : primaryLight;

  static Color accent(bool isDark) =>
      isDark ? accentSageGreen : accentForestGreen;

  static Color textPrimary(bool isDark) =>
      isDark ? textPrimaryDark : textPrimaryLight;

  static Color textSecondary(bool isDark) =>
      isDark ? textSecondaryDark : textSecondaryLight;

  static Color snackSuccessBg(bool isDark) =>
      isDark ? snackSuccessBgDark : snackSuccessBgLight;

  static Color snackErrorBg(bool isDark) =>
      isDark ? snackErrorBgDark : snackErrorBgLight;

  static Color snackInfoBg(bool isDark) =>
      isDark ? snackInfoBgDark : snackInfoBgLight;

  static Color outline(bool isDark) =>
      isDark ? outlineDark : outlineLight;

  static Color filledButton(bool isDark) =>
      isDark ? filledButtonDark : filledButtonLight;

  static Color inputFill(bool isDark) =>
      isDark ? inputFillDark : inputFillLight;

  static Color navSelected(bool isDark) =>
      isDark ? navSelectedDark : navSelectedLight;

  static Color navUnselected(bool isDark) =>
      isDark ? navUnselectedDark : navUnselectedLight;

  static Color navIndicatorFillTop(bool isDark) =>
      isDark ? navIndicatorFillTopDark : navIndicatorFillTopLight;

  static Color navIndicatorFillBottom(bool isDark) =>
      isDark ? navIndicatorFillBottomDark : navIndicatorFillBottomLight;

  static Color navIndicator(bool isDark) =>
      isDark ? navIndicatorDark : navIndicatorLight;
}
