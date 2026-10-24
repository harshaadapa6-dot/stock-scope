import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/stock.dart';
import 'settings_provider.dart';

List<Stock> _decodeStocks(String? raw) {
  if (raw == null) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final out = <Stock>[];
    for (final item in decoded) {
      try {
        if (item is Map) out.add(Stock.fromJson(Map<String, dynamic>.from(item)));
      } catch (_) {
        // Skip a corrupt entry rather than losing the whole list.
      }
    }
    return out;
  } catch (_) {
    return const [];
  }
}

/// Watchlist persisted locally in SharedPreferences.
///
/// Stocks are kept even if they currently cannot be loaded (for example
/// after switching data source); the UI shows an error state for them.
class WatchlistNotifier extends Notifier<List<Stock>> {
  static const _key = 'watchlist_v1';
  late SharedPreferences _prefs;

  @override
  List<Stock> build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    return _decodeStocks(_prefs.getString(_key));
  }

  bool contains(String symbol) => state.any((s) => s.symbol == symbol);

  Future<void> add(Stock stock) async {
    if (contains(stock.symbol)) return;
    state = [...state, stock];
    await _save();
  }

  Future<void> remove(String symbol) async {
    state = [
      for (final s in state)
        if (s.symbol != symbol) s,
    ];
    await _save();
  }

  Future<void> toggle(Stock stock) =>
      contains(stock.symbol) ? remove(stock.symbol) : add(stock);

  Future<void> _save() => _prefs.setString(
        _key,
        jsonEncode([for (final s in state) s.toJson()]),
      );
}

final watchlistProvider =
    NotifierProvider<WatchlistNotifier, List<Stock>>(WatchlistNotifier.new);

/// The last few comparisons, newest first (max 5), persisted locally.
class RecentComparisonsNotifier extends Notifier<List<List<Stock>>> {
  static const _key = 'recent_comparisons_v1';
  late SharedPreferences _prefs;

  @override
  List<List<Stock>> build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    final raw = _prefs.getString(_key);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final group in decoded)
          if (group is List) _decodeStocks(jsonEncode(group)),
      ].where((g) => g.length >= 2).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> add(List<Stock> stocks) async {
    final key = (stocks.map((s) => s.symbol).toList()..sort()).join('|');
    final next = <List<Stock>>[
      List<Stock>.unmodifiable(stocks),
      for (final g in state)
        if ((g.map((s) => s.symbol).toList()..sort()).join('|') != key) g,
    ].take(5).toList();
    state = next;
    await _prefs.setString(
      _key,
      jsonEncode([
        for (final g in next) [for (final s in g) s.toJson()],
      ]),
    );
  }
}

final recentComparisonsProvider =
    NotifierProvider<RecentComparisonsNotifier, List<List<Stock>>>(
  RecentComparisonsNotifier.new,
);
