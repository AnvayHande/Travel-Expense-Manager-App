import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/models/expense_model.dart';
import '../../core/models/trip_model.dart';
import '../../core/models/category_model.dart';
import '../../core/models/settlement_model.dart';
import '../../core/services/report_service.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/expense_filter_service.dart';
import '../../core/services/settlement_service.dart';
import '../../core/services/budget_service.dart';


final reportServiceProvider = Provider<ReportService>((ref) {
  return ReportService(
    filterService: ExpenseFilterService(),
    analyticsService: AnalyticsService(filterService: ExpenseFilterService()),
  );
});

class ReportState {
  final bool isLoading;
  final String? filePath;
  final String? error;
  final double progress;

  const ReportState({
    this.isLoading = false,
    this.filePath,
    this.error,
    this.progress = 0,
  });

  ReportState copyWith({
    bool? isLoading,
    String? filePath,
    String? error,
    double? progress,
  }) {
    return ReportState(
      isLoading: isLoading ?? this.isLoading,
      filePath: filePath ?? this.filePath,
      error: error,
      progress: progress ?? this.progress,
    );
  }
}

class ReportNotifier extends StateNotifier<ReportState> {
  final ReportService _reportService;

  ReportNotifier(this._reportService) : super(const ReportState());

  void clearState() {
    state = const ReportState();
  }

  Future<String?> generateReport({
    required TripModel trip,
    required List<ExpenseModel> expenses,
    required Map<String, String> participantNames,
    required Map<String, BalanceInfo> balances,
    required List<Settlement> pendingTransactions,
    required List<SettlementModel> completedSettlements,
    required Map<String, CategoryModel> catInfo,
    double totalBudget = 0,
  }) async {
    state = state.copyWith(isLoading: true, error: null, filePath: null, progress: 0.1);

    try {
      final filterService = ExpenseFilterService();
      final analyticsService = AnalyticsService(filterService: filterService);

      final budgetData = _buildBudgetData(catInfo, expenses, totalBudget);

      state = state.copyWith(progress: 0.3);

      final bytes = await _reportService.generateReport(
        trip: trip,
        expenses: expenses,
        participantNames: participantNames,
        balances: balances,
        pendingTransactions: pendingTransactions,
        completedSettlements: completedSettlements,
        budgetData: budgetData,
        catInfo: catInfo,
      );

      state = state.copyWith(progress: 0.8);

      final dir = await getTemporaryDirectory();
      final dateStr = '${DateTime.now().year}-'
          '${DateTime.now().month.toString().padLeft(2, '0')}-'
          '${DateTime.now().day.toString().padLeft(2, '0')}';
      final safeName = trip.tripName.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
      final fileName = '${safeName}_Report_$dateStr.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      state = state.copyWith(isLoading: false, filePath: file.path, progress: 1.0);
      return file.path;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  BudgetData _buildBudgetData(
    Map<String, CategoryModel> catInfo,
    List<ExpenseModel> expenses,
    double totalBudget,
  ) {
    final service = BudgetService();
    return service.calculate(
      categories: catInfo.values.toList(),
      expenses: expenses,
      totalBudget: totalBudget,
    );
  }
}

final reportProvider =
    StateNotifierProvider<ReportNotifier, ReportState>((ref) {
  final service = ref.watch(reportServiceProvider);
  return ReportNotifier(service);
});
