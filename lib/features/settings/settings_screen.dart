import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../providers/settings_provider.dart';
import '../../providers/stock_providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/demo_badge.dart';
import '../../widgets/period_selector.dart';
import '../../widgets/section_header.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final repo = ref.watch(stockRepositoryProvider);
    final hasKey = ref.watch(apiKeyProvider) != null;
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const SectionHeader(title: 'Appearance'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Theme', style: theme.textTheme.titleSmall),
                const SizedBox(height: 10),
                SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.brightness_auto),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode_outlined),
                    ),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (s) => notifier.setThemeMode(s.first),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Comparison defaults'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Default comparison period',
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 10),
                PeriodSelector(
                  selected: settings.defaultPeriod,
                  onSelected: notifier.setDefaultPeriod,
                ),
                const SizedBox(height: 16),
                Text('Preferred market', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'Search results from this market are listed first. Other '
                  'markets are still shown.',
                  style: muted,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final m in PreferredMarket.values)
                      ChoiceChip(
                        label: Text(m.label),
                        selected: settings.preferredMarket == m,
                        onSelected: (_) => notifier.setPreferredMarket(m),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Data source'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Active source: ${repo.sourceName}',
                          style: theme.textTheme.titleSmall),
                    ),
                    const DemoBadge(),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  repo.isDemo
                      ? 'Demo mode is ON. All prices and dividends are '
                          'synthetic samples. The app is not connected to any '
                          'exchange or market data provider.'
                      : 'Live mode: data is requested from the configured '
                          'provider and shown with its last observation date.',
                  style: muted,
                ),
                const SizedBox(height: 12),
                SegmentedButton<DataMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: DataMode.demo,
                      label: Text('Demo data'),
                      icon: Icon(Icons.science_outlined),
                    ),
                    ButtonSegment(
                      value: DataMode.live,
                      label: Text('Live provider'),
                      icon: Icon(Icons.cloud_outlined),
                    ),
                  ],
                  selected: {settings.dataMode},
                  onSelectionChanged: (s) => notifier.setDataMode(s.first),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      hasKey ? Icons.check_circle_outline : Icons.key_off_outlined,
                      size: 18,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasKey
                            ? 'An API key is configured (value hidden).'
                            : 'No API key configured. Add ${AppConstants.apiKeyEnvName} '
                                'to .env to use live data.',
                        style: muted,
                      ),
                    ),
                  ],
                ),
                if (settings.dataMode == DataMode.live && !hasKey)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Live mode needs an API key; requests will fail until one '
                      'is configured. Switch to demo data to keep exploring.',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(repo.historyNote, style: muted),
              ],
            ),
          ),
          const SectionHeader(title: 'About'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${AppConstants.appName} v${AppConstants.version}',
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(AppConstants.tagline, style: muted),
                const SizedBox(height: 8),
                Text(
                  'A Flutter mini project for comparing stock performance using '
                  'historical data.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Financial disclaimer'),
          const AppCard(child: Text(AppConstants.disclaimer)),
        ],
      ),
    );
  }
}
