import '../models/expense_model.dart';
import 'expense_filter_service.dart';

class InsightsData {
  final String? highestCategory;
  final String highestPayerName;
  final String averagePerDayText;
  final int expensesThisWeek;
  final int expensesThisMonth;

  const InsightsData({
    this.highestCategory,
    required this.highestPayerName,
    required this.averagePerDayText,
    required this.expensesThisWeek,
    required this.expensesThisMonth,
  });
}

class DailySpending {
  final DateTime date;
  final double amount;

  const DailySpending({required this.date, required this.amount});
}

class AnalyticsService {
  final ExpenseFilterService _filterService;

  AnalyticsService({required ExpenseFilterService filterService})
      : _filterService = filterService;

  double lowestExpense(List<ExpenseModel> expenses) {
    if (expenses.isEmpty) return 0;
    return expenses.map((e) => e.amount).reduce((a, b) => a < b ? a : b);
  }

  int expensesThisWeekCount(List<ExpenseModel> expenses) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    return expenses
        .where((e) =>
            e.createdAt.isAfter(weekStart.subtract(const Duration(days: 1))) &&
            e.createdAt.isBefore(weekEnd))
        .length;
  }

  int expensesThisMonthCount(List<ExpenseModel> expenses) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd =
        DateTime(now.year, now.month + 1, 1).subtract(const Duration(days: 1));
    return expenses
        .where((e) =>
            e.createdAt.isAfter(monthStart.subtract(const Duration(days: 1))) &&
            e.createdAt.isBefore(monthEnd.add(const Duration(days: 1))))
        .length;
  }

  List<DailySpending> dailySpending(List<ExpenseModel> expenses) {
    final map = <DateTime, double>{};
    for (final e in expenses) {
      final day = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
      map[day] = (map[day] ?? 0) + e.amount;
    }
    final entries = map.entries.toList();
    entries.sort((a, b) => a.key.compareTo(b.key));
    return entries
        .map((e) => DailySpending(date: e.key, amount: e.value))
        .toList();
  }

  InsightsData generateInsights({
    required Map<String, double> byCategory,
    required Map<String, double> byParticipant,
    required Map<String, String> participantNames,
    required List<ExpenseModel> expenses,
    required DateTime? tripStartDate,
    required DateTime? tripEndDate,
  }) {
    String? highestCategory;
    double highestCatAmount = 0;
    for (final entry in byCategory.entries) {
      if (entry.value > highestCatAmount) {
        highestCatAmount = entry.value;
        highestCategory = entry.key;
      }
    }

    String highestPayerId = '';
    double highestPaidAmount = 0;
    for (final entry in byParticipant.entries) {
      if (entry.value > highestPaidAmount) {
        highestPaidAmount = entry.value;
        highestPayerId = entry.key;
      }
    }
    final highestPayerName = participantNames[highestPayerId] ?? highestPayerId;

    String averagePerDayText;
    if (tripStartDate != null && tripEndDate != null) {
      final tripDays = tripEndDate.difference(tripStartDate).inDays + 1;
      if (tripDays > 0) {
        final total = _filterService.totalExpenses(expenses);
        averagePerDayText = (total / tripDays).toStringAsFixed(2);
      } else {
        averagePerDayText = '0.00';
      }
    } else if (expenses.isNotEmpty) {
      final minDate =
          expenses.map((e) => e.createdAt).reduce((a, b) => a.isBefore(b) ? a : b);
      final maxDate =
          expenses.map((e) => e.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
      final days = maxDate.difference(minDate).inDays + 1;
      final total = _filterService.totalExpenses(expenses);
      averagePerDayText = days > 0 ? (total / days).toStringAsFixed(2) : '0.00';
    } else {
      averagePerDayText = '0.00';
    }

    return InsightsData(
      highestCategory: highestCategory,
      highestPayerName: highestPayerName,
      averagePerDayText: averagePerDayText,
      expensesThisWeek: expensesThisWeekCount(expenses),
      expensesThisMonth: expensesThisMonthCount(expenses),
    );
  }
}
