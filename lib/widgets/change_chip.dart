import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';

/// Percentage change with an arrow icon AND a sign, so gain/loss is never
/// conveyed by colour alone.
class ChangeChip extends StatelessWidget {
  const ChangeChip({super.key, required this.percent, this.dense = false});

  /// Percentage points; null renders a neutral "unavailable" chip.
  final double? percent;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final value = percent;
    final color = AppColors.forValue(context, value);
    final IconData icon;
    final String spoken;
    if (value == null || !value.isFinite) {
      icon = Icons.remove;
      spoken = 'Change unavailable';
    } else if (value > 0) {
      icon = Icons.arrow_drop_up;
      spoken = 'Up ${value.abs().toStringAsFixed(2)} percent';
    } else if (value < 0) {
      icon = Icons.arrow_drop_down;
      spoken = 'Down ${value.abs().toStringAsFixed(2)} percent';
    } else {
      icon = Icons.remove;
      spoken = 'Unchanged';
    }
    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: dense ? 4 : 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.alpha(color, 0.14),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            Text(
              Fmt.percent(value),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: dense ? 12 : 13,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
