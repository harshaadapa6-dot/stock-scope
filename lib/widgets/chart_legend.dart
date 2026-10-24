import 'package:flutter/material.dart';

class LegendItem {
  const LegendItem(this.color, this.label);
  final Color color;
  final String label;
}

class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.items});

  final List<LegendItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 4,
                decoration: BoxDecoration(
                  color: item.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(item.label, style: theme.textTheme.labelMedium),
            ],
          ),
      ],
    );
  }
}
