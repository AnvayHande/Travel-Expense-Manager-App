import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/draft_expense_service.dart';

class DraftExpenseState {
  final bool isLoading;
  final bool hasDraft;
  final Map<String, dynamic>? draftData;
  final String? error;

  const DraftExpenseState({
    this.isLoading = false,
    this.hasDraft = false,
    this.draftData,
    this.error,
  });

  DraftExpenseState copyWith({
    bool? isLoading,
    bool? hasDraft,
    Map<String, dynamic>? draftData,
    String? error,
  }) {
    return DraftExpenseState(
      isLoading: isLoading ?? this.isLoading,
      hasDraft: hasDraft ?? this.hasDraft,
      draftData: draftData ?? this.draftData,
      error: error,
    );
  }
}

class DraftExpenseNotifier extends StateNotifier<DraftExpenseState> {
  final DraftExpenseService _service;

  DraftExpenseNotifier(this._service) : super(const DraftExpenseState());

  Future<void> checkForDraft(String tripId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final draftData = await _service.loadDraft(tripId);
      state = state.copyWith(
        isLoading: false,
        hasDraft: draftData != null,
        draftData: draftData,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> saveDraft({
    required String tripId,
    String? expenseName,
    String? amount,
    String? category,
    String? paidBy,
    String? splitType,
    List<String>? splitBetween,
    Map<String, String>? splitValues,
    String? notes,
    int? dateMillis,
  }) async {
    try {
      await _service.saveDraft(
        tripId: tripId,
        expenseName: expenseName,
        amount: amount,
        category: category,
        paidBy: paidBy,
        splitType: splitType,
        splitBetween: splitBetween,
        splitValues: splitValues,
        notes: notes,
        dateMillis: dateMillis,
      );
    } catch (_) {}
  }

  Future<void> discardDraft(String tripId) async {
    try {
      await _service.deleteDraft(tripId);
      state = const DraftExpenseState();
    } catch (_) {}
  }

  Future<void> deleteDraft(String tripId) async {
    try {
      await _service.deleteDraft(tripId);
    } catch (_) {}
  }
}

final draftExpenseServiceProvider = Provider<DraftExpenseService>((ref) {
  return DraftExpenseService();
});

final draftExpenseProvider =
    StateNotifierProvider<DraftExpenseNotifier, DraftExpenseState>((ref) {
  final service = ref.watch(draftExpenseServiceProvider);
  return DraftExpenseNotifier(service);
});
