import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stock_scope/core/constants/app_constants.dart';
import 'package:stock_scope/core/errors/app_exception.dart';
import 'package:stock_scope/core/theme/app_theme.dart';
import 'package:stock_scope/features/comparison/comparison_screen.dart';
import 'package:stock_scope/features/dashboard/home_screen.dart';
import 'package:stock_scope/features/settings/settings_screen.dart';
import 'package:stock_scope/features/splash/splash_screen.dart';
import 'package:stock_scope/features/stock_search/stock_search_screen.dart';
import 'package:stock_scope/features/watchlist/watchlist_screen.dart';
import 'package:stock_scope/models/stock.dart';
import 'package:stock_scope/models/stock_comparison.dart';
import 'package:stock_scope/providers/settings_provider.dart';
import 'package:stock_scope/providers/stock_providers.dart';
import 'package:stock_scope/providers/watchlist_provider.dart';

/// Pumps [child] with demo data (no API key), isolated preferences and no
/// network access.
Future<ProviderContainer> pumpApp(
  WidgetTester tester,
  Widget child, {
  Map<String, Object> prefsValues = const {},
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues(prefsValues);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiKeyProvider.overrideWithValue(null),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: child,
      ),
    ),
  );
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

void main() {
  testWidgets('splash shows name and tagline, then moves on', (tester) async {
    await pumpApp(
        tester, const SplashScreen(duration: Duration(milliseconds: 100)));
    expect(find.text(AppConstants.appName), findsOneWidget);
    expect(find.text(AppConstants.tagline), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
  });

  testWidgets('dashboard renders with Compare Stocks button and demo badge',
      (tester) async {
    await pumpApp(tester, const HomeScreen());
    await tester.pumpAndSettle();
    expect(find.text('Compare Stocks'), findsOneWidget);
    expect(find.text('DEMO DATA'), findsWidgets);
    expect(find.text('Watchlist'), findsOneWidget);
    expect(find.text('Sample stocks (synthetic)'), findsOneWidget);
  });

  testWidgets('search debounces, shows matches, and handles no results',
      (tester) async {
    await pumpApp(tester, const StockSearchScreen());
    await tester.enterText(find.byType(TextField), 'tcs');
    // Before the debounce elapses nothing is searched.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Tata Consultancy Services'), findsNothing);
    await tester.pump(AppConstants.searchDebounce);
    await tester.pumpAndSettle();
    expect(find.text('Tata Consultancy Services'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'qqqqq');
    await tester.pump(AppConstants.searchDebounce);
    await tester.pumpAndSettle();
    expect(find.text('No matching stocks'), findsOneWidget);
  });

  testWidgets('selecting a search result adds it once (no duplicates)',
      (tester) async {
    final container =
        await pumpApp(tester, const StockSearchScreen(pickMode: true));
    await tester.enterText(find.byType(TextField), 'infosys');
    await tester.pump(AppConstants.searchDebounce);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Infosys'));
    await tester.pumpAndSettle();
    expect(container.read(selectedStocksProvider).map((s) => s.symbol), ['INFY']);

    final result = container.read(selectedStocksProvider.notifier).add(
        const Stock(symbol: 'INFY', companyName: 'Infosys'));
    expect(result, AddResult.duplicate);
  });

  test('selection is limited to five stocks', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      apiKeyProvider.overrideWithValue(null),
    ]);
    addTearDown(container.dispose);
    final n = container.read(selectedStocksProvider.notifier);
    for (var i = 0; i < 5; i++) {
      expect(n.add(Stock(symbol: 'S$i', companyName: 'S$i')), AddResult.added);
    }
    expect(n.add(const Stock(symbol: 'S9', companyName: 'S9')),
        AddResult.limitReached);
  });

  testWidgets('empty watchlist shows an empty state', (tester) async {
    await pumpApp(tester, const WatchlistScreen());
    await tester.pumpAndSettle();
    expect(find.text('Your watchlist is empty'), findsOneWidget);
  });

  testWidgets('watchlist is restored from saved preferences', (tester) async {
    await pumpApp(
      tester,
      const WatchlistScreen(),
      prefsValues: {
        'watchlist_v1':
            '[{"symbol":"TCS","companyName":"Tata Consultancy Services","exchange":"NSE","currency":"INR"}]',
      },
    );
    await tester.pumpAndSettle();
    expect(find.text('Tata Consultancy Services'), findsOneWidget);
  });

  test('watchlist add/remove persists to storage', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c1 = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      apiKeyProvider.overrideWithValue(null),
    ]);
    addTearDown(c1.dispose);
    await c1.read(watchlistProvider.notifier).add(
        const Stock(symbol: 'ITC', companyName: 'ITC Limited'));

    // A fresh container over the same storage simulates an app restart.
    final c2 = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      apiKeyProvider.overrideWithValue(null),
    ]);
    addTearDown(c2.dispose);
    expect(c2.read(watchlistProvider).map((s) => s.symbol), ['ITC']);
    await c2.read(watchlistProvider.notifier).remove('ITC');
    expect(c2.read(watchlistProvider), isEmpty);
  });

  testWidgets('comparison screen shows a loading state', (tester) async {
    final never = Completer<StockComparison>();
    await pumpApp(
      tester,
      const ComparisonScreen(),
      overrides: [
        comparisonProvider.overrideWith((ref) => never.future),
      ],
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading price history\u2026'), findsOneWidget);
  });

  testWidgets('comparison screen shows a friendly error with retry',
      (tester) async {
    await pumpApp(
      tester,
      const ComparisonScreen(),
      overrides: [
        comparisonProvider.overrideWith((ref) async {
          throw const AppException(
            AppErrorType.network,
            'Unable to reach the data provider. You may be offline.',
          );
        }),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to reach the data provider'),
        findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets('theme choice is applied and persisted', (tester) async {
    final container = await pumpApp(tester, const SettingsScreen());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).themeMode, ThemeMode.dark);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'dark');
  });

  testWidgets('settings shows demo indicator and disclaimer', (tester) async {
    await pumpApp(tester, const SettingsScreen());
    await tester.pumpAndSettle();
    expect(find.textContaining('Demo mode is ON'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(AppConstants.disclaimer),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(AppConstants.disclaimer), findsOneWidget);
  });
}
