import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/expense_model.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/services/expense_filter_service.dart';
import '../../../../presentation/providers/expense_provider.dart';
import '../../../../presentation/providers/expense_filter_provider.dart';
import '../../../../presentation/providers/trip_provider.dart';
import '../../../../presentation/providers/firebase_providers.dart';
import '../../../../presentation/providers/category_provider.dart';
import '../../../../presentation/providers/settlement_provider.dart';
import '../../../../presentation/providers/authentication_provider.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final routeState = GoRouterState.of(context);
    final tripId = routeState.pathParameters['tripId'] ?? '';
    final expenses = ref.watch(filteredExpensesProvider(tripId));
    final filter = ref.watch(filterProvider);
    final expensesAsync = ref.watch(tripExpensesProvider(tripId));
    final allExpenses = expensesAsync.valueOrNull ?? [];
    final isLoading = expensesAsync.isLoading;
    final tripAsync = ref.watch(tripByIdProvider(tripId));
    final trip = tripAsync.valueOrNull;
    final isReadOnly = trip != null && !trip.isActive;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Expenses',
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.search_off_rounded : Icons.search_rounded),
            onPressed: () => setState(() => _showSearch = !_showSearch),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () => _showFilterSheet(context, tripId, colorScheme),
          ),
        ],
      ),
      floatingActionButton: isReadOnly
          ? null
          : FloatingActionButton(
              onPressed: () => context.pushNamed(
                'addExpense',
                pathParameters: {'tripId': tripId},
              ),
              child: const Icon(Icons.add_rounded),
            ),
      body: Column(
        children: [
          if (_showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search expenses...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchCtrl.clear();
                            ref.read(filterProvider.notifier).setSearch('');
                          },
                        )
                      : null,
                ),
                onChanged: (v) =>
                    ref.read(filterProvider.notifier).setSearch(v),
              ),
            ),
          if (filter.searchQuery.isNotEmpty ||
              filter.categoryFilter != null ||
              filter.paidByFilter != null ||
              filter.dateStart != null ||
              filter.dateEnd != null ||
              filter.amountMin != null ||
              filter.amountMax != null ||
              filter.onlyMyExpenses ||
              filter.onlyMyParticipations)
            _ActiveFiltersChip(
              filter: filter,
              tripId: tripId,
              onClearAll: () =>
                  ref.read(filterProvider.notifier).resetAll(),
            ),
          Expanded(
            child: isLoading
                ? const LoadingIndicator(message: 'Loading expenses...')
                : expenses.isEmpty
                    ? _buildEmptyState(context, colorScheme, tripId, allExpenses.isEmpty)
                    : _ExpensesList(expenses: expenses, tripId: tripId),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
      BuildContext context, ColorScheme colorScheme, String tripId, bool noExpenses) {
    final tripAsync = ref.watch(tripByIdProvider(tripId));
    final trip = tripAsync.valueOrNull;
    final isReadOnly = trip != null && !trip.isActive;

    if (noExpenses) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 80,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
              const SizedBox(height: 24),
              Text(
                isReadOnly ? 'No expenses recorded' : 'No expenses yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isReadOnly
                    ? 'This trip has no expenses.'
                    : 'Add your first expense to start tracking trip costs.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              if (!isReadOnly) ...[
                const SizedBox(height: 32),
                PrimaryButton(
                  label: 'Add Expense',
                  icon: Icons.add_rounded,
                  onPressed: () => context.pushNamed(
                    'addExpense',
                    pathParameters: {'tripId': tripId},
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded,
              size: 64, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            'No matching expenses',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters.',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(
      BuildContext context, String tripId, ColorScheme colorScheme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _FilterSheet(
        tripId: tripId,
        colorScheme: colorScheme,
      ),
    );
  }
}

class _ActiveFiltersChip extends ConsumerWidget {
  final FilterState filter;
  final String tripId;
  final VoidCallback onClearAll;

  const _ActiveFiltersChip({
    required this.filter,
    required this.tripId,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final chips = <Widget>[];

    if (filter.searchQuery.isNotEmpty) {
      chips.add(_buildChip('"${filter.searchQuery}"', colorScheme, () {
        ref.read(filterProvider.notifier).setSearch('');
      }));
    }
    if (filter.categoryFilter != null) {
      chips.add(_buildChip(filter.categoryFilter!, colorScheme, () {
        ref.read(filterProvider.notifier).clearCategory();
      }));
    }
    if (filter.paidByFilter != null) {
      final nameAsync = ref.watch(userNameProvider(filter.paidByFilter!));
      final name = nameAsync.valueOrNull ?? filter.paidByFilter!;
      chips.add(_buildChip(name, colorScheme, () {
        ref.read(filterProvider.notifier).clearPaidBy();
      }));
    }
    if (filter.onlyMyExpenses) {
      chips.add(_buildChip('My expenses', colorScheme, () {
        ref.read(filterProvider.notifier).toggleMyExpenses();
      }));
    }
    if (filter.onlyMyParticipations) {
      chips.add(_buildChip('I\'m in', colorScheme, () {
        ref.read(filterProvider.notifier).toggleMyParticipations();
      }));
    }
    if (filter.dateStart != null || filter.dateEnd != null) {
      final label = filter.dateStart != null && filter.dateEnd != null
          ? '${DateFormatter.formatShort(filter.dateStart!)} - ${DateFormatter.formatShort(filter.dateEnd!)}'
          : filter.dateStart != null
              ? 'From ${DateFormatter.formatShort(filter.dateStart!)}'
              : 'To ${DateFormatter.formatShort(filter.dateEnd!)}';
      chips.add(_buildChip(label, colorScheme, () {
        ref.read(filterProvider.notifier).clearDateRange();
      }));
    }
    if (filter.amountMin != null || filter.amountMax != null) {
      final label = filter.amountMin != null && filter.amountMax != null
          ? '${CurrencyFormatter.format(filter.amountMin!)} - ${CurrencyFormatter.format(filter.amountMax!)}'
          : filter.amountMin != null
              ? 'Min ${CurrencyFormatter.format(filter.amountMin!)}'
              : 'Max ${CurrencyFormatter.format(filter.amountMax!)}';
      chips.add(_buildChip(label, colorScheme, () {
        ref.read(filterProvider.notifier).clearAmountRange();
      }));
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...chips,
            const SizedBox(width: 4),
            TextButton(
              onPressed: onClearAll,
              child: const Text('Clear all'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, ColorScheme colorScheme, VoidCallback onRemove) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InputChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        deleteIcon: const Icon(Icons.close_rounded, size: 16),
        onDeleted: onRemove,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _FilterSheet extends ConsumerStatefulWidget {
  final String tripId;
  final ColorScheme colorScheme;

  const _FilterSheet({
    required this.tripId,
    required this.colorScheme,
  });

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  final _amountMinCtrl = TextEditingController();
  final _amountMaxCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final filter = ref.read(filterProvider);
    if (filter.amountMin != null) {
      _amountMinCtrl.text = filter.amountMin.toString();
    }
    if (filter.amountMax != null) {
      _amountMaxCtrl.text = filter.amountMax.toString();
    }
  }

  @override
  void dispose() {
    _amountMinCtrl.dispose();
    _amountMaxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(filterProvider);
    final tripAsync = ref.watch(tripByIdProvider(widget.tripId));
    final trip = tripAsync.valueOrNull;
    final participants = trip?.participants ?? [];
    final categories = ref.watch(activeCategoriesProvider(widget.tripId));

    final participantNames = <String, String>{};
    for (final uid in participants) {
      final nameAsync = ref.watch(userNameProvider(uid));
      participantNames[uid] = nameAsync.valueOrNull ?? uid;
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'Filters & Sort',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: widget.colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      _amountMinCtrl.clear();
                      _amountMaxCtrl.clear();
                      ref.read(filterProvider.notifier).resetAll();
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Sort By',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: widget.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: SortOption.values.map((opt) {
                    final isSelected = filter.sortOption == opt;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_sortLabel(opt)),
                        selected: isSelected,
                        onSelected: (_) =>
                            ref.read(filterProvider.notifier).setSort(opt),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              Text('Category',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: widget.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('All'),
                        selected: filter.categoryFilter == null,
                        onSelected: (_) =>
                            ref.read(filterProvider.notifier).clearCategory(),
                      ),
                    ),
                    ...categories.map((cat) {
                      final isSelected = filter.categoryFilter == cat.name;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: Icon(cat.icon, size: 16, color: cat.color),
                          label: Text(cat.name),
                          selected: isSelected,
                          onSelected: (_) =>
                              ref.read(filterProvider.notifier).setCategory(cat.name),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Paid By',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: widget.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Anyone'),
                    selected: filter.paidByFilter == null,
                    onSelected: (_) =>
                        ref.read(filterProvider.notifier).clearPaidBy(),
                  ),
                  ...participants.map((uid) {
                    final isSelected = filter.paidByFilter == uid;
                    return ChoiceChip(
                      label: Text(participantNames[uid] ?? uid),
                      selected: isSelected,
                      onSelected: (_) =>
                          ref.read(filterProvider.notifier).setPaidBy(uid),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 20),
              Text('Date Range',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: widget.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: filter.dateStart ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          ref.read(filterProvider.notifier).setDateRange(
                              picked, filter.dateEnd);
                        }
                      },
                      child: Text(filter.dateStart != null
                          ? DateFormatter.formatShort(filter.dateStart!)
                          : 'Start date'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: filter.dateEnd ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          ref.read(filterProvider.notifier).setDateRange(
                              filter.dateStart, picked);
                        }
                      },
                      child: Text(filter.dateEnd != null
                          ? DateFormatter.formatShort(filter.dateEnd!)
                          : 'End date'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Amount Range',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: widget.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amountMinCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Min',
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        final val = double.tryParse(v);
                        ref.read(filterProvider.notifier).setAmountRange(
                            val, filter.amountMax);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _amountMaxCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Max',
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        final val = double.tryParse(v);
                        ref.read(filterProvider.notifier).setAmountRange(
                            filter.amountMin, val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Visibility',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: widget.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilterChip(
                      label: const Text('My expenses'),
                      selected: filter.onlyMyExpenses,
                      onSelected: (_) =>
                          ref.read(filterProvider.notifier).toggleMyExpenses(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilterChip(
                      label: const Text('I\'m included'),
                      selected: filter.onlyMyParticipations,
                      onSelected: (_) => ref
                          .read(filterProvider.notifier)
                          .toggleMyParticipations(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'Apply',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _sortLabel(SortOption opt) {
    switch (opt) {
      case SortOption.newest:
        return 'Newest';
      case SortOption.oldest:
        return 'Oldest';
      case SortOption.highestAmount:
        return 'Highest';
      case SortOption.lowestAmount:
        return 'Lowest';
      case SortOption.alphabetical:
        return 'A-Z';
    }
  }
}

class _ExpensesList extends ConsumerWidget {
  final List<ExpenseModel> expenses;
  final String tripId;

  const _ExpensesList({
    required this.expenses,
    required this.tripId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripByIdProvider(tripId));
    final trip = tripAsync.valueOrNull;
    final currentUser = ref.watch(authProvider).user;
    final balances = ref.watch(tripBalanceProvider(tripId));
    final totalAmount =
        expenses.fold<double>(0, (sum, e) => sum + e.amount);

    double currentBalance = 0;
    if (currentUser != null && balances != null) {
      final info = balances[currentUser.uid];
      currentBalance = info?.netBalance ?? 0;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        _SummaryHeader(
          totalExpenses: totalAmount,
          expenseCount: expenses.length,
          currentBalance: currentBalance,
          currency: trip?.currency ?? '\$',
        ),
        const SizedBox(height: 16),
        ...expenses.map((exp) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ExpenseCard(
                expense: exp,
                tripId: tripId,
              ),
            )),
      ],
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final double totalExpenses;
  final int expenseCount;
  final double currentBalance;
  final String currency;

  const _SummaryHeader({
    required this.totalExpenses,
    required this.expenseCount,
    required this.currentBalance,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _MetricTile(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Total Trip',
                value: CurrencyFormatter.format(totalExpenses),
                color: colorScheme.primary,
                colorScheme: colorScheme,
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: colorScheme.surfaceContainerHighest,
            ),
            Expanded(
              child: _MetricTile(
                icon: Icons.balance_rounded,
                label: 'Your Balance',
                value: currentBalance >= 0
                    ? CurrencyFormatter.format(currentBalance)
                    : '-${CurrencyFormatter.format(-currentBalance)}',
                color: currentBalance >= 0 ? Colors.green : Colors.red,
                colorScheme: colorScheme,
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: colorScheme.surfaceContainerHighest,
            ),
            Expanded(
              child: _MetricTile(
                icon: Icons.receipt_rounded,
                label: 'Expenses',
                value: '$expenseCount',
                color: colorScheme.tertiary,
                colorScheme: colorScheme,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final ColorScheme colorScheme;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
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

class _ExpenseCard extends ConsumerStatefulWidget {
  final ExpenseModel expense;
  final String tripId;

  const _ExpenseCard({
    required this.expense,
    required this.tripId,
  });

  @override
  ConsumerState<_ExpenseCard> createState() => _ExpenseCardState();
}

class _ExpenseCardState extends ConsumerState<_ExpenseCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final catInfo = ref.watch(categoryInfoProvider(widget.tripId));
    final payerName = ref.watch(userNameProvider(widget.expense.paidBy));
    final currentUser = ref.watch(authProvider).user;

    final categoryInfo = catInfo[widget.expense.category];
    final icon = categoryInfo?.icon ?? Icons.receipt_long_rounded;
    final color = categoryInfo?.color ?? Colors.grey;
    final label = categoryInfo?.name ?? widget.expense.category;
    final payerDisplay = payerName.valueOrNull ?? widget.expense.paidBy;

    final participantNames = <String, String>{};
    for (final detail in widget.expense.splitDetails) {
      final nameAsync = ref.watch(userNameProvider(detail.userId));
      participantNames[detail.userId] = nameAsync.valueOrNull ?? detail.userId;
    }

    final isMyExpense = currentUser != null && widget.expense.paidBy == currentUser.uid;
    final amIParticipating = currentUser != null &&
        widget.expense.splitDetails.any((d) => d.userId == currentUser.uid);

    return SizeTransition(
      sizeFactor: _anim,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: _anim,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.pushNamed(
              'expenseDetails',
              pathParameters: {
                'tripId': widget.tripId,
                'expenseId': widget.expense.expenseId,
              },
              extra: widget.expense,
            ),
            onLongPress: () => _showExpenseOptions(context, ref, colorScheme),
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
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.expense.expenseName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
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
                            CurrencyFormatter.format(widget.expense.amount),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: _splitTypeColor(
                                  widget.expense.splitType, colorScheme),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.expense.splitLabel,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: _splitTypeTextColor(
                                    widget.expense.splitType, colorScheme),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: colorScheme.onSurfaceVariant),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.person_outlined,
                          size: 13, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          payerDisplay,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.expense.splitDetails.length > 1) ...[
                        const SizedBox(width: 4),
                        ...widget.expense.splitDetails.take(3).map((d) {
                          final uname = participantNames[d.userId] ?? d.userId;
                          return Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: CircleAvatar(
                              radius: 8,
                              backgroundColor: colorScheme.surfaceContainerHighest,
                              child: Text(
                                uname.isNotEmpty
                                    ? uname[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                          );
                        }),
                        if (widget.expense.splitDetails.length > 3)
                          Text(
                            '+${widget.expense.splitDetails.length - 3}',
                            style: TextStyle(
                              fontSize: 9,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                      const Spacer(),
                      if (isMyExpense)
                        _tag('You paid', Colors.green, colorScheme),
                      if (!isMyExpense && amIParticipating)
                        _tag('You\'re in', colorScheme.primary, colorScheme),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 12, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        DateFormatter.formatShort(widget.expense.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(widget.expense.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (widget.expense.receiptUrl != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.attachment_rounded,
                            size: 13, color: colorScheme.primary),
                        Text(
                          'Receipt',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (widget.expense.notes != null &&
                      widget.expense.notes!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.notes_rounded,
                              size: 13, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.expense.notes!,
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tag(String text, Color color, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _splitTypeColor(String splitType, ColorScheme cs) {
    switch (splitType) {
      case 'equal':
        return cs.primary.withValues(alpha: 0.1);
      case 'exact':
        return Colors.orange.withValues(alpha: 0.1);
      case 'percentage':
        return Colors.purple.withValues(alpha: 0.1);
      case 'shares':
        return Colors.teal.withValues(alpha: 0.1);
      case 'paidOnly':
        return Colors.blue.withValues(alpha: 0.1);
      default:
        return cs.surfaceContainerHighest;
    }
  }

  Color _splitTypeTextColor(String splitType, ColorScheme cs) {
    switch (splitType) {
      case 'equal':
        return cs.primary;
      case 'exact':
        return Colors.orange.shade700;
      case 'percentage':
        return Colors.purple.shade700;
      case 'shares':
        return Colors.teal.shade700;
      case 'paidOnly':
        return Colors.blue.shade700;
      default:
        return cs.onSurfaceVariant;
    }
  }

  String _formatTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final amPm = hour < 12 ? 'AM' : 'PM';
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$h:$minute $amPm';
  }

  void _showExpenseOptions(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
  ) {
    final tripAsync = ref.read(tripByIdProvider(widget.tripId));
    final trip = tripAsync.valueOrNull;
    final isReadOnly = trip != null && !trip.isActive;

    if (isReadOnly) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit Expense'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.pushNamed(
                    'addExpense',
                    pathParameters: {'tripId': widget.tripId},
                    extra: widget.expense,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outlined, color: Colors.red),
                title: const Text('Delete Expense',
                    style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final confirmed = await ConfirmationDialog.show(
                    context,
                    title: 'Delete Expense',
                    message:
                        'Are you sure you want to delete "${widget.expense.expenseName}"?',
                    confirmLabel: 'Delete',
                    icon: Icons.delete_rounded,
                    confirmColor: colorScheme.error,
                  );
                  if (confirmed == true && context.mounted) {
                    final success = await ref
                        .read(expenseProvider.notifier)
                        .deleteExpense(widget.expense.expenseId);
                    if (context.mounted) {
                      if (success) {
                        SnackbarHelper.showSuccess(
                            context, 'Expense deleted.');
                      } else {
                        SnackbarHelper.showError(
                          context,
                          ref.read(expenseProvider).error ??
                              'Failed to delete expense.',
                        );
                      }
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
