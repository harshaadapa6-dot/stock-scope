import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';

/// States exactly what the data is: the last observation date, whether it was
/// served from the in-memory cache, and the source. It never claims "live".
class DataFreshnessLabel extends StatelessWidget {
  const DataFreshnessLabel({
    super.key,
    required this.asOf,
    required this.sourceName,
    this.fromCache = false,
    this.prefix = 'Last close',
  });

  final DateTime asOf;
  final String sourceName;
  final bool fromCache;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = '$prefix ${Fmt.date(asOf)}'
        '${fromCache ? ' \u00B7 cached' : ''} \u00B7 $sourceName';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule, size: 12, color: theme.colorScheme.outline),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
