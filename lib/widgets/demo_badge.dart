import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/stock_providers.dart';

/// Persistent "DEMO DATA" label. Renders nothing when live data is in use.
class DemoBadge extends ConsumerWidget {
  const DemoBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isDemoProvider)) return const SizedBox.shrink();
    return const DemoBadgeLabel();
  }
}

/// The badge itself, for places that already know data is synthetic.
class DemoBadgeLabel extends StatelessWidget {
  const DemoBadgeLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Demo data. Prices shown are synthetic, not real market prices.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.science_outlined,
                size: 14, color: scheme.onTertiaryContainer),
            const SizedBox(width: 4),
            Text(
              'DEMO DATA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: scheme.onTertiaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
