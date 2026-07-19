import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';

import 'config/app_env.dart';
import 'theme/app_colors.dart';
import 'models/user_model.dart';
import 'screens/web_app_screen.dart';
import 'services/audio_coordinator.dart';
import 'services/audio_service.dart';
import 'services/user_service.dart';
import 'user_service_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppEnv.load();
  if (!kIsWeb) {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.example.bible_app.audio',
      androidNotificationChannelName: 'Bible App audio',
      androidNotificationOngoing: true,
    );
  }
  await Hive.initFlutter();

  AudioService();

  // Register the lifecycle observer before the first frame so background /
  // lock-screen rules take effect immediately on app start.
  AudioCoordinator.instance;

  runApp(const UserServiceProvider(child: BibleApp()));
}

class BibleApp extends StatelessWidget {
  const BibleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserService>(
      builder: (BuildContext context, UserService userService, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Bible App',
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const <Locale>[
            Locale('en'),
            Locale('te'),
            Locale('hi'),
            Locale('ta'),
            Locale('kn'),
            Locale('ml'),
            Locale('mr'),
          ],
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode: resolveThemeModeForAppTheme(userService.user.theme),
          home: const WebAppScreen(),
        );
      },
    );
  }
}

ThemeMode resolveThemeModeForAppTheme(AppTheme theme) {
  switch (theme) {
    case AppTheme.light:
      return ThemeMode.light;
    case AppTheme.dark:
      return ThemeMode.dark;
    case AppTheme.system:
      return ThemeMode.system;
  }
}

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1C5A47),
    brightness: brightness,
  ).copyWith(
    primary: AppColors.primary(isDark),
    secondary: isDark ? AppColors.secondaryDark : AppColors.secondaryLight,
    surface: AppColors.card(isDark),
    onSurface: AppColors.textPrimary(isDark),
    outline: AppColors.outline(isDark),
  );
  final scaffoldBackground = AppColors.scaffold(isDark);
  final cardColor = AppColors.card(isDark);
  final filledButtonColor = AppColors.filledButton(isDark);
  final outlineColor =
      isDark ? const Color(0xFF33423C) : const Color(0xFFD7C9B0);
  final outlineForeground =
      isDark ? const Color(0xFFDCE6E0) : const Color(0xFF1F3F35);
  final snackBarColor =
      isDark ? const Color(0xFF27483B) : const Color(0xFF173A30);
  final baseTheme = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldBackground,
  );

  return baseTheme.copyWith(
    textTheme: baseTheme.textTheme.copyWith(
      headlineMedium: baseTheme.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: baseTheme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: baseTheme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: baseTheme.textTheme.bodyLarge?.copyWith(
        color: AppColors.textPrimary(isDark),
      ),
      bodyMedium: baseTheme.textTheme.bodyMedium?.copyWith(
        color: AppColors.textSecondary(isDark),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      centerTitle: false,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: snackBarColor,
      contentTextStyle: baseTheme.textTheme.bodyMedium?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.accent(isDark),
      linearTrackColor: AppColors.track(isDark),
      circularTrackColor: Colors.transparent,
      linearMinHeight: 4,
      borderRadius: BorderRadius.circular(4),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: filledButtonColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: outlineForeground,
        side: BorderSide(color: outlineColor),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: cardColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cardColor,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cardColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.inputFill(isDark),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
      ),
    ),
  );
}
