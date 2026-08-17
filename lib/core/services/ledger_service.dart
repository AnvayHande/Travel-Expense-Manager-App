import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/expense_model.dart';
import '../models/category_model.dart';
import 'settlement_service.dart';

class LedgerEntry {
  final ExpenseModel expense;
  final double participantShare;

  const LedgerEntry({
    required this.expense,
    required this.participantShare,
  });
}

class ParticipantLedger {
  final String userId;
  final String userName;
  final double totalPaid;
  final double totalOwed;
  final double netBalance;
  final List<LedgerEntry> entries;

  const ParticipantLedger({
    required this.userId,
    required this.userName,
    required this.totalPaid,
    required this.totalOwed,
    required this.netBalance,
    required this.entries,
  });

  bool get isSettled => netBalance.abs() < 0.01;
}

enum LedgerSortOption { date, amount, category }

class LedgerService {
  ParticipantLedger computeLedger({
    required String userId,
    required String userName,
    required List<ExpenseModel> allExpenses,
    required Map<String, BalanceInfo> balances,
  }) {
    final relevantExpenses = allExpenses.where((e) {
      final isPayer = e.paidBy == userId;
      final isParticipant = e.splitDetails.any((d) => d.userId == userId);
      return isPayer || isParticipant;
    }).toList();

    final info = balances[userId];
    final totalPaid = info?.totalPaid ?? 0.0;
    final totalOwed = info?.totalOwed ?? 0.0;
    final netBalance = info?.netBalance ?? 0.0;

    final entries = relevantExpenses.map((e) {
      return LedgerEntry(
        expense: e,
        participantShare: e.splitAmountForUser(userId),
      );
    }).toList();

    return ParticipantLedger(
      userId: userId,
      userName: userName,
      totalPaid: totalPaid,
      totalOwed: totalOwed,
      netBalance: netBalance,
      entries: entries,
    );
  }

  List<LedgerEntry> filterAndSort({
    required List<LedgerEntry> entries,
    required String? categoryFilter,
    required LedgerSortOption sortOption,
  }) {
    var result = entries;

    if (categoryFilter != null && categoryFilter.isNotEmpty) {
      result = result.where((e) => e.expense.category == categoryFilter).toList();
    }

    result = List.from(result);
    switch (sortOption) {
      case LedgerSortOption.date:
        result.sort((a, b) => b.expense.createdAt.compareTo(a.expense.createdAt));
      case LedgerSortOption.amount:
        result.sort((a, b) => b.expense.amount.compareTo(a.expense.amount));
      case LedgerSortOption.category:
        result.sort((a, b) => a.expense.category.compareTo(b.expense.category));
    }

    return result;
  }

  Future<Uint8List> generateLedgerPdf({
    required ParticipantLedger ledger,
    required List<LedgerEntry> filteredEntries,
    required String currency,
    required String tripName,
    required Map<String, CategoryModel> catInfo,
    String? categoryFilter,
  }) async {
    final pdf = pw.Document();
    final primary = PdfColor.fromInt(0xFF1565C0);
    final green = PdfColor.fromInt(0xFF2E7D32);
    final red = PdfColor.fromInt(0xFFC62828);
    final grey = PdfColor.fromInt(0xFF757575);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: pw.BoxDecoration(
              color: primary,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              'PARTICIPANT LEDGER',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 11,
                letterSpacing: 3,
              ),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            ledger.userName,
            style: pw.TextStyle(
              fontSize: 28,
              fontWeight: pw.FontWeight.bold,
              color: primary,
            ),
          ),
          pw.Text(tripName,
              style: pw.TextStyle(fontSize: 13, color: grey)),
          pw.SizedBox(height: 8),
          if (categoryFilter != null)
            pw.Text('Filtered by: $categoryFilter',
                style: pw.TextStyle(fontSize: 10, color: grey)),
          pw.Divider(height: 24),
          pw.Row(
            children: [
              _pdfMetric('Total Paid', '\$${ledger.totalPaid.toStringAsFixed(2)}', primary),
              pw.SizedBox(width: 16),
              _pdfMetric('Total Share', '\$${ledger.totalOwed.toStringAsFixed(2)}', grey),
              pw.SizedBox(width: 16),
              _pdfMetric(
                'Net Balance',
                '\$${ledger.netBalance.toStringAsFixed(2)}',
                ledger.netBalance >= 0 ? green : red,
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: pw.BoxDecoration(
              color: ledger.isSettled ? green : PdfColor.fromInt(0xFFFFF3E0),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              ledger.isSettled ? 'SETTLED' : 'PENDING',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: ledger.isSettled ? PdfColors.white : PdfColor.fromInt(0xFFE65100),
              ),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Expense History',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: primary,
              )),
          pw.SizedBox(height: 12),
          if (filteredEntries.isEmpty)
            pw.Text('No expenses found.',
                style: const pw.TextStyle(color: PdfColors.grey))
          else
            ...filteredEntries.map((entry) => _buildPdfEntry(entry, ledger.userId, catInfo, grey)),
        ],
      ),
    );

    return await pdf.save();
  }

  pw.Widget _pdfMetric(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF757575))),
          pw.SizedBox(height: 2),
          pw.Text(value,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: color,
              )),
        ],
      ),
    );
  }

  pw.Widget _buildPdfEntry(
    LedgerEntry entry,
    String userId,
    Map<String, CategoryModel> catInfo,
    PdfColor grey,
  ) {
    final e = entry.expense;
    final cat = catInfo[e.category];
    final catColor = cat != null
        ? PdfColor.fromInt(cat.colorValue)
        : PdfColor.fromInt(0xFF9E9E9E);

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE0E0E0), width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 4,
            height: 40,
            decoration: pw.BoxDecoration(
              color: catColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(e.expenseName,
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    )),
                pw.SizedBox(height: 2),
                pw.Text(
                  '${e.category} · ${_formatShortDate(e.createdAt)}',
                  style: pw.TextStyle(fontSize: 8, color: grey),
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  children: [
                    pw.Text('Total: ',
                        style: pw.TextStyle(fontSize: 9, color: grey)),
                    pw.Text('\$${e.amount.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        )),
                    pw.SizedBox(width: 12),
                    pw.Text('Share: ',
                        style: pw.TextStyle(fontSize: 9, color: grey)),
                    pw.Text('\$${entry.participantShare.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(0xFF1565C0),
                        )),
                  ],
                ),
              ],
            ),
          ),
          pw.Text(
            e.paidBy == userId ? 'Paid' : e.splitType,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: e.paidBy == userId
                  ? PdfColor.fromInt(0xFF2E7D32)
                  : PdfColor.fromInt(0xFF757575),
            ),
          ),
        ],
      ),
    );
  }

  String _formatShortDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}';
  }
}
