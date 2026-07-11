import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';

import 'config/app_env.dart';
import 'theme/app_colors.dart';
import 'theme/clay_decorations.dart';
import 'controllers/app_shell_controller.dart';
import 'models/user_model.dart';
import 'screens/bible/bible_page.dart';
import 'screens/home/home_page.dart';
import 'screens/profile/profile_page.dart';
import 'screens/hymns/hymns_page.dart';
import 'screens/music/music_page.dart';
import 'screens/web_app_screen.dart';
import 'services/audio_coordinator.dart';
import 'services/audio_service.dart';
import 'services/offline_bible_service.dart';
import 'services/user_service.dart';
import 'user_service_provider.dart';
import 'widgets/adaptive_layout.dart';
import 'widgets/audio_mini_player.dart';
import 'widgets/web_youtube_player_panel.dart';

const List<_NavItemData> _bottomNavItems = <_NavItemData>[
  _NavItemData(
    label: 'Home',
    icon: Icons.home_filled,
    selectedIcon: Icons.home_filled,
  ),
  _NavItemData(
    label: 'Bible',
    icon: Icons.book_rounded,
    selectedIcon: Icons.book_rounded,
  ),
  _NavItemData(
    label: 'Hymns',
    icon: Icons.lyrics_rounded,
    selectedIcon: Icons.lyrics_rounded,
  ),
  _NavItemData(
    label: 'Music',
    icon: CupertinoIcons.music_note_2,
    selectedIcon: CupertinoIcons.music_note_2,
  ),
  _NavItemData(
    label: 'Profile',
    icon: Icons.person_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];

const List<_NavItemData> _sidebarNavItems = <_NavItemData>[
  _NavItemData(
    label: 'Home',
    icon: Icons.home_filled,
    selectedIcon: Icons.home_filled,
  ),
  _NavItemData(
    label: 'Bible',
    icon: Icons.book_rounded,
    selectedIcon: Icons.book_rounded,
  ),
  _NavItemData(
    label: 'Hymns',
    icon: Icons.lyrics_rounded,
    selectedIcon: Icons.lyrics_rounded,
  ),
  _NavItemData(
    label: 'Music',
    icon: CupertinoIcons.music_note_2,
    selectedIcon: CupertinoIcons.music_note_2,
  ),
  _NavItemData(
    label: 'Profile',
    icon: Icons.person_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];

const List<int> _bottomNavPageIndexes = <int>[
  AppShellController.homeIndex,
  AppShellController.bibleIndex,
  AppShellController.hymnsIndex,
  AppShellController.musicIndex,
  AppShellController.profileIndex,
];

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

  await Hive.openBox('bible_cache');
  await Hive.openBox('offline_bible');

  if (!kIsWeb) {
    const teluguMigrationKey = 'migration:te:verse_extraction_fix_v1';
    final migrationBox = Hive.box<dynamic>('bible_cache');
    if (migrationBox.get(teluguMigrationKey) == null) {
      await OfflineBibleService().clearLanguageData('te');
      await migrationBox.put(teluguMigrationKey, DateTime.now().toIso8601String());
    }
  }

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

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  static const List<Widget> _pages = <Widget>[
    HomePage(),
    BiblePage(),
    HymnsPage(),
    MusicPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<AppShellController>(
      builder: (
        BuildContext context,
        AppShellController shellController,
        Widget? child,
      ) {
        return ConstraintLayout(
          builder: (BuildContext context, AdaptiveLayoutInfo layout) {
            final useRail = layout.useSideNavigation;
            final content = _ShellPageStack(
              index: shellController.selectedIndex,
              pages: _pages,
              enableEdgeGestures: layout.isPhone,
              onOpenHymns: shellController.openHymns,
              onCloseHymns: shellController.openHome,
            );

            if (useRail) {
              return Scaffold(
                body: SafeArea(
                  child: Stack(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          _AdaptiveNavigationRail(
                            selectedIndex: shellController.selectedIndex,
                            isVisible: shellController.showNavigationBar,
                            extended:
                                layout.maxWidth >= AdaptiveBreakpoints.expanded,
                            onDestinationSelected: shellController.selectTab,
                          ),
                          Expanded(child: content),
                        ],
                      ),
                      // Music mini player is hidden on the Bible tab so it
                      // doesn't overlap the Bible chapter audio controls.
                      // Music keeps playing; only the UI is toggled.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: kIsWeb
                            ? const WebYouTubePlayerPanel()
                            : AnimatedSwitcher(
                                duration: const Duration(milliseconds: 240),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                child: shellController.selectedIndex !=
                                        AppShellController.bibleIndex
                                    ? const AudioMiniPlayer(
                                        key: ValueKey<String>('mini-rail-visible'),
                                      )
                                    : const SizedBox.shrink(
                                        key: ValueKey<String>('mini-rail-hidden'),
                                      ),
                              ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Scaffold(
              body: content,
              bottomNavigationBar: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (kIsWeb)
                    const WebYouTubePlayerPanel()
                  else
                    // Hide on Bible tab — Bible has its own audio; music keeps playing.
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: shellController.selectedIndex !=
                              AppShellController.bibleIndex
                          ? const AudioMiniPlayer(
                              key: ValueKey<String>('mini-bar-visible'),
                            )
                          : const SizedBox.shrink(
                              key: ValueKey<String>('mini-bar-hidden'),
                            ),
                    ),
                  PremiumBottomNavigationBar(
                    selectedIndex: _bottomNavSelectedIndexForPageIndex(
                      shellController.selectedIndex,
                    ),
                    isVisible: shellController.showNavigationBar,
                    onDestinationSelected: (int index) {
                      shellController.selectTab(_bottomNavPageIndexes[index]);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

int _bottomNavSelectedIndexForPageIndex(int pageIndex) {
  return _bottomNavPageIndexes.indexOf(pageIndex);
}

class _ShellPageStack extends StatelessWidget {
  const _ShellPageStack({
    required this.index,
    required this.pages,
    required this.enableEdgeGestures,
    required this.onOpenHymns,
    required this.onCloseHymns,
  });

  final int index;
  final List<Widget> pages;
  final bool enableEdgeGestures;
  final VoidCallback onOpenHymns;
  final VoidCallback onCloseHymns;

  static const Duration _duration = Duration(milliseconds: 310);
  static const Curve _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = index.clamp(0, pages.length - 1).toInt();

    return ClipRect(
      child: Stack(
        children: List<Widget>.generate(pages.length, (int pageIndex) {
          final isActive = pageIndex == selectedIndex;
          final offset = pageIndex == selectedIndex
              ? Offset.zero
              : Offset(pageIndex < selectedIndex ? -1.0 : 1.0, 0);
          Widget page = pages[pageIndex];

          if (pageIndex == AppShellController.homeIndex) {
            page = _EdgeSwipeShortcut(
              active: enableEdgeGestures && isActive,
              swipeDirection: _EdgeSwipeDirection.left,
              onTriggered: onOpenHymns,
              child: page,
            );
          } else if (pageIndex == AppShellController.hymnsIndex) {
            page = _EdgeSwipeShortcut(
              active: enableEdgeGestures && isActive,
              swipeDirection: _EdgeSwipeDirection.right,
              onTriggered: onCloseHymns,
              child: page,
            );
          }

          return Positioned.fill(
            child: AnimatedSlide(
              duration: _duration,
              curve: _curve,
              offset: offset,
              child: IgnorePointer(
                ignoring: !isActive,
                child: TickerMode(
                  enabled: isActive,
                  child: page,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

enum _EdgeSwipeDirection {
  left,
  right,
}

class _EdgeSwipeShortcut extends StatefulWidget {
  const _EdgeSwipeShortcut({
    required this.child,
    required this.active,
    required this.swipeDirection,
    required this.onTriggered,
  });

  final Widget child;
  final bool active;
  final _EdgeSwipeDirection swipeDirection;
  final VoidCallback onTriggered;

  @override
  State<_EdgeSwipeShortcut> createState() => _EdgeSwipeShortcutState();
}

class _EdgeSwipeShortcutState extends State<_EdgeSwipeShortcut> {
  static const double _triggerDistance = 24;

  int? _trackingPointer;
  Offset? _startPosition;
  Offset? _lastPosition;
  bool _didTrigger = false;

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.active || _trackingPointer != null) {
      return;
    }

    final edgeWidth = _edgeWidthForContext(context);
    if (event.localPosition.dx > edgeWidth) {
      return;
    }

    _trackingPointer = event.pointer;
    _startPosition = event.position;
    _lastPosition = event.position;
    _didTrigger = false;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _trackingPointer) {
      return;
    }
    _lastPosition = event.position;
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _trackingPointer) {
      return;
    }

    _lastPosition = event.position;
    _finishGesture();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer == _trackingPointer) {
      _handleDragCancel();
    }
  }

  void _finishGesture() {
    if (!widget.active || _trackingPointer == null || _didTrigger) {
      _handleDragCancel();
      return;
    }

    final start = _startPosition;
    final end = _lastPosition;
    if (start == null || end == null) {
      _handleDragCancel();
      return;
    }

    final delta = end - start;
    final horizontal = delta.dx.abs();
    final vertical = delta.dy.abs();
    if (horizontal <= vertical * 1.25) {
      _handleDragCancel();
      return;
    }

    final swipedLeft = delta.dx <= -_triggerDistance;
    final swipedRight = delta.dx >= _triggerDistance;
    final matched = widget.swipeDirection == _EdgeSwipeDirection.left
        ? swipedLeft
        : swipedRight;

    if (!matched) {
      _handleDragCancel();
      return;
    }

    _didTrigger = true;
    widget.onTriggered();
    _handleDragCancel();
  }

  void _handleDragCancel() {
    _trackingPointer = null;
    _startPosition = null;
    _lastPosition = null;
    _didTrigger = false;
  }

  double _edgeWidthForContext(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return (screenWidth * 0.12).clamp(36.0, 52.0);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return widget.child;
    }

    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: widget.child,
    );
  }
}

class PremiumBottomNavigationBar extends StatelessWidget {
  const PremiumBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.isVisible,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final bool isVisible;
  final ValueChanged<int> onDestinationSelected;

  static const List<_NavItemData> _items = _bottomNavItems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth <= 380;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final textScaleFactor = MediaQuery.textScalerOf(context).scale(1);
    final extraHeight = ((textScaleFactor - 1).clamp(0.0, 0.8)) * 18;
    final visibleHeight = (compact ? 88.0 : 96.0) + bottomInset + extraHeight;
    final shellGradient = isDark
        ? const <Color>[AppColors.navShellGradientTopDark, AppColors.navShellGradientBottomDark]
        : const <Color>[AppColors.navShellGradientTopLight, AppColors.navShellGradientBottomLight];

    final navigationShell = SizedBox(
      height: visibleHeight,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 10 : 14,
            0,
            compact ? 10 : 14,
            bottomInset > 0 ? (compact ? 8 : 10) : (compact ? 10 : 12),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: shellGradient,
              ),
              borderRadius: BorderRadius.circular(compact ? 24 : 28),
              boxShadow: clayNavShadows(isDark),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 4 : 8,
                vertical: compact ? 6 : 8,
              ),
              child: Row(
                children: List<Widget>.generate(_items.length, (index) {
                  final item = _items[index];
                  final selected = index == selectedIndex;
                  return Expanded(
                    child: _PremiumNavItem(
                      label: item.label,
                      icon: item.icon,
                      selectedIcon: item.selectedIcon,
                      selected: selected,
                      compact: compact,
                      onTap: () => onDestinationSelected(index),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.hardEdge,
      child: isVisible ? navigationShell : const SizedBox.shrink(),
    );
  }
}

class _PremiumNavItem extends StatefulWidget {
  const _PremiumNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  State<_PremiumNavItem> createState() => _PremiumNavItemState();
}

class _PremiumNavItemState extends State<_PremiumNavItem> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) {
      return;
    }
    setState(() => _pressed = value);
  }

  void _handleTapDown(TapDownDetails _) {
    _setPressed(true);
  }

  void _handleTapCancel() {
    _setPressed(false);
  }

  void _handleTapUp(TapUpDetails _) {
    Future<void>.delayed(const Duration(milliseconds: 110), () {
      if (!mounted) {
        return;
      }
      _setPressed(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textScaleFactor = MediaQuery.textScalerOf(context).scale(1);
    final extraHeight = ((textScaleFactor - 1).clamp(0.0, 0.8)) * 12;
    final selectedColor = AppColors.navSelected(isDark);
    final unselectedColor = AppColors.navUnselected(isDark);
    final selectedFillTop = AppColors.navIndicatorFillTop(isDark);
    final selectedFillBottom = AppColors.navIndicatorFillBottom(isDark);
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: widget.selected ? selectedColor : unselectedColor,
          fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w600,
          fontSize: widget.compact ? 11 : 12,
          height: 1.0,
          letterSpacing: -0.2,
        );
    final itemKeyLabel = widget.label.toLowerCase();

    return AnimatedScale(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      scale: _pressed ? 0.94 : 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (widget.compact ? 60 : 64) + extraHeight,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey<String>('nav-item-$itemKeyLabel'),
            borderRadius: BorderRadius.circular(widget.compact ? 18 : 20),
            splashFactory: InkRipple.splashFactory,
            overlayColor: WidgetStateProperty.resolveWith<Color?>(
              (states) => states.contains(WidgetState.pressed)
                  ? const Color(0x140D5C48)
                  : null,
            ),
            onTap: widget.onTap,
            onTapDown: _handleTapDown,
            onTapCancel: _handleTapCancel,
            onTapUp: _handleTapUp,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 4 : 6,
                vertical: widget.compact ? 6 : 7,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.compact ? 18 : 20),
                gradient: widget.selected
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          selectedFillTop,
                          selectedFillBottom,
                        ],
                      )
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 170),
                    curve: Curves.easeOutCubic,
                    width: widget.compact ? 30 : 34,
                    height: widget.compact ? 30 : 34,
                    decoration: BoxDecoration(
                      color:
                          widget.selected ? selectedColor : Colors.transparent,
                      borderRadius:
                          BorderRadius.circular(widget.compact ? 11 : 13),
                      boxShadow: widget.selected
                          ? <BoxShadow>[
                              BoxShadow(
                                color: AppColors.navSelectedLight.withValues(alpha: isDark ? 0.40 : 0.30),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                              BoxShadow(
                                color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.80),
                                blurRadius: 0,
                                spreadRadius: 1,
                                offset: const Offset(-2, -2),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      widget.selected ? widget.selectedIcon : widget.icon,
                      color: widget.selected ? Colors.white : unselectedColor,
                      size: widget.compact ? 18 : 20,
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 170),
                    curve: Curves.easeOutCubic,
                    child: widget.selected
                        ? Padding(
                            padding:
                                EdgeInsets.only(top: widget.compact ? 2 : 3),
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOutCubic,
                              opacity: 1,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  widget.label,
                                  key: ValueKey<String>(
                                    'nav-label-$itemKeyLabel',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                  softWrap: false,
                                  style: labelStyle,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  if (!widget.selected)
                    SizedBox(height: widget.compact ? 1 : 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdaptiveNavigationRail extends StatelessWidget {
  const _AdaptiveNavigationRail({
    required this.selectedIndex,
    required this.isVisible,
    required this.extended,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final bool isVisible;
  final bool extended;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final visibleWidth = extended ? 176.0 : 88.0;
    final shellGradient = isDark
        ? const <Color>[AppColors.navShellGradientTopDark, AppColors.navShellGradientBottomDark]
        : const <Color>[AppColors.navShellGradientTopLight, AppColors.navShellGradientBottomLight];
    final selectedColor = AppColors.navSelected(isDark);
    final unselectedColor = AppColors.navUnselected(isDark);
    final indicatorColor = AppColors.navIndicator(isDark);

    final navigationShell = SizedBox(
      width: visibleWidth,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: shellGradient,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: clayNavShadows(isDark),
          ),
          child: NavigationRail(
            selectedIndex: selectedIndex,
            extended: extended,
            useIndicator: true,
            backgroundColor: Colors.transparent,
            minWidth: extended ? 100 : 68,
            minExtendedWidth: 164,
            labelType: extended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.selected,
            indicatorColor: indicatorColor,
            selectedIconTheme: IconThemeData(
              color: selectedColor,
              size: 22,
            ),
            unselectedIconTheme: IconThemeData(
              color: unselectedColor,
              size: 22,
            ),
            selectedLabelTextStyle:
                Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selectedColor,
                      fontWeight: FontWeight.w800,
                    ),
            unselectedLabelTextStyle:
                Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: unselectedColor,
                      fontWeight: FontWeight.w600,
                    ),
            destinations: _sidebarNavItems
                .map(
                  (_NavItemData item) => NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: Text(item.label),
                  ),
                )
                .toList(growable: false),
            onDestinationSelected: onDestinationSelected,
          ),
        ),
      ),
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.centerLeft,
      clipBehavior: Clip.hardEdge,
      child: isVisible ? navigationShell : const SizedBox.shrink(),
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
