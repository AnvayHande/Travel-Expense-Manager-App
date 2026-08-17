import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/expense_model.dart';
import '../../core/models/category_model.dart';
import '../../core/services/ledger_service.dart';
import '../../core/utils/file_helper.dart';
import 'expense_provider.dart';
import 'firebase_providers.dart';
import 'settlement_provider.dart';
final ledgerServiceProvider = Provider<LedgerService>((ref) {
  return LedgerService();
});

final participantLedgerProvider =
    Provider.family<ParticipantLedger?, String>((ref, tripId) {
  return null;
});

final participantLedgerProvider2 = Provider.family<ParticipantLedger?, Map<String, String>>((ref, params) {
  final tripId = params['tripId'] ?? '';
  final userId = params['userId'] ?? '';

  final expensesAsync = ref.watch(tripExpensesProvider(tripId));
  final expenses = expensesAsync.valueOrNull ?? [];
  final balances = ref.watch(tripBalanceProvider(tripId));
  final nameAsync = ref.watch(userNameProvider(userId));

  final userName = nameAsync.valueOrNull ?? userId;

  if (balances == null) return null;

  final service = ref.watch(ledgerServiceProvider);
  return service.computeLedger(
    userId: userId,
    userName: userName,
    allExpenses: expenses,
    balances: balances,
  );
});

class LedgerExportState {
  final bool isLoading;
  final String? filePath;
  final String? error;

  const LedgerExportState({
    this.isLoading = false,
    this.filePath,
    this.error,
  });

  LedgerExportState copyWith({
    bool? isLoading,
    String? filePath,
    String? error,
  }) {
    return LedgerExportState(
      isLoading: isLoading ?? this.isLoading,
      filePath: filePath ?? this.filePath,
      error: error,
    );
  }
}

class LedgerExportNotifier extends StateNotifier<LedgerExportState> {
  final LedgerService _ledgerService;

  LedgerExportNotifier(this._ledgerService) : super(const LedgerExportState());

  void clearState() {
    state = const LedgerExportState();
  }

  Future<String?> exportLedgerPdf({
    required ParticipantLedger ledger,
    required List<LedgerEntry> filteredEntries,
    required String tripName,
    required Map<String, CategoryModel> catInfo,
    String? categoryFilter,
  }) async {
    state = state.copyWith(isLoading: true, error: null, filePath: null);

    try {
      final bytes = await _ledgerService.generateLedgerPdf(
        ledger: ledger,
        filteredEntries: filteredEntries,
        tripName: tripName,
        catInfo: catInfo,
        currency: '\$',
        categoryFilter: categoryFilter,
      );

      final safeName = ledger.userName.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
      final dateStr = '${DateTime.now().year}-'
          '${DateTime.now().month.toString().padLeft(2, '0')}-'
          '${DateTime.now().day.toString().padLeft(2, '0')}';
      final fileName = '${safeName}_Ledger_$dateStr.pdf';
      final filePath = await FileHelper.saveFile(fileName, bytes, mimeType: 'application/pdf');

      state = state.copyWith(isLoading: false, filePath: filePath);
      return filePath;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }
}

final ledgerExportProvider =
    StateNotifierProvider<LedgerExportNotifier, LedgerExportState>((ref) {
  final service = ref.watch(ledgerServiceProvider);
  return LedgerExportNotifier(service);
});
