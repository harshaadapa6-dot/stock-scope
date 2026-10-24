import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/date_utils.dart';

/// Must be overridden in main() (and in tests) with a loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden with a loaded instance.',
  ),
);

/// The configured API key, or null. Read from .env; never displayed in the UI.
/// Overridable in tests.
final apiKeyProvider = Provider<String?>((ref) {
  try {
    final value = dotenv.maybeGet(AppConstants.apiKeyEnvName)?.trim();
    return (value == null || value.isEmpty) ? null : value;
  } catch (_) {
    // dotenv was never loaded (e.g. in tests): treat as "no key".
    return null;
  }
});

enum DataMode { demo, live }

/// Preference used to order search results; it does not hide other markets.
enum PreferredMarket {
  any('Any'),
  india('India (NSE/BSE)'),
  us('United States');

  const PreferredMarket(this.label);
  final String label;

  bool matches(String? exchange) {
    final e = (exchange ?? '').toUpperCase();
    switch (this) {
      case PreferredMarket.any:
        return true;
      case PreferredMarket.india:
        return e.contains('NSE') || e.contains('BSE');
      case PreferredMarket.us:
        return e.contains('NASDAQ') || e.contains('NYSE') || e.contains('AMEX');
    }
  }
}

class SettingsState {
  const SettingsState({
    required this.themeMode,
    required this.defaultPeriod,
    required this.dataMode,
    required this.preferredMarket,
  });

  final ThemeMode themeMode;
  final ComparisonPeriod defaultPeriod;
  final DataMode dataMode;
  final PreferredMarket preferredMarket;

  SettingsState copyWith({
    ThemeMode? themeMode,
    ComparisonPeriod? defaultPeriod,
    DataMode? dataMode,
    PreferredMarket? preferredMarket,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      defaultPeriod: defaultPeriod ?? this.defaultPeriod,
      dataMode: dataMode ?? this.dataMode,
      preferredMarket: preferredMarket ?? this.preferredMarket,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  static const _kTheme = 'theme_mode';
  static const _kPeriod = 'default_period';
  static const _kMode = 'data_mode';
  static const _kMarket = 'preferred_market';

  late SharedPreferences _prefs;

  @override
  SettingsState build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    final hasKey = ref.read(apiKeyProvider) != null;
    return SettingsState(
      themeMode: ThemeMode.values.asNameMap()[_prefs.getString(_kTheme)] ??
          ThemeMode.system,
      defaultPeriod:
          ComparisonPeriod.values.asNameMap()[_prefs.getString(_kPeriod)] ??
              ComparisonPeriod.oneYear,
      // Without a key we default to demo mode so the app is always usable.
      dataMode: DataMode.values.asNameMap()[_prefs.getString(_kMode)] ??
          (hasKey ? DataMode.live : DataMode.demo),
      preferredMarket:
          PreferredMarket.values.asNameMap()[_prefs.getString(_kMarket)] ??
              PreferredMarket.any,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString(_kTheme, mode.name);
  }

  Future<void> setDefaultPeriod(ComparisonPeriod period) async {
    state = state.copyWith(defaultPeriod: period);
    await _prefs.setString(_kPeriod, period.name);
  }

  Future<void> setDataMode(DataMode mode) async {
    state = state.copyWith(dataMode: mode);
    await _prefs.setString(_kMode, mode.name);
  }

  Future<void> setPreferredMarket(PreferredMarket market) async {
    state = state.copyWith(preferredMarket: market);
    await _prefs.setString(_kMarket, market.name);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
