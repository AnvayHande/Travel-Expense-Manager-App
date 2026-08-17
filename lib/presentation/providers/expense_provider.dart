import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/expense_model.dart';
import '../../core/models/split_detail.dart';
import '../../core/repositories/expense_repository.dart';

final tripExpensesProvider =
    StreamProvider.family<List<ExpenseModel>, String>((ref, tripId) {
  final repository = ref.watch(expenseRepositoryProvider);
  return repository.getTripExpenses(tripId);
});

class ExpenseState {
  final bool isLoading;
  final String? error;

  const ExpenseState({
    this.isLoading = false,
    this.error,
  });

  ExpenseState copyWith({
    bool? isLoading,
    String? error,
  }) {
    return ExpenseState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ExpenseNotifier extends StateNotifier<ExpenseState> {
  final ExpenseRepository _expenseRepository;

  ExpenseNotifier(this._expenseRepository) : super(const ExpenseState());

  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<ExpenseModel?> addExpense({
    required String tripId,
    required String expenseName,
    String? description,
    required double amount,
    required String paidBy,
    String splitType = 'equal',
    List<SplitDetail> splitDetails = const [],
    required String category,
    DateTime? createdAt,
    String? notes,
    String? receiptUrl,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final expense = ExpenseModel(
        expenseId: const Uuid().v4(),
        tripId: tripId,
        expenseName: expenseName,
        description: description,
        amount: amount,
        paidBy: paidBy,
        splitType: splitType,
        splitDetails: splitDetails,
        category: category,
        createdAt: createdAt ?? DateTime.now(),
        notes: notes,
        receiptUrl: receiptUrl,
      );
      await _expenseRepository.addExpense(expense);
      state = state.copyWith(isLoading: false);
      return expense;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<bool> updateExpense(ExpenseModel expense) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _expenseRepository.updateExpense(expense);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> deleteExpense(String expenseId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _expenseRepository.deleteExpense(expenseId);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final expenseProvider =
    StateNotifierProvider<ExpenseNotifier, ExpenseState>((ref) {
  final repository = ref.watch(expenseRepositoryProvider);
  return ExpenseNotifier(repository);
});
