import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../providers/settings_provider.dart';
import '../providers/stock_providers.dart';

IconData _iconFor(AppErrorType type) {
  switch (type) {
    case AppErrorType.network:
      return Icons.wifi_off;
    case AppErrorType.timeout:
      return Icons.timer_off_outlined;
    case AppErrorType.rateLimit:
      return Icons.hourglass_top;
    case AppErrorType.invalidKey:
      return Icons.vpn_key_off_outlined;
    case AppErrorType.planRestricted:
      return Icons.lock_outline;
    case AppErrorType.notFound:
    case AppErrorType.noData:
      return Icons.search_off;
    case AppErrorType.parse:
    case AppErrorType.invalidInput:
    case AppErrorType.unknown:
      return Icons.error_outline;
  }
}

/// Shows a user-friendly message for any thrown object, with a retry action
/// and (in live mode) an explicit, user-initiated switch to demo data.
/// Raw exceptions and stack traces are never displayed.
class ErrorView extends ConsumerWidget {
  const ErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
  });

  final Object error;
  final VoidCallback? onRetry;

  /// Single-row variant for use inside list items.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = AppException.from(error);
    final theme = Theme.of(context);
    final isDemo = ref.watch(isDemoProvider);
    final canRetry = onRetry != null &&
        e.type != AppErrorType.invalidKey &&
        e.type != AppErrorType.planRestricted;

    if (compact) {
      return Row(
        children: [
          Icon(_iconFor(e.type), size: 18, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              e.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ),
          if (canRetry)
            IconButton(
              tooltip: 'Retry',
              icon: const Icon(Icons.refresh),
              onPressed: onRetry,
            ),
        ],
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconFor(e.type), size: 56, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              e.message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (e.hint != null) ...[
              const SizedBox(height: 8),
              Text(
                e.hint!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                if (canRetry)
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                if (!isDemo)
                  OutlinedButton.icon(
                    onPressed: () => ref
                        .read(settingsProvider.notifier)
                        .setDataMode(DataMode.demo),
                    icon: const Icon(Icons.science_outlined),
                    label: const Text('Use demo data'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
