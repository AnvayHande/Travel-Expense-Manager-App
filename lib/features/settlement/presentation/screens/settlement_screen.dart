import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/settlement_service.dart';
import '../../../../core/models/settlement_model.dart';
import '../../../../core/models/trip_model.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../../presentation/providers/settlement_provider.dart';
import '../../../../presentation/providers/trip_provider.dart';
import '../../../../presentation/providers/expense_provider.dart';
import '../../../../presentation/providers/authentication_provider.dart';
import '../../../../presentation/providers/firebase_providers.dart';
import '../../../../presentation/providers/activity_provider.dart';

class SettlementScreen extends ConsumerStatefulWidget {
  const SettlementScreen({super.key});

  @override
  ConsumerState<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends ConsumerState<SettlementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final routeState = GoRouterState.of(context);
    final tripId = routeState.pathParameters['tripId'] ?? '';

    final tripAsync = ref.watch(tripByIdProvider(tripId));
    final balancesAsync = ref.watch(tripBalanceProvider(tripId));
    final pendingTransactions =
        ref.watch(tripPendingTransactionsProvider(tripId));
    final completedSettlements =
        ref.watch(tripCompletedSettlementsProvider(tripId));
    final totalExpenses = ref.watch(tripTotalExpensesProvider(tripId));
    final currentUser = ref.watch(authProvider).user;

    final trip = tripAsync.valueOrNull;
    final balances = balancesAsync;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Settlement',
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Settle Up'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: trip == null || balances == null
          ? const LoadingIndicator(message: 'Calculating settlements...')
          : TabBarView(
              controller: _tabController,
              children: [
                _SettleUpTab(
                  trip: trip,
                  tripId: tripId,
                  balances: balances,
                  pendingTransactions: pendingTransactions,
                  totalExpenses: totalExpenses,
                  currentUser: currentUser,
                  colorScheme: colorScheme,
                ),
                _HistoryTab(
                  completedSettlements: completedSettlements,
                  colorScheme: colorScheme,
                ),
              ],
            ),
    );
  }
}

class _SettleUpTab extends ConsumerWidget {
  final TripModel trip;
  final String tripId;
  final Map<String, BalanceInfo> balances;
  final List<Settlement> pendingTransactions;
  final double totalExpenses;
  final UserModel? currentUser;
  final ColorScheme colorScheme;

  const _SettleUpTab({
    required this.trip,
    required this.tripId,
    required this.balances,
    required this.pendingTransactions,
    required this.totalExpenses,
    required this.currentUser,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryCards(
          expenseCount:
              ref.watch(tripExpensesProvider(tripId)).valueOrNull?.length ?? 0,
          participantCount: trip.participants.length,
          totalExpenses: totalExpenses,
          settlementCount: pendingTransactions.length,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 28),
        SectionHeader(
          icon: Icons.account_balance_wallet_rounded,
          title: 'Balances',
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 12),
        ...trip.participants.map((uid) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _BalanceCard(
                uid: uid,
                balance: balances[uid],
              ),
            )),
        if (pendingTransactions.isNotEmpty) ...[
          const SizedBox(height: 28),
          SectionHeader(
            icon: Icons.swap_horiz_rounded,
            title: 'Recommended Payments',
            subtitle:
                '${pendingTransactions.length} settlement${pendingTransactions.length == 1 ? '' : 's'} required',
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 12),
          ...pendingTransactions.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SettlementCard(
                  transaction: t,
                  trip: trip,
                  currentUser: currentUser,
                  tripId: tripId,
                ),
              )),
        ],
        if (pendingTransactions.isEmpty && trip.participants.isNotEmpty) ...[
          const SizedBox(height: 48),
          Center(
            child: Column(
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 72, color: Colors.green.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text(
                  'All Settled Up!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No payments needed.',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  final List<SettlementModel> completedSettlements;
  final ColorScheme colorScheme;

  const _HistoryTab({
    required this.completedSettlements,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (completedSettlements.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded,
                size: 72, color: colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'No settlements yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Completed settlements will appear here.',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: completedSettlements.length,
      itemBuilder: (context, index) {
        final settlement = completedSettlements[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _CompletedSettlementCard(
            settlement: settlement,
            colorScheme: colorScheme,
          ),
        );
      },
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final int expenseCount;
  final int participantCount;
  final double totalExpenses;
  final int settlementCount;
  final ColorScheme colorScheme;

  const _SummaryCards({
    required this.expenseCount,
    required this.participantCount,
    required this.totalExpenses,
    required this.settlementCount,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: _SummaryItem(
                icon: Icons.receipt_rounded,
                iconColor: colorScheme.primary,
                label: 'Expenses',
                value: '$expenseCount',
              ),
            ),
            _VerticalDivider(colorScheme: colorScheme),
            Expanded(
              child: _SummaryItem(
                icon: Icons.people_rounded,
                iconColor: colorScheme.tertiary,
                label: 'Participants',
                value: '$participantCount',
              ),
            ),
            _VerticalDivider(colorScheme: colorScheme),
            Expanded(
              child: _SummaryItem(
                icon: Icons.swap_horiz_rounded,
                iconColor: colorScheme.secondary,
                label: 'Settlements',
                value: '$settlementCount',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _SummaryItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  final ColorScheme colorScheme;

  const _VerticalDivider({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 60,
      color: colorScheme.outlineVariant,
    );
  }
}

class SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final ColorScheme colorScheme;

  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.onSurface),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _BalanceCard extends ConsumerWidget {
  final String uid;
  final BalanceInfo? balance;

  const _BalanceCard({
    required this.uid,
    required this.balance,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final nameAsync = ref.watch(userNameProvider(uid));
    final name = nameAsync.valueOrNull ?? uid;
    final bal = balance;

    if (bal == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.surfaceContainerHighest,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                ),
              ),
              const SizedBox(width: 12),
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('No data',
                  style: TextStyle(color: colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    final Color netColor;
    final String netLabel;
    final String netSign;
    if (bal.isCreditor) {
      netColor = Colors.green;
      netLabel = 'To receive';
      netSign = '+';
    } else if (bal.isDebtor) {
      netColor = Colors.red;
      netLabel = 'To pay';
      netSign = '';
    } else {
      netColor = Colors.grey;
      netLabel = 'Settled';
      netSign = '';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: netColor.withValues(alpha: 0.15),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: netColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        netLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: netColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$netSign${CurrencyFormatter.format(bal.netBalance.abs())}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: netColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _LabeledAmount(
                    label: 'Paid',
                    amount: bal.totalPaid,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _LabeledAmount(
                    label: 'Owed',
                    amount: bal.totalOwed,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledAmount extends StatelessWidget {
  final String label;
  final double amount;

  const _LabeledAmount({
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            CurrencyFormatter.format(amount),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettlementCard extends ConsumerWidget {
  final Settlement transaction;
  final TripModel trip;
  final UserModel? currentUser;
  final String tripId;

  const _SettlementCard({
    required this.transaction,
    required this.trip,
    required this.currentUser,
    required this.tripId,
  });

  bool get _canSettle {
    if (currentUser == null) return false;
    return currentUser!.uid == transaction.fromUserId ||
        trip.isAdmin(currentUser!.uid);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final fromNameAsync = ref.watch(userNameProvider(transaction.fromUserId));
    final toNameAsync = ref.watch(userNameProvider(transaction.toUserId));
    final fromName = fromNameAsync.valueOrNull ?? transaction.fromUserId;
    final toName = toNameAsync.valueOrNull ?? transaction.toUserId;
    final settlementState = ref.watch(settlementProvider);
    final isLoading = settlementState.isLoading;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.red.shade50,
                  child: Text(
                    fromName.isNotEmpty ? fromName[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.arrow_forward_rounded, size: 20),
                ),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.green.shade50,
                  child: Text(
                    toName.isNotEmpty ? toName[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fromName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'pays',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        CurrencyFormatter.format(transaction.amount),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'to $toName',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (_canSettle)
                  FilledButton.tonalIcon(
                    onPressed: isLoading
                        ? null
                        : () => _markSettled(context, ref),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Mark Settled'),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Pending',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markSettled(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Mark as Settled',
      message:
          'Confirm that ${transaction.fromUserId} has paid ${CurrencyFormatter.format(transaction.amount)} to ${transaction.toUserId}?',
      confirmLabel: 'Mark Settled',
      icon: Icons.check_circle_rounded,
      confirmColor: Colors.green,
    );

    if (confirmed != true) return;

    final notifier = ref.read(settlementProvider.notifier);
    final result = await notifier.completeSettlement(
      tripId: tripId,
      fromUser: transaction.fromUserId,
      toUser: transaction.toUserId,
      amount: transaction.amount,
      completedBy: currentUser!.uid,
    );

    if (result != null && context.mounted) {
      ref.read(activityServiceProvider).logActivity(
        tripId: tripId,
        userId: currentUser!.uid,
        userName: currentUser!.name,
        actionType: 'settlement_completed',
        message:
            'completed a settlement of ${CurrencyFormatter.format(transaction.amount)}',
      );
      SnackbarHelper.showSuccess(context, 'Settlement marked as completed!');
    } else if (context.mounted) {
      SnackbarHelper.showError(context, 'Failed to mark settlement.');
    }
  }
}

class _CompletedSettlementCard extends ConsumerWidget {
  final SettlementModel settlement;
  final ColorScheme colorScheme;

  const _CompletedSettlementCard({
    required this.settlement,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fromNameAsync = ref.watch(userNameProvider(settlement.fromUser));
    final toNameAsync = ref.watch(userNameProvider(settlement.toUser));
    final completedByNameAsync =
        ref.watch(userNameProvider(settlement.completedBy ?? ''));
    final fromName = fromNameAsync.valueOrNull ?? settlement.fromUser;
    final toName = toNameAsync.valueOrNull ?? settlement.toUser;
    final completedByName =
        completedByNameAsync.valueOrNull ?? settlement.completedBy ?? 'Unknown';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.green.shade50,
                  child: Icon(Icons.check_rounded,
                      color: Colors.green.shade700, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settled',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      if (settlement.completedAt != null)
                        Text(
                          DateFormatter.formatDateTime(settlement.completedAt!),
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  CurrencyFormatter.format(settlement.amount),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.red.shade50,
                          child: Text(
                            fromName.isNotEmpty
                                ? fromName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fromName,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.arrow_forward_rounded,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.green.shade50,
                          child: Text(
                            toName.isNotEmpty
                                ? toName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            toName,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_rounded,
                    size: 14, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  'Marked by $completedByName',
                  style: TextStyle(
                      fontSize: 11, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
