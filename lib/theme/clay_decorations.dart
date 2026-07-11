import 'package:flutter/material.dart';

import 'app_colors.dart';

enum ClaySnackType { success, error, info }

/// Multi-layer clay shadow for standard cards and surfaces.
List<BoxShadow> clayShadows(bool isDark, {Color? shadowHue}) {
  if (isDark) {
    return <BoxShadow>[
      BoxShadow(
        color: const Color(0xFF000000).withValues(alpha: 0.42),
        blurRadius: 22,
        offset: const Offset(0, 9),
      ),
      BoxShadow(
        color: const Color(0xFF000000).withValues(alpha: 0.18),
        blurRadius: 44,
        spreadRadius: -6,
        offset: const Offset(0, 20),
      ),
      const BoxShadow(
        color: Color(0x0EFFFFFF),
        blurRadius: 0,
        spreadRadius: 1,
        offset: Offset(-2, -2),
      ),
    ];
  }
  final hue = shadowHue ?? const Color(0xFF1A5A47);
  return <BoxShadow>[
    BoxShadow(
      color: hue.withValues(alpha: 0.22),
      blurRadius: 22,
      offset: const Offset(0, 9),
    ),
    BoxShadow(
      color: hue.withValues(alpha: 0.10),
      blurRadius: 44,
      spreadRadius: -6,
      offset: const Offset(0, 20),
    ),
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.90),
      blurRadius: 0,
      spreadRadius: 2,
      offset: const Offset(-3, -3),
    ),
  ];
}

/// Stronger shadows for hero / accent feature cards.
List<BoxShadow> clayHeroShadows(bool isDark, {Color? shadowHue}) {
  if (isDark) {
    return <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.55),
        blurRadius: 32,
        offset: const Offset(0, 16),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.22),
        blurRadius: 60,
        spreadRadius: -8,
        offset: const Offset(0, 28),
      ),
      const BoxShadow(
        color: Color(0x10FFFFFF),
        blurRadius: 0,
        spreadRadius: 1,
        offset: Offset(-3, -4),
      ),
    ];
  }
  final hue = shadowHue ?? const Color(0xFF0F3F32);
  return <BoxShadow>[
    BoxShadow(
      color: hue.withValues(alpha: 0.35),
      blurRadius: 32,
      offset: const Offset(0, 16),
    ),
    BoxShadow(
      color: hue.withValues(alpha: 0.16),
      blurRadius: 60,
      spreadRadius: -8,
      offset: const Offset(0, 28),
    ),
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.18),
      blurRadius: 0,
      spreadRadius: 1,
      offset: const Offset(-3, -4),
    ),
  ];
}

/// Tight shadows for chips, pills, and compact interactive elements.
List<BoxShadow> claySmallShadows(bool isDark, {Color? shadowHue}) {
  if (isDark) {
    return <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.32),
        blurRadius: 12,
        offset: const Offset(0, 5),
      ),
      const BoxShadow(
        color: Color(0x08FFFFFF),
        blurRadius: 0,
        spreadRadius: 1,
        offset: Offset(-1, -2),
      ),
    ];
  }
  final hue = shadowHue ?? const Color(0xFF1A5A47);
  return <BoxShadow>[
    BoxShadow(
      color: hue.withValues(alpha: 0.18),
      blurRadius: 12,
      offset: const Offset(0, 5),
    ),
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.92),
      blurRadius: 0,
      spreadRadius: 1,
      offset: const Offset(-2, -2),
    ),
  ];
}

/// Shows a floating clay-styled snackbar with an icon and message.
void showClaySnackBar(
  BuildContext context,
  String message, {
  ClaySnackType type = ClaySnackType.info,
  SnackBarAction? action,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  final Color bgColor;
  final IconData iconData;
  final Color iconColor;

  switch (type) {
    case ClaySnackType.success:
      bgColor = AppColors.snackSuccessBg(isDark);
      iconData = Icons.check_circle_rounded;
      iconColor = AppColors.snackSuccessIcon;
    case ClaySnackType.error:
      bgColor = AppColors.snackErrorBg(isDark);
      iconData = Icons.error_rounded;
      iconColor = AppColors.snackErrorIcon;
    case ClaySnackType.info:
      bgColor = AppColors.snackInfoBg(isDark);
      iconData = Icons.info_rounded;
      iconColor = AppColors.snackInfoIcon;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: bgColor,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      action: action,
      content: Row(
        children: <Widget>[
          Icon(iconData, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Full-page clay loading spinner for empty-state screens.
Widget clayLoadingCenter(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Center(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(24),
        boxShadow: clayShadows(isDark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: AppColors.accent(isDark),
        ),
      ),
    ),
  );
}

/// Shadow for floating nav bar / bottom sheets.
List<BoxShadow> clayNavShadows(bool isDark) {
  if (isDark) {
    return <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.45),
        blurRadius: 28,
        offset: const Offset(0, 12),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.18),
        blurRadius: 50,
        spreadRadius: -6,
        offset: const Offset(0, 22),
      ),
      const BoxShadow(
        color: Color(0x0AFFFFFF),
        blurRadius: 0,
        spreadRadius: 1,
        offset: Offset(-2, -2),
      ),
    ];
  }
  return <BoxShadow>[
    BoxShadow(
      color: const Color(0xFF1A5A47).withValues(alpha: 0.20),
      blurRadius: 28,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: const Color(0xFF1A5A47).withValues(alpha: 0.09),
      blurRadius: 50,
      spreadRadius: -6,
      offset: const Offset(0, 22),
    ),
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.88),
      blurRadius: 0,
      spreadRadius: 2,
      offset: const Offset(-2, -2),
    ),
  ];
}
