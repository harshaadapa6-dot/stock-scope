import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/stock_providers.dart';
import '../comparison/compare_setup_screen.dart';
import '../dashboard/home_screen.dart';
import '../settings/settings_screen.dart';
import '../watchlist/watchlist_screen.dart';

/// Bottom navigation on phones, navigation rail on wider screens.
class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const _pages = <Widget>[
    HomeScreen(),
    CompareSetupScreen(),
    WatchlistScreen(),
    SettingsScreen(),
  ];

  static const _labels = ['Home', 'Compare', 'Watchlist', 'Settings'];
  static const _icons = [
    Icons.home_outlined,
    Icons.compare_arrows,
    Icons.star_outline,
    Icons.settings_outlined,
  ];
  static const _selectedIcons = [
    Icons.home,
    Icons.compare_arrows,
    Icons.star,
    Icons.settings,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(navIndexProvider);
    final notifier = ref.read(navIndexProvider.notifier);
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final body = IndexedStack(index: index, children: _pages);

    return PopScope(
      // Back from any tab other than Home returns to Home first.
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) notifier.go(0);
      },
      child: Scaffold(
        body: wide
            ? Row(
                children: [
                  NavigationRail(
                    selectedIndex: index,
                    onDestinationSelected: notifier.go,
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      for (var i = 0; i < _labels.length; i++)
                        NavigationRailDestination(
                          icon: Icon(_icons[i]),
                          selectedIcon: Icon(_selectedIcons[i]),
                          label: Text(_labels[i]),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: body),
                ],
              )
            : body,
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: index,
                onDestinationSelected: notifier.go,
                destinations: [
                  for (var i = 0; i < _labels.length; i++)
                    NavigationDestination(
                      icon: Icon(_icons[i]),
                      selectedIcon: Icon(_selectedIcons[i]),
                      label: _labels[i],
                    ),
                ],
              ),
      ),
    );
  }
}
