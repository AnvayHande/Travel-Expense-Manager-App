import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/repositories/expense_repository.dart';
import '../../core/services/import_service.dart';
import '../../core/repositories/category_repository.dart';
import 'category_provider.dart';

class ImportPreview {
  final List<ImportRow> rows;
  final int totalRows;
  final int validRows;
  final int invalidRows;
  final int duplicateCount;

  const ImportPreview({
    required this.rows,
    required this.totalRows,
    required this.validRows,
    required this.invalidRows,
    required this.duplicateCount,
  });
}

enum ImportStatus { idle, parsing, preview, importing, summary, error }

class ImportProviderState {
  final ImportStatus status;
  final String? error;
  final ImportPreview? preview;
  final ImportSummary? summary;
  final double progress;

  const ImportProviderState({
    this.status = ImportStatus.idle,
    this.error,
    this.preview,
    this.summary,
    this.progress = 0.0,
  });

  ImportProviderState copyWith({
    ImportStatus? status,
    String? error,
    ImportPreview? preview,
    ImportSummary? summary,
    double? progress,
  }) {
    return ImportProviderState(
      status: status ?? this.status,
      error: error,
      preview: preview ?? this.preview,
      summary: summary ?? this.summary,
      progress: progress ?? this.progress,
    );
  }
}

class ImportNotifier extends StateNotifier<ImportProviderState> {
  final ExpenseRepository _expenseRepository;
  final CategoryRepository _categoryRepository;
  final ImportService _importService;

  ImportNotifier({
    required ExpenseRepository expenseRepository,
    required CategoryRepository categoryRepository,
    required ImportService importService,
  })  : _expenseRepository = expenseRepository,
        _categoryRepository = categoryRepository,
        _importService = importService,
        super(const ImportProviderState());

  void reset() {
    state = const ImportProviderState();
  }

  Future<void> parseFile({
    required String filePath,
    required String tripId,
  }) async {
    state = state.copyWith(status: ImportStatus.parsing, error: null);
    try {
      final categories = await _categoryRepository.getTripCategories(tripId).first;
      final validCategoryNames = categories.map((c) => c.name).toList();
      if (validCategoryNames.isEmpty) {
        validCategoryNames.addAll([
          'Food', 'Transport', 'Accommodation', 'Shopping', 'Entertainment', 'Other',
        ]);
      }

      final rows = _importService.parseRows(
        filePath: filePath,
        validCategories: validCategoryNames,
      );

      if (rows.isEmpty) {
        state = state.copyWith(
          status: ImportStatus.error,
          error: 'No valid rows found in the file.',
        );
        return;
      }

      final expensesAsync = await _expenseRepository.getTripExpenses(tripId).first;
      final rowsWithDuplicates = _importService.markDuplicates(
        rows: rows,
        existingExpenses: expensesAsync,
      );

      final totalRows = rowsWithDuplicates.length;
      final validRows = rowsWithDuplicates.where((r) => r.isValid).length;
      final invalidRows = rowsWithDuplicates.where((r) => !r.isValid).length;
      final duplicateCount = rowsWithDuplicates.where((r) => r.isDuplicate).length;

      state = state.copyWith(
        status: ImportStatus.preview,
        preview: ImportPreview(
          rows: rowsWithDuplicates,
          totalRows: totalRows,
          validRows: validRows,
          invalidRows: invalidRows,
          duplicateCount: duplicateCount,
        ),
      );
    } catch (e) {
      state = state.copyWith(
        status: ImportStatus.error,
        error: 'Failed to parse file: ${e.toString()}',
      );
    }
  }

  Future<void> importAll({
    required String tripId,
    required Map<String, String> participantNameToId,
  }) async {
    final preview = state.preview;
    if (preview == null) return;

    await _importRows(
      rows: preview.rows.where((r) => r.isValid && !r.isDuplicate).toList(),
      tripId: tripId,
      participantNameToId: participantNameToId,
    );
  }

  Future<void> importSelected({
    required List<String> expenseNames,
    required String tripId,
    required Map<String, String> participantNameToId,
  }) async {
    final preview = state.preview;
    if (preview == null) return;

    final selectedNames = expenseNames.toSet();
    final rows = preview.rows.where((r) {
      return r.isValid && !r.isDuplicate && selectedNames.contains(r.expenseName);
    }).toList();

    await _importRows(
      rows: rows,
      tripId: tripId,
      participantNameToId: participantNameToId,
    );
  }

  Future<void> _importRows({
    required List<ImportRow> rows,
    required String tripId,
    required Map<String, String> participantNameToId,
  }) async {
    state = state.copyWith(status: ImportStatus.importing, progress: 0.0);

    try {
      int imported = 0;
      int failed = 0;
      final skipped = state.preview?.invalidRows ?? 0;
      final duplicates = state.preview?.duplicateCount ?? 0;

      final expenses = await _importService.createExpenses(
        rows: rows,
        tripId: tripId,
        participantNameToId: participantNameToId,
      );

      for (var i = 0; i < expenses.length; i++) {
        try {
          await _expenseRepository.addExpense(expenses[i]);
          imported++;
        } catch (e) {
          failed++;
        }
        state = state.copyWith(
          progress: (i + 1) / expenses.length,
        );
      }

      state = state.copyWith(
        status: ImportStatus.summary,
        summary: ImportSummary(
          imported: imported,
          failed: failed,
          duplicates: duplicates,
          skipped: skipped,
        ),
        progress: 1.0,
      );
    } catch (e) {
      state = state.copyWith(
        status: ImportStatus.error,
        error: 'Import failed: ${e.toString()}',
      );
    }
  }
}

final importProvider = StateNotifierProvider<ImportNotifier, ImportProviderState>((ref) {
  final expenseRepository = ref.watch(expenseRepositoryProvider);
  final categoryRepository = ref.watch(categoryRepositoryProvider);
  final importService = ImportService();
  return ImportNotifier(
    expenseRepository: expenseRepository,
    categoryRepository: categoryRepository,
    importService: importService,
  );
});
