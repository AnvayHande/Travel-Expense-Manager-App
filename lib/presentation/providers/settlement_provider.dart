import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/expense_model.dart';
import '../../core/models/settlement_model.dart';
import '../../core/repositories/settlement_repository.dart';
import '../../core/services/settlement_service.dart';
import '../providers/expense_provider.dart';
import '../providers/trip_provider.dart';

final tripSettlementsProvider =
    StreamProvider.family<List<SettlementModel>, String>((ref, tripId) {
  final repository = ref.watch(settlementRepositoryProvider);
  return repository.getTripSettlements(tripId);
});

final tripCompletedSettlementsProvider =
    Provider.family<List<SettlementModel>, String>((ref, tripId) {
  final settlementsAsync = ref.watch(tripSettlementsProvider(tripId));
  final settlements = settlementsAsync.valueOrNull ?? [];
  return settlements.where((s) => s.status == 'completed').toList();
});

Map<String, BalanceInfo> _calculateBalances({
  required List<ExpenseModel> expenses,
  required List<String> participants,
}) {
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

final tripBalanceProvider =
    Provider.family<Map<String, BalanceInfo>?, String>((ref, tripId) {
  final expensesAsync = ref.watch(tripExpensesProvider(tripId));
  final tripAsync = ref.watch(tripByIdProvider(tripId));

  final expenses = expensesAsync.valueOrNull;
  final trip = tripAsync.valueOrNull;

  if (expenses == null || trip == null) return null;

  return _calculateBalances(
    expenses: expenses,
    participants: trip.participants,
  );
});

final tripTransactionsProvider =
    Provider.family<List<Settlement>, String>((ref, tripId) {
  final balances = ref.watch(tripBalanceProvider(tripId));
  if (balances == null) return [];

  final participantBalances = balances.values
      .map((b) => ParticipantBalance(userId: b.userId, netBalance: b.netBalance))
      .toList();

  final service = SettlementService();
  return service.calculateMinimumTransactions(participantBalances);
});

final tripPendingTransactionsProvider =
    Provider.family<List<Settlement>, String>((ref, tripId) {
  final transactions = ref.watch(tripTransactionsProvider(tripId));
  final completedSettlements =
      ref.watch(tripCompletedSettlementsProvider(tripId));

  final completedPairs = completedSettlements
      .map((s) => '${s.fromUser}-${s.toUser}')
      .toSet();

  return transactions
      .where(
          (t) => !completedPairs.contains('${t.fromUserId}-${t.toUserId}'))
      .toList();
});

final tripTotalExpensesProvider = Provider.family<double, String>((ref, tripId) {
  final expensesAsync = ref.watch(tripExpensesProvider(tripId));
  final expenses = expensesAsync.valueOrNull;
  if (expenses == null) return 0.0;
  return expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
});

class SettlementState {
  final bool isLoading;
  final String? error;

  const SettlementState({
    this.isLoading = false,
    this.error,
  });

  SettlementState copyWith({
    bool? isLoading,
    String? error,
  }) {
    return SettlementState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SettlementNotifier extends StateNotifier<SettlementState> {
  final SettlementRepository _settlementRepository;

  SettlementNotifier(this._settlementRepository) : super(const SettlementState());

  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<SettlementModel?> createSettlement({
    required String tripId,
    required String fromUser,
    required String toUser,
    required double amount,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final settlement = SettlementModel(
        settlementId: const Uuid().v4(),
        tripId: tripId,
        fromUser: fromUser,
        toUser: toUser,
        amount: amount,
        createdAt: DateTime.now(),
      );
      await _settlementRepository.createSettlement(settlement);
      state = state.copyWith(isLoading: false);
      return settlement;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<bool> markAsSettled({
    required String settlementId,
    required String completedBy,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _settlementRepository.markAsSettled(settlementId,
          completedBy: completedBy);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<SettlementModel?> completeSettlement({
    required String tripId,
    required String fromUser,
    required String toUser,
    required double amount,
    required String completedBy,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final settlement = SettlementModel(
        settlementId: const Uuid().v4(),
        tripId: tripId,
        fromUser: fromUser,
        toUser: toUser,
        amount: amount,
        status: 'completed',
        completedAt: DateTime.now(),
        completedBy: completedBy,
        createdAt: DateTime.now(),
      );
      await _settlementRepository.createSettlement(settlement);
      state = state.copyWith(isLoading: false);
      return settlement;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }
}

final settlementProvider =
    StateNotifierProvider<SettlementNotifier, SettlementState>((ref) {
  final repository = ref.watch(settlementRepositoryProvider);
  return SettlementNotifier(repository);
});
