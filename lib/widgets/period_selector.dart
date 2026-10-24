import 'package:flutter/material.dart';

import '../core/utils/date_utils.dart';

/// Row of preset period chips. Pass a null [selected] for custom ranges.
class PeriodSelector extends StatelessWidget {
  const PeriodSelector({
    super.key,
    required this.selected,
    required this.onSelected,
    this.periods = ComparisonPeriod.values,
  });

  final ComparisonPeriod? selected;
  final ValueChanged<ComparisonPeriod> onSelected;
  final List<ComparisonPeriod> periods;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final p in periods)
          ChoiceChip(
            label: Text(p.shortLabel),
            tooltip: p.label,
            selected: selected == p,
            onSelected: (_) => onSelected(p),
          ),
      ],
    );
  }
}
