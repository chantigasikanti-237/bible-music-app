import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bible_app/main.dart';
import 'package:bible_app/models/user_model.dart';
import 'package:bible_app/screens/home/home_page.dart';

void main() {
  testWidgets('Home page loads', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomePage(),
      ),
    );
    expect(find.text('Welcome to Bible App'), findsOneWidget);
  });

  testWidgets('Bottom navigation shows only the active label',
      (WidgetTester tester) async {
    var selectedIndex = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Scaffold(
              bottomNavigationBar: PremiumBottomNavigationBar(
                selectedIndex: selectedIndex,
                isVisible: true,
                onDestinationSelected: (int index) {
                  setState(() => selectedIndex = index);
                },
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Bible'), findsNothing);
    expect(find.text('Hymns'), findsNothing);
    expect(find.text('Audio'), findsNothing);
    expect(find.text('Profile'), findsNothing);
    expect(find.byIcon(Icons.home_filled), findsOneWidget);
    expect(find.byIcon(Icons.book_rounded), findsOneWidget);
    expect(find.byIcon(Icons.lyrics_rounded), findsOneWidget);
    expect(find.byIcon(Icons.queue_music_rounded), findsOneWidget);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('nav-item-bible')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.text('Home'), findsNothing);
    expect(find.text('Bible'), findsOneWidget);
    expect(find.text('Hymns'), findsNothing);
    expect(find.text('Audio'), findsNothing);
    expect(find.text('Profile'), findsNothing);
  });

  test('theme preference maps to the expected ThemeMode', () {
    expect(resolveThemeModeForAppTheme(AppTheme.light), ThemeMode.light);
    expect(resolveThemeModeForAppTheme(AppTheme.dark), ThemeMode.dark);
    expect(resolveThemeModeForAppTheme(AppTheme.system), ThemeMode.system);
    expect(buildAppTheme(Brightness.dark).brightness, Brightness.dark);
  });

  testWidgets('Bottom navigation stays overflow-free on compact layouts',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    FlutterErrorDetails? flutterError;
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      flutterError ??= details;
    };
    addTearDown(() {
      FlutterError.onError = previousOnError;
    });

    var selectedIndex = 0;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(1.35),
        ),
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Scaffold(
                bottomNavigationBar: PremiumBottomNavigationBar(
                  selectedIndex: selectedIndex,
                  isVisible: true,
                  onDestinationSelected: (int index) {
                    setState(() => selectedIndex = index);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('nav-item-profile')));
    await tester.pumpAndSettle();

    expect(flutterError, isNull);
    expect(tester.takeException(), isNull);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('Bottom navigation hides without layout overflow',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    FlutterErrorDetails? flutterError;
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      flutterError ??= details;
    };
    addTearDown(() {
      FlutterError.onError = previousOnError;
    });

    var isVisible = true;
    late StateSetter updateVisibility;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            updateVisibility = setState;
            return Scaffold(
              bottomNavigationBar: PremiumBottomNavigationBar(
                selectedIndex: 0,
                isVisible: isVisible,
                onDestinationSelected: (_) {},
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    updateVisibility(() => isVisible = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    await tester.pumpAndSettle();

    expect(flutterError, isNull);
    expect(tester.takeException(), isNull);
  });
}
