import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../models/stock.dart';
import '../../providers/stock_providers.dart';
import '../../widgets/demo_badge.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/stock_card.dart';
import '../stock_details/stock_details_screen.dart';

/// Search by company name or ticker.
///
/// In [pickMode] tapping a result adds it to the comparison and returns to the
/// previous screen; otherwise it opens the stock's details.
class StockSearchScreen extends ConsumerStatefulWidget {
  const StockSearchScreen({super.key, this.pickMode = false});

  final bool pickMode;

  @override
  ConsumerState<StockSearchScreen> createState() => _StockSearchScreenState();
}

class _StockSearchScreenState extends ConsumerState<StockSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      setState(() => _query = '');
      return;
    }
    // Debounced: no request is made for every keystroke.
    _debounce = Timer(AppConstants.searchDebounce, () {
      if (mounted) setState(() => _query = trimmed);
    });
  }

  void _submit(String text) {
    _debounce?.cancel();
    setState(() => _query = text.trim());
  }

  void _addToComparison(Stock stock) {
    final result = ref.read(selectedStocksProvider.notifier).add(stock);
    final message = switch (result) {
      AddResult.added => '${stock.displaySymbol} added to comparison.',
      AddResult.duplicate => '${stock.displaySymbol} is already selected.',
      AddResult.limitReached =>
        'You can compare at most ${AppConstants.maxCompareStocks} stocks.',
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _onSelect(Stock stock) {
    if (widget.pickMode) {
      _addToComparison(stock);
      Navigator.of(context).maybePop();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StockDetailsScreen(stock: stock),
        ),
      );
    }
  }

  Widget _resultTile(Stock stock) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: StockCard(
        stock: stock,
        onTap: () => _onSelect(stock),
        trailing: widget.pickMode
            ? const Icon(Icons.add_circle_outline)
            : IconButton(
                tooltip: 'Add ${stock.displaySymbol} to comparison',
                icon: const Icon(Icons.add_chart),
                onPressed: () => _addToComparison(stock),
              ),
      ),
    );
  }

  Widget _body() {
    final theme = Theme.of(context);
    if (_query.length < AppConstants.minSearchLength) {
      final suggestions = ref.watch(stockRepositoryProvider).suggestedStocks;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Type at least ${AppConstants.minSearchLength} characters of a '
            'company name or ticker symbol.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text('Suggestions', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final s in suggestions) _resultTile(s),
        ],
      );
    }

    final results = ref.watch(searchResultsProvider(_query));
    return results.when(
      loading: () => const LoadingWidget(message: 'Searching\u2026'),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(searchResultsProvider(_query)),
      ),
      data: (stocks) {
        if (stocks.isEmpty) {
          return EmptyState(
            icon: Icons.search_off,
            title: 'No matching stocks',
            message: 'Nothing matched "$_query". Try a different name or '
                'ticker symbol.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [for (final s in stocks) _resultTile(s)],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: _submit,
          decoration: const InputDecoration(
            hintText: 'Search company or ticker',
            border: InputBorder.none,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: DemoBadge()),
          ),
        ],
      ),
      body: _body(),
    );
  }
}
