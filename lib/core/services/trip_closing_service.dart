import '../models/expense_model.dart';
import '../models/trip_model.dart';
import '../repositories/trip_repository.dart';
import '../repositories/expense_repository.dart';
import '../repositories/settlement_repository.dart';
import 'activity_service.dart';
import 'settlement_service.dart';

class ExpenseCheckResult {
  final int count;
  final bool isEmpty;
  final double totalAmount;

  const ExpenseCheckResult({
    required this.count,
    required this.isEmpty,
    required this.totalAmount,
  });
}

class SettlementCheckResult {
  final bool allSettled;
  final int pendingCount;
  final List<Settlement> pendingTransactions;
  final Map<String, BalanceInfo> balances;

  const SettlementCheckResult({
    required this.allSettled,
    required this.pendingCount,
    required this.pendingTransactions,
    required this.balances,
  });
}

class TripClosingService {
  final TripRepository _tripRepository;
  final SettlementRepository _settlementRepository;
  final ActivityService _activityService;

  TripClosingService({
    required TripRepository tripRepository,
    required SettlementRepository settlementRepository,
    required ActivityService activityService,
  })  : _tripRepository = tripRepository,
        _settlementRepository = settlementRepository,
        _activityService = activityService;

  Future<ExpenseCheckResult> checkExpenses(String tripId) async {
    final expenses = await _tripRepository.getExpensesForTrip(tripId);
    double total = 0;
    for (final e in expenses) {
      total += e.amount;
    }
    return ExpenseCheckResult(
      count: expenses.length,
      isEmpty: expenses.isEmpty,
      totalAmount: total,
    );
  }

  Map<String, BalanceInfo> computeBalances(
    List<ExpenseModel> expenses,
    List<String> participants,
  ) {
    final paid = <String, double>{};
    final owed = <String, double>{};

    for (final uid in participants) {
      paid[uid] = 0.0;
      owed[uid] = 0.0;
    }

    for (final expense in expenses) {
      paid[expense.paidBy] = (paid[expense.paidBy] ?? 0.0) + expense.amount;
      for (final detail in expense.splitDetails) {
        owed[detail.userId] =
            (owed[detail.userId] ?? 0.0) + expense.splitAmountForUser(detail.userId);
      }
    }

    final balances = <String, BalanceInfo>{};
    for (final uid in participants) {
      final tp = paid[uid] ?? 0.0;
      final to = owed[uid] ?? 0.0;
      balances[uid] = BalanceInfo(
        userId: uid,
        totalPaid: tp,
        totalOwed: to,
        netBalance: tp - to,
      );
    }

    return balances;
  }

  Future<SettlementCheckResult> checkSettlements(
    String tripId,
    List<ExpenseModel> expenses,
    TripModel trip,
  ) async {
    final settlementsAsync = _settlementRepository.getTripSettlements(tripId);
    final settlements = await settlementsAsync.first;
    final completedSettlements =
        settlements.where((s) => s.isSettled).toList();

    final balances = computeBalances(expenses, trip.participants);

    final participantBalances = balances.values
        .map((b) => ParticipantBalance(userId: b.userId, netBalance: b.netBalance))
        .toList();

    final service = SettlementService();
    final allTransactions = service.calculateMinimumTransactions(participantBalances);

    final completedPairs = completedSettlements
        .map((s) => '${s.fromUser}-${s.toUser}')
        .toSet();

    final pendingTransactions = allTransactions
        .where((t) => !completedPairs.contains('${t.fromUserId}-${t.toUserId}'))
        .toList();

    final allSettled = balances.values.every((b) => b.isSettled) && pendingTransactions.isEmpty;

    return SettlementCheckResult(
      allSettled: allSettled,
      pendingCount: pendingTransactions.length,
      pendingTransactions: pendingTransactions,
      balances: balances,
    );
  }

  Future<void> archiveTrip({
    required String tripId,
    required String tripName,
    required String adminId,
    required String adminName,
  }) async {
    await _tripRepository.updateTripStatus(tripId, 'completed');
    await _activityService.logActivity(
      tripId: tripId,
      userId: adminId,
      userName: adminName,
      actionType: 'trip_closed',
      message: 'closed the trip "$tripName"',
    );
  }
}
