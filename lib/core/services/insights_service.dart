import '../models/expense_model.dart';
import '../models/expense_template_model.dart';
import 'analytics_service.dart';
import 'expense_filter_service.dart';

class WeeklySpending {
  final int year;
  final int weekNumber;
  final DateTime weekStart;
  final double amount;

  const WeeklySpending({
    required this.year,
    required this.weekNumber,
    required this.weekStart,
    required this.amount,
  });
}

class TripInsights {
  final double totalTripCost;
  final int totalParticipants;
  final int totalExpenses;
  final double averageExpense;
  final double averageCostPerPerson;
  final int? tripDurationDays;
  final double averageSpendPerDay;

  final Map<String, double> categoryPercentages;
  final String? highestSpendingCategory;
  final double highestSpendingCategoryAmount;
  final String? lowestSpendingCategory;
  final double lowestSpendingCategoryAmount;

  final String? whoPaidTheMost;
  final double whoPaidTheMostAmount;
  final String? whoOwesTheMost;
  final double whoOwesTheMostAmount;
  final String? whoReceivedTheMost;
  final double whoReceivedTheMostAmount;
  final double averageContributionPerParticipant;

  final double highestSingleExpense;
  final String highestExpenseName;
  final double lowestSingleExpense;
  final String lowestExpenseName;
  final String mostFrequentCategory;
  final int mostFrequentCategoryCount;
  final String? mostUsedTemplate;
  final int mostUsedTemplateCount;

  final List<DailySpending> dailySpending;
  final List<WeeklySpending> weeklySpending;

  final List<String> smartInsights;

  const TripInsights({
    required this.totalTripCost,
    required this.totalParticipants,
    required this.totalExpenses,
    required this.averageExpense,
    required this.averageCostPerPerson,
    this.tripDurationDays,
    required this.averageSpendPerDay,
    required this.categoryPercentages,
    this.highestSpendingCategory,
    required this.highestSpendingCategoryAmount,
    this.lowestSpendingCategory,
    required this.lowestSpendingCategoryAmount,
    this.whoPaidTheMost,
    required this.whoPaidTheMostAmount,
    this.whoOwesTheMost,
    required this.whoOwesTheMostAmount,
    this.whoReceivedTheMost,
    required this.whoReceivedTheMostAmount,
    required this.averageContributionPerParticipant,
    required this.highestSingleExpense,
    required this.highestExpenseName,
    required this.lowestSingleExpense,
    required this.lowestExpenseName,
    required this.mostFrequentCategory,
    required this.mostFrequentCategoryCount,
    this.mostUsedTemplate,
    required this.mostUsedTemplateCount,
    required this.dailySpending,
    required this.weeklySpending,
    required this.smartInsights,
  });
}

class InsightsService {
  final ExpenseFilterService _filterService;
  final AnalyticsService _analyticsService;

  InsightsService({
    required this._filterService,
    required this._analyticsService,
  });

  TripInsights generate({
    required List<ExpenseModel> expenses,
    required List<String> participants,
    required Map<String, String> participantNames,
    required Map<String, double> paidByUser,
    required Map<String, double> owedByUser,
    required DateTime? tripStartDate,
    required DateTime? tripEndDate,
    List<ExpenseTemplateModel> templates = const [],
  }) {
    final byCategory = _filterService.expensesByCategory(expenses);
    final byParticipant = _filterService.expensesByParticipant(
        expenses, participants, participantNames);
    final totalCost = _filterService.totalExpenses(expenses);
    final dailySpending = _analyticsService.dailySpending(expenses);
    final weeklySpending = _computeWeeklySpending(expenses);

    final tripDurationDays = _calcDuration(tripStartDate, tripEndDate);
    final avgPerDay = _calcAvgPerDay(totalCost, tripDurationDays, expenses);

    final categoryPercentages = _calcCategoryPercentages(byCategory, totalCost);
    final (highestCat, highestCatAmt) = _findHighestCategory(byCategory);
    final (lowestCat, lowestCatAmt) = _findLowestCategory(byCategory);

    final (whoPaidMost, paidMostAmt) = _findMaxEntry(byParticipant, participantNames);
    final (whoOwesMost, owesMostAmt) = _findMaxEntry(owedByUser, participantNames);
    final (whoReceivedMost, receivedMostAmt) = _findReceivedMost(paidByUser, owedByUser, participantNames);

    final avgContribution = participants.isNotEmpty ? totalCost / participants.length : 0.0;

    final highestExp = _findHighestExpense(expenses);
    final lowestExp = _findLowestExpense(expenses);
    final (freqCat, freqCatCount) = _mostFrequentCategory(expenses);
    final (usedTmpl, tmplCount) = _mostUsedTemplate(templates);

    final smartInsights = _generateSmartInsights(
      totalCost: totalCost,
      byCategory: byCategory,
      byParticipant: byParticipant,
      participantNames: participantNames,
      avgPerDay: avgPerDay,
      tripDurationDays: tripDurationDays,
      whoPaidMost: whoPaidMost,
      paidMostAmt: paidMostAmt,
      highestCat: highestCat,
      highestCatAmt: highestCatAmt,
      expenses: expenses,
    );

    return TripInsights(
      totalTripCost: totalCost,
      totalParticipants: participants.length,
      totalExpenses: expenses.length,
      averageExpense: _filterService.averageExpense(expenses),
      averageCostPerPerson: avgContribution,
      tripDurationDays: tripDurationDays,
      averageSpendPerDay: avgPerDay,
      categoryPercentages: categoryPercentages,
      highestSpendingCategory: highestCat,
      highestSpendingCategoryAmount: highestCatAmt,
      lowestSpendingCategory: lowestCat,
      lowestSpendingCategoryAmount: lowestCatAmt,
      whoPaidTheMost: whoPaidMost,
      whoPaidTheMostAmount: paidMostAmt,
      whoOwesTheMost: whoOwesMost,
      whoOwesTheMostAmount: owesMostAmt,
      whoReceivedTheMost: whoReceivedMost,
      whoReceivedTheMostAmount: receivedMostAmt,
      averageContributionPerParticipant: avgContribution,
      highestSingleExpense: highestExp.$1,
      highestExpenseName: highestExp.$2,
      lowestSingleExpense: lowestExp.$1,
      lowestExpenseName: lowestExp.$2,
      mostFrequentCategory: freqCat,
      mostFrequentCategoryCount: freqCatCount,
      mostUsedTemplate: usedTmpl,
      mostUsedTemplateCount: tmplCount,
      dailySpending: dailySpending,
      weeklySpending: weeklySpending,
      smartInsights: smartInsights,
    );
  }

  int? _calcDuration(DateTime? start, DateTime? end) {
    if (start != null && end != null) {
      return end.difference(start).inDays + 1;
    }
    return null;
  }

  double _calcAvgPerDay(double total, int? durationDays, List<ExpenseModel> expenses) {
    if (durationDays != null && durationDays > 0) {
      return total / durationDays;
    }
    if (expenses.length >= 2) {
      final dates = expenses.map((e) => e.createdAt).toList()..sort();
      final days = dates.last.difference(dates.first).inDays + 1;
      return days > 0 ? total / days : total;
    }
    return total;
  }

  Map<String, double> _calcCategoryPercentages(
      Map<String, double> byCategory, double totalCost) {
    if (totalCost <= 0) return {};
    return byCategory.map((k, v) => MapEntry(k, (v / totalCost) * 100));
  }

  (String?, double) _findHighestCategory(Map<String, double> byCategory) {
    String? highest;
    double highestAmt = 0;
    for (final e in byCategory.entries) {
      if (e.value > highestAmt) {
        highestAmt = e.value;
        highest = e.key;
      }
    }
    return (highest, highestAmt);
  }

  (String?, double) _findLowestCategory(Map<String, double> byCategory) {
    String? lowest;
    double lowestAmt = double.infinity;
    for (final e in byCategory.entries) {
      if (e.value < lowestAmt) {
        lowestAmt = e.value;
        lowest = e.key;
      }
    }
    if (lowest == null) return (null, 0);
    return (lowest, lowestAmt);
  }

  (String?, double) _findMaxEntry(
      Map<String, double> map, Map<String, String> names) {
    String? key;
    double value = 0;
    for (final e in map.entries) {
      if (e.value > value) {
        value = e.value;
        key = e.key;
      }
    }
    if (key == null) return (null, 0);
    return (names[key] ?? key, value);
  }

  (String?, double) _findReceivedMost(
    Map<String, double> paidByUser,
    Map<String, double> owedByUser,
    Map<String, String> names,
  ) {
    String? key;
    double maxNet = 0;
    final allKeys = {...paidByUser.keys, ...owedByUser.keys};
    for (final uid in allKeys) {
      final paid = paidByUser[uid] ?? 0;
      final owed = owedByUser[uid] ?? 0;
      final net = paid - owed;
      if (net > maxNet) {
        maxNet = net;
        key = uid;
      }
    }
    if (key == null) return (null, 0);
    return (names[key] ?? key, maxNet);
  }

  (double, String) _findHighestExpense(List<ExpenseModel> expenses) {
    if (expenses.isEmpty) return (0, '');
    final e = expenses.fold<ExpenseModel>(
        expenses.first,
        (max, e) => e.amount > max.amount ? e : max);
    return (e.amount, e.expenseName);
  }

  (double, String) _findLowestExpense(List<ExpenseModel> expenses) {
    if (expenses.isEmpty) return (0, '');
    final e = expenses.fold<ExpenseModel>(
        expenses.first,
        (min, e) => e.amount < min.amount ? e : min);
    return (e.amount, e.expenseName);
  }

  (String, int) _mostFrequentCategory(List<ExpenseModel> expenses) {
    final counts = <String, int>{};
    for (final e in expenses) {
      counts[e.category] = (counts[e.category] ?? 0) + 1;
    }
    String cat = '';
    int maxCount = 0;
    for (final e in counts.entries) {
      if (e.value > maxCount) {
        maxCount = e.value;
        cat = e.key;
      }
    }
    return (cat, maxCount);
  }

  (String?, int) _mostUsedTemplate(List<ExpenseTemplateModel> templates) {
    String? name;
    int maxCount = 0;
    for (final t in templates) {
      if (t.usageCount > maxCount) {
        maxCount = t.usageCount;
        name = t.name;
      }
    }
    return (name, maxCount);
  }

  List<WeeklySpending> _computeWeeklySpending(List<ExpenseModel> expenses) {
    final weeklyMap = <int, double>{};
    final weekStartMap = <int, DateTime>{};
    for (final e in expenses) {
      final year = e.createdAt.year;
      final week = _isoWeekNumber(e.createdAt);
      final key = year * 100 + week;
      weeklyMap[key] = (weeklyMap[key] ?? 0) + e.amount;
      if (!weekStartMap.containsKey(key)) {
        weekStartMap[key] = _startOfWeek(e.createdAt);
      }
    }
    final entries = weeklyMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((e) {
      final year = e.key ~/ 100;
      final week = e.key % 100;
      return WeeklySpending(
        year: year,
        weekNumber: week,
        weekStart: weekStartMap[e.key] ?? DateTime(year),
        amount: e.value,
      );
    }).toList();
  }

  int _isoWeekNumber(DateTime date) {
    final base = DateTime(date.year, 1, 1);
    final days = date.difference(base).inDays;
    return ((days + base.weekday - 1) / 7).ceil();
  }

  DateTime _startOfWeek(DateTime date) {
    final diff = date.weekday - 1;
    return DateTime(date.year, date.month, date.day - diff);
  }

  List<String> _generateSmartInsights({
    required double totalCost,
    required Map<String, double> byCategory,
    required Map<String, double> byParticipant,
    required Map<String, String> participantNames,
    required double avgPerDay,
    required int? tripDurationDays,
    required String? whoPaidMost,
    required double paidMostAmt,
    required String? highestCat,
    required double highestCatAmt,
    required List<ExpenseModel> expenses,
  }) {
    final insights = <String>[];

    if (highestCat != null && totalCost > 0) {
      final pct = (highestCatAmt / totalCost) * 100;
      insights.add(
        '$highestCat accounts for ${pct.toStringAsFixed(0)}% of the total trip cost.',
      );
    }

    if (whoPaidMost != null && totalCost > 0 && paidMostAmt > 0) {
      final pct = (paidMostAmt / totalCost) * 100;
      insights.add(
        '$whoPaidMost paid ${pct.toStringAsFixed(0)}% of all expenses.',
      );
    }

    if (avgPerDay > 0) {
      insights.add(
        'Average spending per day was \$${avgPerDay.toStringAsFixed(2)}.',
      );
    }

    if (expenses.length > 1) {
      final dates = expenses.map((e) => e.createdAt).toList()..sort();
      final span = dates.last.difference(dates.first).inDays + 1;
      final perDay = span > 0 ? (expenses.length / span) : expenses.length.toDouble();
      insights.add(
        '${expenses.length} expenses across $span day${span == 1 ? '' : 's'} '
        '(${perDay.toStringAsFixed(1)} per day).',
      );
    }

    if (tripDurationDays != null && totalCost > 0 && tripDurationDays > 0) {
      final perDayTotal = totalCost / tripDurationDays;
      insights.add(
        'Total trip cost spread over $tripDurationDays day${tripDurationDays == 1 ? '' : 's'} '
        'averages \$${perDayTotal.toStringAsFixed(2)} per day.',
      );
    }

    if (byCategory.length > 1 && totalCost > 0) {
      final cats = byCategory.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (cats.length >= 2) {
        final top2Pct = ((cats[0].value + cats[1].value) / totalCost) * 100;
        insights.add(
          'Top 2 categories (${cats[0].key}, ${cats[1].key}) account for '
          '${top2Pct.toStringAsFixed(0)}% of spending.',
        );
      }
    }

    if (expenses.isNotEmpty) {
      final amounts = expenses.map((e) => e.amount).toList()..sort();
      final median = amounts.length.isOdd
          ? amounts[amounts.length ~/ 2]
          : (amounts[amounts.length ~/ 2 - 1] + amounts[amounts.length ~/ 2]) / 2;
      final avg = _filterService.averageExpense(expenses);
      if (avg > 0) {
        final ratio = median / avg;
        if (ratio < 0.5) {
          insights.add(
            'Most expenses are small but a few large ones drive up the average.',
          );
        } else if (ratio > 1.5) {
          insights.add(
            'Expenses are evenly distributed with no extreme outliers.',
          );
        }
      }
    }

    return insights;
  }
}
