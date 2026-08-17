import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import '../models/expense_model.dart';

class ExportService {
  Future<String> exportTripExpenses({
    required String tripName,
    required List<ExpenseModel> expenses,
    required List<String> participants,
    required Map<String, String> participantNames,
    required DateTime date,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Expenses'];

    final sortedExpenses = List<ExpenseModel>.from(expenses)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    const nameCol = 0;
    const paidByCol = 1;
    const amountCol = 2;
    final participantColOffset = 3;

    _setCell(sheet, nameCol, 0, 'Expense Name');
    _setCell(sheet, paidByCol, 0, 'Paid By');
    _setCell(sheet, amountCol, 0, 'Total Amount');

    for (var i = 0; i < participants.length; i++) {
      _setCell(
        sheet,
        participantColOffset + i,
        0,
        participantNames[participants[i]] ?? participants[i],
      );
    }

    for (var row = 0; row < sortedExpenses.length; row++) {
      final expense = sortedExpenses[row];
      final excelRow = row + 1;

      _setCell(sheet, nameCol, excelRow, expense.expenseName);
      _setCell(
          sheet, paidByCol, excelRow,
          participantNames[expense.paidBy] ?? expense.paidBy);
      _setCell(sheet, amountCol, excelRow, expense.amount);

      for (var i = 0; i < participants.length; i++) {
        if (expense.splitBetween.contains(participants[i])) {
          _setCell(sheet, participantColOffset + i, excelRow,
              expense.splitAmountForUser(participants[i]));
        }
      }
    }

    final totalsRow = sortedExpenses.length + 1;
    _setCell(sheet, nameCol, totalsRow, 'Total Owed');

    for (var i = 0; i < participants.length; i++) {
      double total = 0;
      for (final expense in sortedExpenses) {
        if (expense.splitBetween.contains(participants[i])) {
          total += expense.splitAmountForUser(participants[i]);
        }
      }
      _setCell(sheet, participantColOffset + i, totalsRow, total);
    }

    final paidRow = sortedExpenses.length + 2;
    _setCell(sheet, nameCol, paidRow, 'Total Paid');

    final paidMap = <String, double>{};
    for (final expense in sortedExpenses) {
      paidMap[expense.paidBy] =
          (paidMap[expense.paidBy] ?? 0) + expense.amount;
    }
    for (var i = 0; i < participants.length; i++) {
      _setCell(sheet, participantColOffset + i, paidRow,
          paidMap[participants[i]] ?? 0);
    }

    final netRow = sortedExpenses.length + 3;
    _setCell(sheet, nameCol, netRow, 'Net Balance');

    for (var i = 0; i < participants.length; i++) {
      double paid = paidMap[participants[i]] ?? 0;
      double owed = 0;
      for (final expense in sortedExpenses) {
        if (expense.splitBetween.contains(participants[i])) {
          owed += expense.splitAmountForUser(participants[i]);
        }
      }
      _setCell(sheet, participantColOffset + i, netRow, paid - owed);
    }

    final fileName =
        '${tripName.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_')}_'
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}.xlsx';

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    final bytes = excel.encode();
    if (bytes == null) throw Exception('Failed to encode Excel file');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  void _setCell(Sheet sheet, int col, int row, dynamic value) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(
        columnIndex: col, rowIndex: row));
    if (value is num) {
      cell.value = DoubleCellValue(value.toDouble());
    } else {
      cell.value = TextCellValue(value?.toString() ?? '');
    }
  }
}
