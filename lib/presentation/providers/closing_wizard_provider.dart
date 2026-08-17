import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/expense_model.dart';
import '../../core/models/trip_model.dart';
import '../../core/services/trip_closing_service.dart';
import '../../core/repositories/trip_repository.dart';
import '../../core/repositories/settlement_repository.dart';
import 'activity_provider.dart';

enum WizardStep { expenseCheck, settlementCheck, generateReports, archive }

class ClosingWizardState {
  final WizardStep currentStep;
  final bool isLoading;
  final String? error;

  final int expenseCount;
  final double expenseTotal;
  final bool expenseCheckPassed;

  final int pendingSettlementCount;
  final bool settlementCheckPassed;

  final bool archiveComplete;

  const ClosingWizardState({
    this.currentStep = WizardStep.expenseCheck,
    this.isLoading = false,
    this.error,
    this.expenseCount = 0,
    this.expenseTotal = 0,
    this.expenseCheckPassed = false,
    this.pendingSettlementCount = 0,
    this.settlementCheckPassed = false,
    this.archiveComplete = false,
  });

  ClosingWizardState copyWith({
    WizardStep? currentStep,
    bool? isLoading,
    String? error,
    int? expenseCount,
    double? expenseTotal,
    bool? expenseCheckPassed,
    int? pendingSettlementCount,
    bool? settlementCheckPassed,
    bool? archiveComplete,
  }) {
    return ClosingWizardState(
      currentStep: currentStep ?? this.currentStep,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      expenseCount: expenseCount ?? this.expenseCount,
      expenseTotal: expenseTotal ?? this.expenseTotal,
      expenseCheckPassed: expenseCheckPassed ?? this.expenseCheckPassed,
      pendingSettlementCount: pendingSettlementCount ?? this.pendingSettlementCount,
      settlementCheckPassed: settlementCheckPassed ?? this.settlementCheckPassed,
      archiveComplete: archiveComplete ?? this.archiveComplete,
    );
  }
}

class ClosingWizardNotifier extends StateNotifier<ClosingWizardState> {
  final TripClosingService _closingService;

  ClosingWizardNotifier(this._closingService) : super(const ClosingWizardState());

  Future<void> checkExpenses(String tripId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _closingService.checkExpenses(tripId);
      state = state.copyWith(
        isLoading: false,
        expenseCount: result.count,
        expenseTotal: result.totalAmount,
        expenseCheckPassed: !result.isEmpty,
        currentStep: WizardStep.settlementCheck,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> checkSettlements(
    String tripId,
    List<ExpenseModel> expenses,
    TripModel trip,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _closingService.checkSettlements(tripId, expenses, trip);
      state = state.copyWith(
        isLoading: false,
        pendingSettlementCount: result.pendingCount,
        settlementCheckPassed: result.allSettled,
        currentStep: WizardStep.generateReports,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void skipToGenerateReports() {
    state = state.copyWith(currentStep: WizardStep.generateReports);
  }

  Future<void> archiveTrip({
    required String tripId,
    required String tripName,
    required String adminId,
    required String adminName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _closingService.archiveTrip(
        tripId: tripId,
        tripName: tripName,
        adminId: adminId,
        adminName: adminName,
      );
      state = state.copyWith(isLoading: false, archiveComplete: true, currentStep: WizardStep.archive);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() {
    state = const ClosingWizardState();
  }
}

final closingWizardProvider =
    StateNotifierProvider<ClosingWizardNotifier, ClosingWizardState>((ref) {
  final tripRepository = ref.watch(tripRepositoryProvider);
  final settlementRepository = ref.watch(settlementRepositoryProvider);
  final activityService = ref.watch(activityServiceProvider);
  final service = TripClosingService(
    tripRepository: tripRepository,
    settlementRepository: settlementRepository,
    activityService: activityService,
  );
  return ClosingWizardNotifier(service);
});
