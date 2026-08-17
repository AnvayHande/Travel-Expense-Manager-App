
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/models/expense_model.dart';
import '../../../../core/models/category_model.dart';
import '../../../../core/services/ledger_service.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../presentation/providers/ledger_provider.dart';
import '../../../../presentation/providers/expense_provider.dart';
import '../../../../presentation/providers/trip_provider.dart';
import '../../../../presentation/providers/firebase_providers.dart';
import '../../../../presentation/providers/category_provider.dart';

class ParticipantLedgerScreen extends ConsumerStatefulWidget {
  const ParticipantLedgerScreen({super.key});

  @override
  ConsumerState<ParticipantLedgerScreen> createState() =>
      _ParticipantLedgerScreenState();
}

class _ParticipantLedgerScreenState
    extends ConsumerState<ParticipantLedgerScreen> {
  String? _categoryFilter;
  LedgerSortOption _sortOption = LedgerSortOption.date;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final routeState = GoRouterState.of(context);
    final tripId = routeState.pathParameters['tripId'] ?? '';
    final userId = routeState.pathParameters['userId'] ?? '';
    final tripAsync = ref.watch(tripByIdProvider(tripId));
    final trip = tripAsync.valueOrNull;
    final ledger = ref.watch(participantLedgerProvider2({
      'tripId': tripId,
      'userId': userId,
    }));
    final catInfo = ref.watch(categoryInfoProvider(tripId));

    final expensesAsync = ref.watch(tripExpensesProvider(tripId));
    final allExpenses = expensesAsync.valueOrNull ?? [];

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Participant Ledger',
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            onPressed: ledger != null
                ? () => _exportPdf(ledger, trip, catInfo)
                : null,
            tooltip: 'Export PDF',
          ),
        ],
      ),
      body: ledger == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _ProfileSummary(ledger: ledger, colorScheme: colorScheme),
                const Divider(height: 1),
                _FilterBar(
                  categoryFilter: _categoryFilter,
                  sortOption: _sortOption,
                  allExpenses: allExpenses,
                  catInfo: catInfo,
                  onCategoryChanged: (cat) =>
                      setState(() => _categoryFilter = cat),
                  onSortChanged: (opt) =>
                      setState(() => _sortOption = opt),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _ExpenseHistory(
                    ledger: ledger,
                    categoryFilter: _categoryFilter,
                    sortOption: _sortOption,
                    catInfo: catInfo,
                    colorScheme: colorScheme,
                  ),
                ),
                const Divider(height: 1),
                _BottomSummary(ledger: ledger, colorScheme: colorScheme),
              ],
            ),
    );
  }

  Future<void> _exportPdf(
    ParticipantLedger ledger,
    dynamic trip,
    Map<String, CategoryModel> catInfo,
  ) async {
    final service = LedgerService();
    final filteredEntries = service.filterAndSort(
      entries: ledger.entries,
      categoryFilter: _categoryFilter,
      sortOption: _sortOption,
    );

    final notifier = ref.read(ledgerExportProvider.notifier);
    final path = await notifier.exportLedgerPdf(
      ledger: ledger,
      filteredEntries: filteredEntries,
      tripName: trip?.tripName ?? 'Trip',
      catInfo: catInfo,
      categoryFilter: _categoryFilter,
    );

    if (path != null && mounted) {
      await Share.shareXFiles(
        [XFile(path)],
        text: '${ledger.userName} - Ledger',
      );
    } else if (mounted) {
      SnackbarHelper.showError(context, 'Failed to export PDF.');
    }
  }
}

class _ProfileSummary extends StatelessWidget {
  final ParticipantLedger ledger;
  final ColorScheme colorScheme;

  const _ProfileSummary({
    required this.ledger,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: colorScheme.onPrimary.withValues(alpha: 0.2),
            child: Text(
              ledger.userName.isNotEmpty
                  ? ledger.userName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            ledger.userName,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _metric(Icons.paid_rounded, 'Total Paid',
                  CurrencyFormatter.format(ledger.totalPaid), Colors.green.shade200, colorScheme),
              _verticalDivider(colorScheme),
              _metric(Icons.account_balance_rounded, 'Total Share',
                  CurrencyFormatter.format(ledger.totalOwed), Colors.orange.shade200, colorScheme),
              _verticalDivider(colorScheme),
              _metric(
                Icons.balance_rounded,
                'Net Balance',
                CurrencyFormatter.format(ledger.netBalance),
                ledger.netBalance >= 0
                    ? Colors.green.shade200
                    : Colors.red.shade200,
                colorScheme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(IconData icon, String label, String value, Color iconColor, ColorScheme cs) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: cs.onPrimary,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: cs.onPrimary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider(ColorScheme cs) {
    return Container(
      width: 1,
      height: 36,
      color: cs.onPrimary.withValues(alpha: 0.3),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String? categoryFilter;
  final LedgerSortOption sortOption;
  final List<ExpenseModel> allExpenses;
  final Map<String, CategoryModel> catInfo;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<LedgerSortOption> onSortChanged;

  const _FilterBar({
    required this.categoryFilter,
    required this.sortOption,
    required this.allExpenses,
    required this.catInfo,
    required this.onCategoryChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final categories = <String>{};
    for (final e in allExpenses) {
      categories.add(e.category);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('All', categoryFilter == null, colorScheme, () {
                    onCategoryChanged(null);
                  }),
                  ...categories.map((cat) {
                    final selected = categoryFilter == cat;
                    return _filterChip(cat, selected, colorScheme, () {
                      onCategoryChanged(selected ? null : cat);
                    });
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<LedgerSortOption>(
            icon: Icon(Icons.sort_rounded, color: colorScheme.onSurfaceVariant),
            onSelected: onSortChanged,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: LedgerSortOption.date,
                child: Row(
                  children: [
                    if (sortOption == LedgerSortOption.date)
                      Icon(Icons.check, size: 18, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text('Date'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: LedgerSortOption.amount,
                child: Row(
                  children: [
                    if (sortOption == LedgerSortOption.amount)
                      Icon(Icons.check, size: 18, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text('Amount'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: LedgerSortOption.category,
                child: Row(
                  children: [
                    if (sortOption == LedgerSortOption.category)
                      Icon(Icons.check, size: 18, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text('Category'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, ColorScheme cs, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _ExpenseHistory extends ConsumerWidget {
  final ParticipantLedger ledger;
  final String? categoryFilter;
  final LedgerSortOption sortOption;
  final Map<String, CategoryModel> catInfo;
  final ColorScheme colorScheme;

  const _ExpenseHistory({
    required this.ledger,
    required this.categoryFilter,
    required this.sortOption,
    required this.catInfo,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = LedgerService();
    final filtered = service.filterAndSort(
      entries: ledger.entries,
      categoryFilter: categoryFilter,
      sortOption: sortOption,
    );

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 48,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text('No matching expenses',
                style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final entry = filtered[index];
        final e = entry.expense;
        final cat = catInfo[e.category];
        final catColor = cat?.color ?? Colors.grey;
        final catIcon = cat?.icon ?? Icons.receipt_long_rounded;
        final isPayer = e.paidBy == ledger.userId;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.pushNamed(
                'expenseDetails',
                pathParameters: {
                  'tripId': e.tripId,
                  'expenseId': e.expenseId,
                },
                extra: e,
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(catIcon, color: catColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.expenseName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${e.category} \u2022 ${DateFormatter.formatShort(e.createdAt)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyFormatter.format(e.amount),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: isPayer
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isPayer ? 'Paid' : e.splitLabel,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: isPayer
                                      ? Colors.green.shade700
                                      : colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        Icon(Icons.person_pin_rounded,
                            size: 14, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          isPayer ? 'Paid by ${ledger.userName}' : 'Paid by ${_payerName(ref, e.paidBy)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Your Share: ${CurrencyFormatter.format(entry.participantShare)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _payerName(WidgetRef ref, String uid) {
    final nameAsync = ref.watch(userNameProvider(uid));
    return nameAsync.valueOrNull ?? uid;
  }
}

class _BottomSummary extends StatelessWidget {
  final ParticipantLedger ledger;
  final ColorScheme colorScheme;

  const _BottomSummary({
    required this.ledger,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.surfaceContainerHighest),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryItem(
              'Total Paid',
              CurrencyFormatter.format(ledger.totalPaid),
              Colors.green,
              colorScheme,
            ),
          ),
          Container(
            width: 1,
            height: 28,
            color: colorScheme.surfaceContainerHighest,
          ),
          Expanded(
            child: _summaryItem(
              'Total Share',
              CurrencyFormatter.format(ledger.totalOwed),
              colorScheme.primary,
              colorScheme,
            ),
          ),
          Container(
            width: 1,
            height: 28,
            color: colorScheme.surfaceContainerHighest,
          ),
          Expanded(
            child: _summaryItem(
              'Balance',
              CurrencyFormatter.format(ledger.netBalance),
              ledger.netBalance >= 0 ? Colors.green : Colors.red,
              colorScheme,
            ),
          ),
          Container(
            width: 1,
            height: 28,
            color: colorScheme.surfaceContainerHighest,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ledger.isSettled
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    ledger.isSettled ? 'Settled' : 'Pending',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: ledger.isSettled
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Status',
                  style: TextStyle(
                    fontSize: 9,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(
      String label, String value, Color color, ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
