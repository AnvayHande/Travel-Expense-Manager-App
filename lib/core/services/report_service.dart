import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/trip_model.dart';
import '../models/expense_model.dart';
import '../models/category_model.dart';
import '../models/settlement_model.dart';
import 'settlement_service.dart';
import 'analytics_service.dart';
import 'expense_filter_service.dart';
import 'budget_service.dart';

class ReportService {
  final ExpenseFilterService _filterService;
  final AnalyticsService _analyticsService;

  ReportService({
    required this._filterService,
    required this._analyticsService,
  });

  Future<Uint8List> generateReport({
    required TripModel trip,
    required List<ExpenseModel> expenses,
    required Map<String, String> participantNames,
    required Map<String, BalanceInfo> balances,
    required List<Settlement> pendingTransactions,
    required List<SettlementModel> completedSettlements,
    required BudgetData budgetData,
    required Map<String, CategoryModel> catInfo,
  }) async {
    final pdf = pw.Document();
    final primary = PdfColor.fromInt(0xFF1565C0);
    final grey = PdfColor.fromInt(0xFF757575);
    final lightGrey = PdfColor.fromInt(0xFFF5F5F5);
    final green = PdfColor.fromInt(0xFF2E7D32);
    final red = PdfColor.fromInt(0xFFC62828);

    final sortedExpenses = List<ExpenseModel>.from(expenses)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final dailySpending = _analyticsService.dailySpending(expenses);
    final byCategory = _filterService.expensesByCategory(expenses);
    final byParticipant = _filterService.expensesByParticipant(
      expenses,
      trip.participants,
      participantNames,
    );

    final totalParticipants = trip.participants.length;
    final totalExpenses = expenses.length;
    final totalCost = _filterService.totalExpenses(expenses);
    final totalBudget = trip.totalBudget;
    final remainingBudget = totalBudget > 0 ? totalBudget - totalCost : 0.0;

    // Page 1: Cover / Overview
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          _buildCoverPage(
            trip, totalParticipants, totalExpenses, totalCost,
            totalBudget, remainingBudget, primary, grey, expenses,
          ),
        ],
      ),
    );

    // Page 2: Expense Summary Table
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _sectionHeader('Expense Summary', primary),
          pw.SizedBox(height: 16),
          _buildExpenseTable(sortedExpenses, participantNames, lightGrey),
        ],
      ),
    );

    // Page 3: Participant Summary
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _sectionHeader('Participant Summary', primary),
          pw.SizedBox(height: 16),
          _buildParticipantSummary(
            trip.participants, participantNames, balances,
            lightGrey, green, red,
          ),
        ],
      ),
    );

    // Page 4: Analytics
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _sectionHeader('Analytics', primary),
          pw.SizedBox(height: 16),
          _buildCategoryPieChart(byCategory, catInfo, totalCost, primary, grey),
          pw.SizedBox(height: 32),
          _buildParticipantBarChart(byParticipant, participantNames, primary, grey),
          pw.SizedBox(height: 32),
          _buildDailySpendingChart(dailySpending, primary, grey),
        ],
      ),
    );

    // Page 5: Settlement Summary
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _sectionHeader('Settlement Summary', primary),
          pw.SizedBox(height: 16),
          _buildSettlementSummary(
            completedSettlements, pendingTransactions,
            trip.participants, participantNames, balances,
            lightGrey, green, red, grey,
          ),
        ],
      ),
    );

    // Page 6: Trip Memories
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _sectionHeader('Trip Memories', primary),
          pw.SizedBox(height: 16),
          _buildMemories(sortedExpenses, participantNames, grey),
        ],
      ),
    );

    return await pdf.save();
  }

  pw.Widget _buildCoverPage(
    TripModel trip,
    int totalParticipants,
    int totalExpenses,
    double totalCost,
    double totalBudget,
    double remainingBudget,
    PdfColor primary,
    PdfColor grey,
    List<ExpenseModel> expenses,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 40),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: pw.BoxDecoration(
            color: primary,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(
            'TRIP REPORT',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 12,
              letterSpacing: 3,
            ),
          ),
        ),
        pw.SizedBox(height: 24),
        pw.Text(
          trip.tripName,
          style: pw.TextStyle(
            fontSize: 36,
            fontWeight: pw.FontWeight.bold,
            color: primary,
          ),
        ),
        if (trip.destination != null && trip.destination!.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text(
            trip.destination!,
            style: pw.TextStyle(fontSize: 16, color: grey),
          ),
        ],
        pw.SizedBox(height: 8),
        pw.Text(
          _formatDateRange(trip.startDate, trip.endDate),
          style: pw.TextStyle(fontSize: 14, color: grey),
        ),
        pw.Divider(height: 40),
        pw.SizedBox(height: 20),
        _overviewRow('Total Participants', '$totalParticipants', primary),
        pw.SizedBox(height: 12),
        _overviewRow('Total Expenses', '$totalExpenses', primary),
        pw.SizedBox(height: 12),
        _overviewRow('Total Cost', '\$${totalCost.toStringAsFixed(2)}', primary),
        if (totalBudget > 0) ...[
          pw.SizedBox(height: 12),
          _overviewRow('Total Budget', '\$${totalBudget.toStringAsFixed(2)}', primary),
          pw.SizedBox(height: 12),
          _overviewRow(
            'Remaining Budget',
            remainingBudget >= 0
                ? '\$${remainingBudget.toStringAsFixed(2)}'
                : 'Exceeded by \$${(-remainingBudget).toStringAsFixed(2)}',
            remainingBudget >= 0 ? primary : PdfColor.fromInt(0xFFC62828),
          ),
        ],
        pw.SizedBox(height: 40),
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFF5F5F5),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoChip('Created', _formatDate(trip.createdAt)),
                    pw.SizedBox(height: 6),
                    _infoChip('Admin', trip.adminName),
                    pw.SizedBox(height: 6),
                    _infoChip('Status', trip.status.toUpperCase()),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoChip(
                      'Avg Expense',
                      '\$${_filterService.averageExpense(expenses) > 0 ? _filterService.averageExpense(expenses).toStringAsFixed(2) : '0.00'}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _overviewRow(String label, String value, PdfColor color) {
    return pw.Row(
      children: [
        pw.Container(
          width: 8,
          height: 8,
          decoration: pw.BoxDecoration(
            color: color,
            shape: pw.BoxShape.circle,
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Text(label, style: const pw.TextStyle(fontSize: 13)),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  pw.Widget _infoChip(String label, String value) {
    return pw.Row(
      children: [
        pw.Text(
          '$label: ',
          style: pw.TextStyle(
            fontSize: 11,
            color: PdfColor.fromInt(0xFF757575),
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildExpenseTable(
    List<ExpenseModel> expenses,
    Map<String, String> participantNames,
    PdfColor lightGrey,
  ) {
    if (expenses.isEmpty) {
      return pw.Text('No expenses recorded.',
          style: const pw.TextStyle(color: PdfColors.grey));
    }

    final headers = ['Expense', 'Category', 'Paid By', 'Amount', 'Split', 'Date'];

    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColor.fromInt(0xFFE0E0E0),
        width: 0.5,
      ),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFF1565C0)),
          children: headers.map((h) => _tableCell(
            h, isHeader: true,
          )).toList(),
        ),
        ...expenses.map((e) {
          final even = expenses.indexOf(e).isEven;
          return pw.TableRow(
            decoration: even
                ? pw.BoxDecoration(color: lightGrey)
                : const pw.BoxDecoration(),
            children: [
              _tableCell(e.expenseName, maxLines: 2),
              _tableCell(e.category),
              _tableCell(participantNames[e.paidBy] ?? e.paidBy),
              _tableCell('\$${e.amount.toStringAsFixed(2)}'),
              _tableCell(e.splitLabel),
              _tableCell(_formatShortDate(e.createdAt)),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _tableCell(String text, {bool isHeader = false, int maxLines = 1}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 9 : 8,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
        maxLines: maxLines,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  pw.Widget _buildParticipantSummary(
    List<String> participants,
    Map<String, String> participantNames,
    Map<String, BalanceInfo> balances,
    PdfColor lightGrey,
    PdfColor green,
    PdfColor red,
  ) {
    if (participants.isEmpty) {
      return pw.Text('No participants.',
          style: const pw.TextStyle(color: PdfColors.grey));
    }

    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColor.fromInt(0xFFE0E0E0),
        width: 0.5,
      ),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFF1565C0)),
          children: ['Participant', 'Total Paid', 'Total Owed', 'Net Balance', 'Status']
              .map((h) => _tableCell(h, isHeader: true))
              .toList(),
        ),
        ...participants.map((uid) {
          final name = participantNames[uid] ?? uid;
          final info = balances[uid];
          final paid = info?.totalPaid ?? 0;
          final owed = info?.totalOwed ?? 0;
          final net = info?.netBalance ?? 0;
          final settled = info?.isSettled ?? true;
          final isEven = participants.indexOf(uid).isEven;

          return pw.TableRow(
            decoration: isEven
                ? pw.BoxDecoration(color: lightGrey)
                : const pw.BoxDecoration(),
            children: [
              _tableCell(name),
              _tableCell('\$${paid.toStringAsFixed(2)}'),
              _tableCell('\$${owed.toStringAsFixed(2)}'),
              _tableCell(
                '\$${net.toStringAsFixed(2)}',
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: settled ? green : PdfColor.fromInt(0xFFFFF3E0),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    settled ? 'Settled' : 'Pending',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: settled ? PdfColors.white : PdfColor.fromInt(0xFFE65100),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _buildCategoryPieChart(
    Map<String, double> byCategory,
    Map<String, CategoryModel> catInfo,
    double totalCost,
    PdfColor primary,
    PdfColor grey,
  ) {
    if (byCategory.isEmpty) {
      return pw.Text('No category data.',
          style: const pw.TextStyle(color: PdfColors.grey));
    }

    final sorted = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Spending by Category',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: primary,
            )),
        pw.SizedBox(height: 12),
        ...sorted.map((entry) {
          final cat = catInfo[entry.key];
          final pct = totalCost > 0 ? (entry.value / totalCost) * 100 : 0.0;
          final color = cat != null
              ? PdfColor.fromInt(cat.colorValue)
              : PdfColor.fromInt(0xFF9E9E9E);

          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      width: 10,
                      height: 10,
                      decoration: pw.BoxDecoration(
                        color: color,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Text(entry.key,
                          style: const pw.TextStyle(fontSize: 10)),
                    ),
                    pw.Text(
                      '${pct.toStringAsFixed(1)}%  (\$${entry.value.toStringAsFixed(2)})',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Container(
                  height: 8,
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFEEEEEE),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: (pct / 100) * 400,
                        height: 8,
                        decoration: pw.BoxDecoration(
                          color: color,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  pw.Widget _buildParticipantBarChart(
    Map<String, double> byParticipant,
    Map<String, String> participantNames,
    PdfColor primary,
    PdfColor grey,
  ) {
    if (byParticipant.isEmpty) {
      return pw.Text('No participant data.',
          style: const pw.TextStyle(color: PdfColors.grey));
    }

    final sorted = byParticipant.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = sorted.fold<double>(
        0, (m, e) => e.value > m ? e.value : m);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Spending by Participant',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: primary,
            )),
        pw.SizedBox(height: 12),
        ...sorted.map((entry) {
          final name = participantNames[entry.key] ?? entry.key;
          final ratio = maxVal > 0 ? entry.value / maxVal : 0.0;

          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              children: [
                pw.SizedBox(
                  width: 70,
                  child: pw.Text(
                    name.length > 10 ? '${name.substring(0, 10)}..' : name,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Container(
                    height: 16,
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFEEEEEE),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Container(
                          width: ratio * 300,
                          height: 16,
                          decoration: pw.BoxDecoration(
                            color: primary,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.SizedBox(
                  width: 60,
                  child: pw.Text(
                    '\$${entry.value.toStringAsFixed(2)}',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  pw.Widget _buildDailySpendingChart(
    List<DailySpending> dailySpending,
    PdfColor primary,
    PdfColor grey,
  ) {
    if (dailySpending.isEmpty) {
      return pw.Text('No daily spending data.',
          style: const pw.TextStyle(color: PdfColors.grey));
    }

    final maxVal = dailySpending.fold<double>(
        0, (m, d) => d.amount > m ? d.amount : m);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Daily Spending Trend',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: primary,
            )),
        pw.SizedBox(height: 12),
        ...dailySpending.map((day) {
          final ratio = maxVal > 0 ? day.amount / maxVal : 0.0;

          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Row(
              children: [
                pw.SizedBox(
                  width: 60,
                  child: pw.Text(
                    _formatShortDate(day.date),
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ),
                pw.SizedBox(width: 6),
                pw.Expanded(
                  child: pw.Container(
                    height: 10,
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFEEEEEE),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Container(
                          width: ratio * 300,
                          height: 10,
                          decoration: pw.BoxDecoration(
                            color: primary,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 6),
                pw.SizedBox(
                  width: 55,
                  child: pw.Text(
                    '\$${day.amount.toStringAsFixed(2)}',
                    textAlign: pw.TextAlign.right,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  pw.Widget _buildSettlementSummary(
    List<SettlementModel> completedSettlements,
    List<Settlement> pendingTransactions,
    List<String> participants,
    Map<String, String> participantNames,
    Map<String, BalanceInfo> balances,
    PdfColor lightGrey,
    PdfColor green,
    PdfColor red,
    PdfColor grey,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Completed Settlements',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: green,
            )),
        pw.SizedBox(height: 8),
        if (completedSettlements.isEmpty)
          pw.Text('No completed settlements.',
              style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10))
        else
          ...completedSettlements.map((s) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 4),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: lightGrey,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        '${participantNames[s.fromUser] ?? s.fromUser} → ${participantNames[s.toUser] ?? s.toUser}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                    pw.Text(
                      '\$${s.amount.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: green,
                      ),
                    ),
                  ],
                ),
              )),
        pw.SizedBox(height: 24),
        pw.Text('Pending Settlements',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: red,
            )),
        pw.SizedBox(height: 8),
        if (pendingTransactions.isEmpty)
          pw.Text('No pending settlements. Everyone is settled!',
              style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10))
        else
          ...pendingTransactions.map((t) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 4),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFFFF3E0),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        '${participantNames[t.fromUserId] ?? t.fromUserId} → ${participantNames[t.toUserId] ?? t.toUserId}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                    pw.Text(
                      '\$${t.amount.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: red,
                      ),
                    ),
                  ],
                ),
              )),
        pw.SizedBox(height: 24),
        pw.Text('Final Balances',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            )),
        pw.SizedBox(height: 8),
        ...participants.map((uid) {
          final info = balances[uid];
          final net = info?.netBalance ?? 0;
          final name = participantNames[uid] ?? uid;
          final color = net > 0.01
              ? green
              : net < -0.01
                  ? red
                  : grey;

          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(name,
                      style: const pw.TextStyle(fontSize: 10)),
                ),
                pw.Text(
                  net > 0
                      ? 'Gets back \$${net.toStringAsFixed(2)}'
                      : net < 0
                          ? 'Owes \$${(-net).toStringAsFixed(2)}'
                          : 'Settled',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  pw.Widget _buildMemories(
    List<ExpenseModel> expenses,
    Map<String, String> participantNames,
    PdfColor grey,
  ) {
    final withNotes = expenses.where((e) =>
        (e.notes != null && e.notes!.isNotEmpty) ||
        e.receiptUrl != null).toList();

    if (withNotes.isEmpty) {
      return pw.Text('No memories recorded.',
          style: const pw.TextStyle(color: PdfColors.grey));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: withNotes.map((e) {
        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 12),
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(
              color: PdfColor.fromInt(0xFFE0E0E0),
              width: 0.5,
            ),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                e.expenseName,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '${participantNames[e.paidBy] ?? e.paidBy} · ${e.category} · ${_formatShortDate(e.createdAt)}',
                style: pw.TextStyle(fontSize: 9, color: grey),
              ),
              if (e.notes != null && e.notes!.isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Text(
                  e.notes!,
                  style: const pw.TextStyle(fontSize: 10),
                  maxLines: 3,
                  overflow: pw.TextOverflow.clip,
                ),
              ],
              if (e.receiptUrl != null) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  children: [
                    pw.Text('📎', style: pw.TextStyle(fontSize: 12)),
                    pw.SizedBox(width: 4),
                    pw.Text('Receipt attached',
                        style: pw.TextStyle(fontSize: 9, color: grey)),
                  ],
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  pw.Widget _sectionHeader(String title, PdfColor color) {
    return pw.Row(
      children: [
        pw.Container(
          width: 4,
          height: 24,
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatDateRange(DateTime? start, DateTime? end) {
    if (start != null && end != null) {
      return '${_formatDate(start)} — ${_formatDate(end)}';
    } else if (start != null) {
      return 'From ${_formatDate(start)}';
    } else if (end != null) {
      return 'Until ${_formatDate(end)}';
    }
    return '';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatShortDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}';
  }
}
