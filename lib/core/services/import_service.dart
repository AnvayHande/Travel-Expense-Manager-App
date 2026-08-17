import 'dart:io';
import 'package:excel/excel.dart';
import 'package:uuid/uuid.dart';
import '../models/expense_model.dart';
import '../models/split_detail.dart';

class ImportRow {
  final int rowNumber;
  final String? expenseName;
  final String? category;
  final double? amount;
  final String? paidByName;
  final String? splitType;
  final String? participantsStr;
  final DateTime? date;
  final String? notes;
  final String? validationError;
  final bool isDuplicate;

  const ImportRow({
    required this.rowNumber,
    this.expenseName,
    this.category,
    this.amount,
    this.paidByName,
    this.splitType,
    this.participantsStr,
    this.date,
    this.notes,
    this.validationError,
    this.isDuplicate = false,
  });

  bool get isValid => validationError == null;
}

class ImportSummary {
  final int imported;
  final int failed;
  final int duplicates;
  final int skipped;

  const ImportSummary({
    required this.imported,
    required this.failed,
    required this.duplicates,
    required this.skipped,
  });
}

class ImportService {
  List<ImportRow> parseRows({
    required String filePath,
    required List<String> validCategories,
  }) {
    final file = File(filePath);
    final bytes = file.readAsBytesSync();
    final excel = Excel.decodeBytes(bytes);

    final rows = <ImportRow>[];

    for (final table in excel.tables.keys) {
      final sheet = excel.tables[table]!;
      if (sheet.rows.isEmpty) continue;

      final headerRow = sheet.rows[0];
      final colMap = _buildColumnMap(headerRow);
      if (colMap == null) continue;

      for (var i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        final rowNumber = i + 1;

        final expenseName = _cellString(row, colMap['expensename']);
        final category = _cellString(row, colMap['category']);
        final amount = _cellDouble(row, colMap['amount']);
        final paidByName = _cellString(row, colMap['paidby']);
        final splitType = _cellString(row, colMap['splittype']);
        final participantsStr = _cellString(row, colMap['participants']);
        final dateStr = _cellString(row, colMap['date']);
        final notes = _cellString(row, colMap['notes']);

        String? error;

        if (expenseName == null || expenseName.trim().isEmpty) {
          error = 'Missing expense name';
        } else if (amount == null || amount <= 0) {
          error = 'Invalid or missing amount';
        } else if (paidByName == null || paidByName.trim().isEmpty) {
          error = 'Missing paid by';
        } else if (category != null && category.trim().isNotEmpty && !validCategories.contains(category.trim())) {
          error = 'Unknown category "$category"';
        }

        DateTime? parsedDate;
        if (dateStr != null && dateStr.trim().isNotEmpty) {
          parsedDate = _parseDate(dateStr.trim());
        }

        rows.add(ImportRow(
          rowNumber: rowNumber,
          expenseName: expenseName?.trim(),
          category: category?.trim(),
          amount: amount,
          paidByName: paidByName?.trim(),
          splitType: splitType?.trim().toLowerCase(),
          participantsStr: participantsStr?.trim(),
          date: parsedDate,
          notes: notes?.trim(),
          validationError: error,
        ));
      }
    }

    return rows;
  }

  List<ImportRow> markDuplicates({
    required List<ImportRow> rows,
    required List<ExpenseModel> existingExpenses,
  }) {
    return rows.map((row) {
      if (!row.isValid) return row;

      final isDup = existingExpenses.any((e) {
        final nameMatch = e.expenseName.toLowerCase() == (row.expenseName ?? '').toLowerCase();
        final amountMatch = (e.amount - (row.amount ?? 0)).abs() < 0.01;
        final dateMatch = row.date == null || e.createdAt.day == row.date!.day &&
            e.createdAt.month == row.date!.month &&
            e.createdAt.year == row.date!.year;
        return nameMatch && amountMatch && dateMatch;
      });

      return ImportRow(
        rowNumber: row.rowNumber,
        expenseName: row.expenseName,
        category: row.category,
        amount: row.amount,
        paidByName: row.paidByName,
        splitType: row.splitType,
        participantsStr: row.participantsStr,
        date: row.date,
        notes: row.notes,
        validationError: row.validationError,
        isDuplicate: isDup,
      );
    }).toList();
  }

  Future<List<ExpenseModel>> createExpenses({
    required List<ImportRow> rows,
    required String tripId,
    required Map<String, String> participantNameToId,
  }) async {
    final expenses = <ExpenseModel>[];
    final uuid = const Uuid();

    for (final row in rows) {
      if (!row.isValid || row.isDuplicate) continue;

      final paidById = participantNameToId[row.paidByName ?? ''];
      if (paidById == null) continue;

      final splitDetails = _buildSplitDetails(
        splitType: row.splitType ?? 'equal',
        participantsStr: row.participantsStr,
        participantNameToId: participantNameToId,
        amount: row.amount ?? 0,
        paidById: paidById,
      );

      final expense = ExpenseModel(
        expenseId: uuid.v4(),
        tripId: tripId,
        expenseName: row.expenseName ?? '',
        amount: row.amount ?? 0,
        paidBy: paidById,
        splitType: row.splitType?.toLowerCase() ?? 'equal',
        splitDetails: splitDetails,
        category: row.category ?? 'Other',
        createdAt: row.date ?? DateTime.now(),
        notes: row.notes,
      );

      expenses.add(expense);
    }

    return expenses;
  }

  List<SplitDetail> _buildSplitDetails({
    required String splitType,
    required String? participantsStr,
    required Map<String, String> participantNameToId,
    required double amount,
    required String paidById,
  }) {
    if (splitType == 'paidOnly') {
      return [SplitDetail(userId: paidById)];
    }

    if (participantsStr == null || participantsStr.trim().isEmpty) {
      return [SplitDetail(userId: paidById)];
    }

    final names = participantsStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final userIds = names.map((n) => participantNameToId[n]).whereType<String>().toList();

    if (userIds.isEmpty) {
      return [SplitDetail(userId: paidById)];
    }

    switch (splitType) {
      case 'exact':
        return _buildExactSplit(userIds, participantsStr, participantNameToId, paidById);
      case 'percentage':
        return _buildPercentageSplit(userIds, participantsStr, participantNameToId);
      case 'shares':
        return _buildSharesSplit(userIds, participantsStr, participantNameToId);
      case 'equal':
      default:
        return userIds.map((uid) => SplitDetail(userId: uid)).toList();
    }
  }

  List<SplitDetail> _buildExactSplit(
    List<String> userIds,
    String participantsStr,
    Map<String, String> participantNameToId,
    String paidById,
  ) {
    final result = <SplitDetail>[];
    final parts = participantsStr.split(',').map((s) => s.trim()).toList();
    for (final part in parts) {
      final match = RegExp(r'^(.+?)\s*[=:]\s*(\d+(?:\.\d+)?)$').firstMatch(part);
      if (match != null) {
        final name = match.group(1)?.trim() ?? '';
        final amtStr = match.group(2);
        final amt = amtStr != null ? double.tryParse(amtStr) : null;
        final uid = participantNameToId[name];
        if (uid != null && amt != null) {
          result.add(SplitDetail(userId: uid, amount: amt));
        }
      }
    }
    if (result.isEmpty) {
      return userIds.map((uid) => SplitDetail(userId: uid)).toList();
    }
    return result;
  }

  List<SplitDetail> _buildPercentageSplit(
    List<String> userIds,
    String participantsStr,
    Map<String, String> participantNameToId,
  ) {
    final result = <SplitDetail>[];
    final parts = participantsStr.split(',').map((s) => s.trim()).toList();
    for (final part in parts) {
      final match = RegExp(r'^(.+?)\s*[=:]\s*(\d+(?:\.\d+)?)%$').firstMatch(part);
      if (match != null) {
        final name = match.group(1)?.trim() ?? '';
        final pctStr = match.group(2);
        final pct = pctStr != null ? double.tryParse(pctStr) : null;
        final uid = participantNameToId[name];
        if (uid != null && pct != null) {
          result.add(SplitDetail(userId: uid, percentage: pct));
        }
      }
    }
    if (result.isEmpty) {
      return userIds.map((uid) => SplitDetail(userId: uid)).toList();
    }
    return result;
  }

  List<SplitDetail> _buildSharesSplit(
    List<String> userIds,
    String participantsStr,
    Map<String, String> participantNameToId,
  ) {
    final result = <SplitDetail>[];
    final parts = participantsStr.split(',').map((s) => s.trim()).toList();
    for (final part in parts) {
      final match = RegExp(r'^(.+?)\s*[=:]\s*(\d+)$').firstMatch(part);
      if (match != null) {
        final name = match.group(1)?.trim() ?? '';
        final sharesStr = match.group(2);
        final shares = sharesStr != null ? int.tryParse(sharesStr) : null;
        final uid = participantNameToId[name];
        if (uid != null && shares != null) {
          result.add(SplitDetail(userId: uid, shares: shares));
        }
      }
    }
    if (result.isEmpty) {
      return userIds.map((uid) => SplitDetail(userId: uid)).toList();
    }
    return result;
  }

  Map<String, int>? _buildColumnMap(List<Data?> headerRow) {
    final map = <String, int>{};
    for (var i = 0; i < headerRow.length; i++) {
      final cell = headerRow[i];
      if (cell == null) continue;
      final text = cell.value?.toString().toLowerCase().replaceAll(RegExp(r'\s+'), '') ?? '';
      if (text.isNotEmpty) {
        map[text] = i;
      }
    }

    if (!map.containsKey('expensename') || !map.containsKey('amount')) {
      return null;
    }

    return map;
  }

  String? _cellString(List<Data?> row, int? col) {
    if (col == null || col >= row.length) return null;
    final cell = row[col];
    if (cell == null) return null;
    final value = cell.value;
    if (value == null) return null;
    return value.toString();
  }

  double? _cellDouble(List<Data?> row, int? col) {
    if (col == null || col >= row.length) return null;
    final cell = row[col];
    if (cell == null) return null;
    final value = cell.value;
    if (value == null) return null;
    if (value is DoubleCellValue) return value.value;
    if (value is IntCellValue) return value.value.toDouble();
    if (value is TextCellValue) {
      return double.tryParse(value.value.toString().trim());
    }
    return double.tryParse(value.toString().trim());
  }

  DateTime? _parseDate(String dateStr) {
    dateStr = dateStr.trim();
    final formats = [
      r'^(\d{4})-(\d{1,2})-(\d{1,2})$',
      r'^(\d{1,2})/(\d{1,2})/(\d{4})$',
      r'^(\d{1,2})-(\d{1,2})-(\d{4})$',
      r'^(\d{4})/(\d{1,2})/(\d{1,2})$',
      r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$',
    ];

    for (final pattern in formats) {
      final match = RegExp(pattern).firstMatch(dateStr);
      if (match != null) {
        try {
          final parts = match.groups([1, 2, 3]).map((s) => int.parse(s!)).toList();
          if (pattern.startsWith(r'^(\d{4})')) {
            return DateTime(parts[0], parts[1], parts[2]);
          } else if (pattern.contains('/') || pattern.contains('-')) {
            return DateTime(parts[2], parts[1], parts[0]);
          }
          return DateTime(parts[2], parts[1], parts[0]);
        } catch (_) {}
      }
    }

    return null;
  }
}
