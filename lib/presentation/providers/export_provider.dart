import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/expense_model.dart';
import '../../core/services/export_service.dart';

class ExportState {
  final bool isLoading;
  final String? filePath;
  final String? error;

  const ExportState({
    this.isLoading = false,
    this.filePath,
    this.error,
  });

  ExportState copyWith({
    bool? isLoading,
    String? filePath,
    String? error,
  }) {
    return ExportState(
      isLoading: isLoading ?? this.isLoading,
      filePath: filePath ?? this.filePath,
      error: error,
    );
  }
}

class ExportNotifier extends StateNotifier<ExportState> {
  final ExportService _exportService;

  ExportNotifier(this._exportService) : super(const ExportState());

  void clearState() {
    state = const ExportState();
  }

  Future<String?> exportTrip({
    required String tripId,
    required String tripName,
    required List<ExpenseModel> expenses,
    required List<String> participants,
    required Map<String, String> participantNames,
    required DateTime date,
  }) async {
    state = state.copyWith(isLoading: true, error: null, filePath: null);
    try {
      final path = await _exportService.exportTripExpenses(
        tripName: tripName,
        expenses: expenses,
        participants: participants,
        participantNames: participantNames,
        date: date,
      );
      state = state.copyWith(isLoading: false, filePath: path);
      return path;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }
}

final exportProvider =
    StateNotifierProvider<ExportNotifier, ExportState>((ref) {
  return ExportNotifier(ExportService());
});
